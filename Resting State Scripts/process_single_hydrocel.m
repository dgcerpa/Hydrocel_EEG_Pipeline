
% Single subject analysis
% Iterable with process_grydrocel_batch.m and run_hydrocel_pipeline.m

function [success, msg] = process_single_hydrocel(mat_path, output_dir, report_dir, problematic_dir, chanLoc_file)

% Returns:
%   success - true if processing completed successfully
%   msg     - descriptive message of outcome

    success = false;
    msg = '';
    
    % Extract subject and experiment info from filename
    [~, fname, ~] = fileparts(mat_path);
    
    % Parse filename: E1_1RE_20240305_11232 -> S_01_Exp1_RE
    tokens = regexp(fname, 'E(\d+)_(\d+)RE', 'tokens');
    if isempty(tokens)
        msg = 'Cannot parse filename - expected format: EX_YRE...';
        return;
    end
    
    exp_num = tokens{1}{1};    % Experiment number
    subj_num = tokens{1}{2};   % Subject number
    
    % Format output names
    subj_id = sprintf('S_%02d_Exp%s_RE', str2num(subj_num), exp_num);
    
    % Create subject-specific log
    subj_log = fullfile(report_dir, sprintf('%s_report.txt', subj_id));
    fid_subj = fopen(subj_log, 'w');
    fprintf(fid_subj, '=== Processing Report: %s ===\n', subj_id);
    fprintf(fid_subj, 'Source file: %s\n', fname);
    
    try
        %% STEP 1: Load and basic preprocessing
        fprintf(fid_subj,' STEP 1: Loading Data \n');
        
        % Load .mat file
        data = load(mat_path);
        var_names = fieldnames(data);
        
        % Construct name from filename
        % Rule: replace spaces with underscores and add "2" at the end
        expected_var = [strrep(fname, ' ', '_') '2'];
        
        fprintf(fid_subj, 'Expected EEG variable name: %s\n', expected_var);
        
        % Check if expected variable exists
        if ~isfield(data, expected_var)
            % Fallback: try to find variable with pattern E*_*RE_*2
            eeg_var = '';
            for v = 1:length(var_names)
                if ~strcmp(var_names{v}, 'ECI_TCPIP_55513') && ...
                   ~strcmp(var_names{v}, 'samplingRate') && ...
                   ~contains(var_names{v}, 'Impedances') && ...
                   endsWith(var_names{v}, '2') && ...
                   size(data.(var_names{v}), 1) == 65
                    eeg_var = var_names{v};
                    fprintf(fid_subj, 'Found alternative EEG variable: %s\n', eeg_var);
                    break;
                end
            end
            
            if isempty(eeg_var)
                msg = sprintf('Cannot find EEG data variable. Expected: %s. Variables: %s', ...
                             expected_var, strjoin(var_names, ', '));
                fprintf(fid_subj, 'ERROR: %s\n', msg);
                fclose(fid_subj);
                return;
            end
        else
            eeg_var = expected_var;
        end
        
        fprintf(fid_subj, 'Data size: %s\n', mat2str(size(data.(eeg_var))));
        
        % Load variable into base workspace (required by pop_importdata)
        assignin('base', eeg_var, data.(eeg_var));
        
        % Import into EEGLAB
        EEG = pop_importdata('dataformat', 'array', ...
                            'nbchan', 0, ...
                            'data', eeg_var, ...
                            'setname', subj_id, ...
                            'srate', 500, ...
                            'pnts', 0, ...
                            'xmin', 0);
        EEG = eeg_checkset(EEG);
        
        % Clean up base workspace
        evalin('base', sprintf('clear %s', eeg_var));
        
        fprintf(fid_subj, 'Imported: %d channels, %d points, %.2f sec\n', ...
                EEG.nbchan, EEG.pnts, EEG.pnts/EEG.srate);
        
        %% STEP 2: Label channels
        fprintf(fid_subj, '\n STEP 2: Channel Labeling \n');
        
        standard_labels = {'E1','E2','E3','E4','E5','E6','E7','E8','E9',...
                          'E10','E11','E12','E13','E14','E15','E16','E17','E18','E19',...
                          'E20','E21','E22','E23','E24','E25','E26','E27','E28','E29',...
                          'E30','E31','E32','E33','E34','E35','E36','E37','E38','E39',...
                          'E40','E41','E42','E43','E44','E45','E46','E47','E48','E49',...
                          'E50','E51','E52','E53','E54','E55','E56','E57','E58','E59',...
                          'E60','E61','E62','E63','E64','Cz'};
        
        for i = 1:65
            EEG.chanlocs(i).labels = standard_labels{i};
        end
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Channels labeled\n');
        
        %% STEP 3: Set channel locations
        fprintf(fid_subj, '\n STEP 3: Channel Locations \n');
        
        EEG = pop_chanedit(EEG, 'lookup', chanLoc_file);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Channel locations loaded');
        
        %% STEP 4: Re-reference to Cz
        fprintf(fid_subj, '\n STEP 4: Re-referencing \n');
        
        EEG = pop_reref(EEG, 65);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Re-referenced to Cz\n');
        
        %% STEP 5: Filtering
        fprintf(fid_subj, '\n STEP 5: Filtering \n');
        
        EEG = pop_basicfilter(EEG, 1:64, ...
                             'Boundary', 'boundary', ...
                             'Cutoff', [0.5 35], ...
                             'Design', 'butter', ...
                             'Filter', 'bandpass', ...
                             'Order', 2);
        EEG = eeg_checkset(EEG);
        fprintf(fid_subj, 'Bandpass filter applied\n');
        
        %% STEP 6: Import and validate events
        fprintf(fid_subj, '\n STEP 6: Event Import \n');
        
        % Check if event variable exists
        if ~isfield(data, 'ECI_TCPIP_55513')
            msg = 'Event variable ECI_TCPIP_55513 not found in .mat file';
            fprintf(fid_subj, 'ERROR: %s\n', msg);
            fclose(fid_subj);
            return;
        end
        
        tipos = data.ECI_TCPIP_55513(1, :);
        frames = cell2mat(data.ECI_TCPIP_55513(4, :));
        
        % Create events
        EEG.event = [];
        valid_events = 0;
        for i = 1:length(frames)
            if isnumeric(frames(i)) && frames(i) > 0 && frames(i) <= EEG.pnts
                EEG.event(end+1).type = tipos{i};
                EEG.event(end).latency = frames(i);
                valid_events = valid_events + 1;
            end
        end
        EEG = eeg_checkset(EEG);
        
        fprintf(fid_subj, 'Valid events imported: %d\n', valid_events);
        
        % List unique event types
        event_types = unique({EEG.event.type});
        fprintf(fid_subj, 'Event types found: %s\n', strjoin(event_types, ', '));
        
        % Validate critical events
        fix1_idx = find(strcmp({EEG.event.type}, 'fix1'));
        fix2_idx = find(strcmp({EEG.event.type}, 'fix2'));
        TRSP_idx = find(strcmp({EEG.event.type}, 'TRSP'));
        
        fprintf(fid_subj, '\nCritical Events:\n');
        fprintf(fid_subj, '  fix1: %d occurrences\n', length(fix1_idx));
        fprintf(fid_subj, '  fix2: %d occurrences\n', length(fix2_idx));
        fprintf(fid_subj, '  TRSP: %d occurrences\n', length(TRSP_idx));
        
        % Check if we have at least one of each
        if isempty(fix1_idx) || isempty(fix2_idx) || isempty(TRSP_idx)
            msg = sprintf('Missing critical events - fix1:%d, fix2:%d, TRSP:%d', ...
                         length(fix1_idx), length(fix2_idx), length(TRSP_idx));
            fprintf(fid_subj, '\nERROR: %s\n', msg);
            fprintf(fid_subj, 'Saving unsegmented data to problematic_data/\n');
            
            % Save problematic file for manual inspection
            problem_name = sprintf('%s_UNSEGMENTED.set', subj_id);
            pop_saveset(EEG, 'filename', problem_name, 'filepath', problematic_dir);
            
            fclose(fid_subj);
            return;
        end
        
        % Use first occurrence of each event for segmentation
        fix1_lat = EEG.event(fix1_idx(1)).latency;
        fix2_lat = EEG.event(fix2_idx(1)).latency;
        TRSP_lat = EEG.event(TRSP_idx(1)).latency;
        
        fprintf(fid_subj, '\nUsing first occurrence for segmentation:\n');
        fprintf(fid_subj, '  fix1 at sample: %d (%.2f sec)\n', fix1_lat, fix1_lat/EEG.srate);
        fprintf(fid_subj, '  fix2 at sample: %d (%.2f sec)\n', fix2_lat, fix2_lat/EEG.srate);
        fprintf(fid_subj, '  TRSP at sample: %d (%.2f sec)\n', TRSP_lat, TRSP_lat/EEG.srate);
        
        % Validate temporal order
        if ~(fix1_lat < fix2_lat && fix2_lat < TRSP_lat)
            msg = sprintf('Events not in expected order: fix1(%d) < fix2(%d) < TRSP(%d)', ...
                         fix1_lat, fix2_lat, TRSP_lat);
            fprintf(fid_subj, '\nERROR: %s\n', msg);
            fclose(fid_subj);
            return;
        end
        
        %% STEP 7: Segmentation
        fprintf(fid_subj, '\n STEP 7: Segmentation \n');
        
        % Segment 1: fix1 to fix2 (ojos abiertos)
        EEG_abiertos = pop_select(EEG, 'point', [fix1_lat fix2_lat]);
        EEG_abiertos = eeg_checkset(EEG_abiertos);
        EEG_abiertos.setname = sprintf('%s_abiertos', subj_id);
        
        seg1_duration = (fix2_lat - fix1_lat) / EEG.srate;
        fprintf(fid_subj, 'Segment "abiertos" (fix1→fix2):\n');
        fprintf(fid_subj, '  Duration: %.2f sec (%d samples)\n', seg1_duration, fix2_lat - fix1_lat);
        fprintf(fid_subj, '  Events in segment: %d\n', length(EEG_abiertos.event));
        
        % Segment 2: fix2 to TRSP (ojos cerrados)
        EEG_cerrados = pop_select(EEG, 'point', [fix2_lat TRSP_lat]);
        EEG_cerrados = eeg_checkset(EEG_cerrados);
        EEG_cerrados.setname = sprintf('%s_cerrados', subj_id);
        
        seg2_duration = (TRSP_lat - fix2_lat) / EEG.srate;
        fprintf(fid_subj, 'Segment "cerrados" (fix2→TRSP):\n');
        fprintf(fid_subj, '  Duration: %.2f sec (%d samples)\n', seg2_duration, TRSP_lat - fix2_lat);
        fprintf(fid_subj, '  Events in segment: %d\n', length(EEG_cerrados.event));
        
        %% STEP 8: Clean, ICA, and artifact rejection for each segment
        fprintf('  STEP 8: Processing segments (Clean → ICA → Reject artifacts) \n');
        
        % Process "abiertos" segment
        fprintf('    → Processing "abiertos" segment...\n');
        fprintf(fid_subj, '\n--- STEP 8a: Processing "abiertos" Segment ---\n');
        
        [EEG_abiertos, clean_info_ab, ica_info_ab] = clean_and_ica_segment(EEG_abiertos, fid_subj);
        
        % Process "cerrados" segment
        fprintf('    → Processing "cerrados" segment...\n');
        fprintf(fid_subj, '\n--- STEP 8b: Processing "cerrados" Segment ---\n');
        
        [EEG_cerrados, clean_info_ce, ica_info_ce] = clean_and_ica_segment(EEG_cerrados, fid_subj);
        
        %% Save both segments
        fprintf('  [SAVE] Saving processed segments...\n');
        fprintf(fid_subj, '\n--- SAVING RESULTS ---\n');
        
        fname_abiertos = sprintf('%s_abiertos.set', subj_id);
        pop_saveset(EEG_abiertos, 'filename', fname_abiertos, 'filepath', output_dir);
        fprintf(fid_subj, 'Saved: %s\n', fname_abiertos);
        
        fname_cerrados = sprintf('%s_cerrados.set', subj_id);
        pop_saveset(EEG_cerrados, 'filename', fname_cerrados, 'filepath', output_dir);
        fprintf(fid_subj, 'Saved: %s\n', fname_cerrados);
        
        %% Summary
        fprintf(fid_subj, '\n=== PROCESSING SUMMARY ===\n');
        fprintf(fid_subj, 'Status: SUCCESS\n');
        fprintf(fid_subj, '\nSegment "abiertos":\n');
        fprintf(fid_subj, '  Duration: %.2f sec\n', seg1_duration);
        fprintf(fid_subj, '  Samples removed (ASR): %d (%.2f%%)\n', ...
                clean_info_ab.removed_samples, clean_info_ab.percent_removed);
        fprintf(fid_subj, '  ICA components rejected: %d/%d\n', ...
                ica_info_ab.n_rejected, ica_info_ab.n_total);
        fprintf(fid_subj, '  Rejected components: %s\n', mat2str(ica_info_ab.rejected_comps));
        
        fprintf(fid_subj, '\nSegment "cerrados":\n');
        fprintf(fid_subj, '  Duration: %.2f sec\n', seg2_duration);
        fprintf(fid_subj, '  Samples removed (ASR): %d (%.2f%%)\n', ...
                clean_info_ce.removed_samples, clean_info_ce.percent_removed);
        fprintf(fid_subj, '  ICA components rejected: %d/%d\n', ...
                ica_info_ce.n_rejected, ica_info_ce.n_total);
        fprintf(fid_subj, '  Rejected components: %s\n', mat2str(ica_info_ce.rejected_comps));
        
        success = true;
        msg = sprintf('Completed successfully - %s_abiertos.set, %s_cerrados.set', subj_id, subj_id);
        
    catch ME
        success = false;
        msg = sprintf('Exception: %s', ME.message);
        fprintf(fid_subj, '\n=== ERROR ===\n');
        fprintf(fid_subj, '%s\n', ME.message);
        fprintf(fid_subj, 'Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf(fid_subj, '  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
    end
    
    fclose(fid_subj);
end


function [EEG, clean_info, ica_info] = clean_and_ica_segment(EEG, fid_subj)
% Helper function to clean, run ICA, and reject artifacts on one segment
    
    %% Clean with ASR
    fprintf(fid_subj, '\n[Clean] Applying ASR artifact rejection...\n');
    
    pnts_before = EEG.pnts;
    
    EEG = pop_clean_rawdata(EEG, ...
        'FlatlineCriterion', 'off', ...
        'ChannelCriterion', 'off', ...
        'LineNoiseCriterion', 'off', ...
        'Highpass', 'off', ...
        'BurstCriterion', 20, ...
        'WindowCriterion', 0.25, ...
        'BurstRejection', 'on', ...
        'Distance', 'Euclidian', ...
        'WindowCriterionTolerances', [-Inf 7]);
    EEG = eeg_checkset(EEG);
    
    pnts_after = EEG.pnts;
    removed_samples = pnts_before - pnts_after;
    percent_removed = (removed_samples / pnts_before) * 100;
    
    fprintf(fid_subj, '  Samples before: %d\n', pnts_before);
    fprintf(fid_subj, '  Samples after: %d\n', pnts_after);
    fprintf(fid_subj, '  Samples removed: %d (%.2f%%)\n', removed_samples, percent_removed);
    
    clean_info.removed_samples = removed_samples;
    clean_info.percent_removed = percent_removed;
    
    %% Run ICA
    fprintf(fid_subj, '\n[ICA] Running extended Infomax ICA...\n');
    
    EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'interrupt', 'off');
    EEG = eeg_checkset(EEG);
    
    n_components = size(EEG.icaweights, 1);
    fprintf(fid_subj, '  ICA complete: %d components computed\n', n_components);
    
    %% Label components with ICLabel
    fprintf(fid_subj, '\n[ICLabel] Classifying ICA components...\n');
    
    EEG = pop_iclabel(EEG, 'default');
    EEG = eeg_checkset(EEG);
    
    % Flag components for rejection
    % Criteria: [Brain, Muscle, Eye, Heart, Line Noise, Channel Noise, Other]
    % Reject if: Muscle≥0.7, Eye≥0.7, Heart≥0.7, Channel Noise≥0.7
    EEG = pop_icflag(EEG, [NaN NaN; 0.7 1; 0.7 1; 0.7 1; NaN NaN; 0.7 1; NaN NaN]);
    EEG = eeg_checkset(EEG);
    
    % Find which components were flagged
    rejected_comps = find(EEG.reject.gcompreject);
    n_rejected = length(rejected_comps);
    
    fprintf(fid_subj, '  Components flagged for rejection: %d/%d\n', n_rejected, n_components);
    if n_rejected > 0
        fprintf(fid_subj, '  Rejected component indices: %s\n', mat2str(rejected_comps));
        
        % Log classification probabilities for rejected components
        fprintf(fid_subj, '  Classification details:\n');
        class_labels = {'Brain', 'Muscle', 'Eye', 'Heart', 'LineNoise', 'ChanNoise', 'Other'};
        for c = rejected_comps
            [max_prob, max_idx] = max(EEG.etc.ic_classification.ICLabel.classifications(c, :));
            fprintf(fid_subj, '    Comp %d: %s (%.1f%%)\n', c, class_labels{max_idx}, max_prob*100);
        end
    end
    
    ica_info.n_total = n_components;
    ica_info.n_rejected = n_rejected;
    ica_info.rejected_comps = rejected_comps;
    
    %% Remove flagged components
    fprintf(fid_subj, '\n[Reject] Removing flagged components...\n');
    
    EEG = pop_subcomp(EEG, [], 0);
    EEG = eeg_checkset(EEG);
    
    fprintf(fid_subj, '  Artifact components removed\n');
    fprintf(fid_subj, '  Final dataset: %d channels, %d samples\n', EEG.nbchan, EEG.pnts);
end
