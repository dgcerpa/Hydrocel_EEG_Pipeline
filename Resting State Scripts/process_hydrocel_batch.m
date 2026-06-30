
% Automated batch processing for HydroCel EEG data

function process_hydrocel_batch(input_dir, output_dir, chanLoc_file)

% Inputs:
%   input_dir     - Folder containing .mat files (e.g., 'D:\Mona Lisa RE\Exp 1')
%   output_dir    - Folder to save processed .set files
%   chanLoc_file  - Path to GSN-HydroCel-65_1.0.sfp file

% Output files:
%   - S_XX_ExpY_RE_abiertos.set
%   - S_XX_ExpY_RE_cerrados.set
%   - processing_log.txt (detailed log of all operations)
%   - subject_reports/ (individual subject logs)

    % Initialize EEGLAB without GUI
    eeglab('nogui');
    
    % Create output directory structure
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    report_dir = fullfile(output_dir, 'subject_reports');
    if ~exist(report_dir, 'dir')
        mkdir(report_dir);
    end
    
    problematic_dir = fullfile(output_dir, 'problematic_data');
    if ~exist(problematic_dir, 'dir')
        mkdir(problematic_dir);
    end
    
    % Initialize master log
    log_file = fullfile(output_dir, 'processing_log.txt');
    fid_log = fopen(log_file, 'w');
    fprintf(fid_log, '=== HydroCel EEG Processing Log ===\n');
    fprintf(fid_log, 'Date: %s\n', datestr(now));
    fprintf(fid_log, 'Input Directory: %s\n', input_dir);
    fprintf(fid_log, 'Output Directory: %s\n\n', output_dir);
    fclose(fid_log);
    
    % Find all .mat files
    mat_files = dir(fullfile(input_dir, '*.mat'));
    if isempty(mat_files)
        error('No .mat files found in %s', input_dir);
    end
    
    fprintf('\n=== Found %d .mat files to process ===\n\n', length(mat_files));
    
    % Process each file
    n_success = 0;
    n_failed = 0;
    
    for i = 1:length(mat_files)
        fname = mat_files(i).name;
        fprintf('Processing file %d/%d: %s\n', i, length(mat_files), fname);
        
        try
            % Process single subject
            [success, msg] = process_single_hydrocel(...
                fullfile(input_dir, fname), ...
                output_dir, ...
                report_dir, ...
                problematic_dir, ...
                chanLoc_file);
            
            % Log result
            append_to_log(log_file, fname, success, msg);
            
            if success
                n_success = n_success + 1;
                fprintf('✓ SUCCESS: %s\n', fname);
            else
                n_failed = n_failed + 1;
                fprintf('✗ FAILED: %s\n', fname);
                fprintf('  Reason: %s\n', msg);
            end
            
        catch ME
            n_failed = n_failed + 1;
            error_msg = sprintf('EXCEPTION: %s', ME.message);
            append_to_log(log_file, fname, false, error_msg);
            fprintf('✗ EXCEPTION: %s\n', fname);
            fprintf('  Error: %s\n', ME.message);
        end
    end
    
    % Final summary
    fprintf(' PROCESSING COMPLETE \n');
    fprintf('Total files: %d\n', length(mat_files));
    fprintf('Successful: %d\n', n_success);
    fprintf('Failed: %d\n', n_failed);
    fprintf('Success rate: %.1f%%\n', (n_success/length(mat_files))*100);
    fprintf('\nDetailed log saved to: %s\n', log_file);
    
    % Append summary to log
    fid_log = fopen(log_file, 'a');
    fprintf(fid_log, '\n FINAL SUMMARY \n');
    fprintf(fid_log, 'Total files: %d\n', length(mat_files));
    fprintf(fid_log, 'Successful: %d\n', n_success);
    fprintf(fid_log, 'Failed: %d\n', n_failed);
    fprintf(fid_log, 'Success rate: %.1f%%\n', (n_success/length(mat_files))*100);
    fclose(fid_log);
end


function append_to_log(log_file, fname, success, msg)
% Append processing result to master log
    fid = fopen(log_file, 'a');
    if success
        fprintf(fid, '[SUCCESS] %s - %s\n', fname, msg);
    else
        fprintf(fid, '[FAILED]  %s - %s\n', fname, msg);
    end
    fclose(fid);
end
