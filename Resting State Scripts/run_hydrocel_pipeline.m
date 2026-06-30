
%% Run HydroCel EEG Processing Pipeline

% Instructions:
%   1. Update the paths below for your system
%   2. Run this script
%   3. Check output_dir for processed files and logs
%
% Output structure:
%   output_dir/
%   ├── S_01_Exp1_RE_abiertos.set
%   ├── S_01_Exp1_RE_cerrados.set
%   ├── ...
%   ├── processing_log.txt
%   ├── subject_reports/
%   │   ├── S_01_Exp1_RE_report.txt
%   │   ├── S_02_Exp1_RE_report.txt
%   │   └── ...
%   └── problematic_data/
%       └── (files with missing events)

%% Clear environment
clc;
clear;
close all;

%% Initialize EEGLAB
eeglab;

%%  CONFIGURATION 
% UPDATE  PATHS FOR YOUR SYSTEM

% Input directory containing .mat files
input_dir = '<path/to>\Mona Lisa RE\Exp 1';

% Output directory for processed files
output_dir = '<path/to>\Mona Lisa RE\Processed\Exp1';

% Path to channel location file
chanLoc_file = '<path/to>\eeglab\functions\supportfiles\channel_location_files\philips_neuro\GSN-HydroCel-65_1.0.sfp';

%%  VALIDATION 

% Check if input directory exists
if ~exist(input_dir, 'dir')
    error('Input directory does not exist: %s', input_dir);
end

% Check if channel location file exists
if ~exist(chanLoc_file, 'file')
    error('Channel location file not found: %s', chanLoc_file);
end

% Check for .mat files
mat_files = dir(fullfile(input_dir, '*.mat'));
if isempty(mat_files)
    error('No .mat files found in: %s', input_dir);
end

fprintf('HydroCel EEG Processing Pipeline\n');
fprintf('Input directory: %s\n', input_dir);
fprintf('Output directory: %s\n', output_dir);
fprintf('Channel location file: %s\n', chanLoc_file);
fprintf('Number of files to process: %d\n', length(mat_files));

% Confirm before starting
response = input('Start processing? (y/n): ', 's');
if ~strcmpi(response, 'y')
    fprintf('Processing cancelled.\n');
    return;
end

%% RUN PIPELINE 

tic; % Start timer
process_hydrocel_batch(input_dir, output_dir, chanLoc_file);
elapsed_time = toc;

%% COMPLETION 

fprintf('Pipeline execution completed!\n');
fprintf('Total time: %.1f minutes\n', elapsed_time/60);


