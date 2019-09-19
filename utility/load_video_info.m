function [img_files, pos, target_sz, ground_truth, video_path] = load_video_info(base_path, video)
%LOAD_VIDEO_INFO
%   Loads all the relevant information for the video in the given path:
%   the list of image files (cell array of strings), initial position
%   (1x2), target size (1x2), the ground truth information for precision
%   calculations (Nx2, for N frames), and the path where the images are
%   located. The ordering of coordinates and sizes is always [y, x].
%
%   Joao F. Henriques, 2014
%   http://www.isr.uc.pt/~henriques/


    pos=[];
    target_sz=[];
    ground_truth=[];

	%see if there's a suffix, specifying one of multiple targets, for
	%example the dot and number in 'Jogging.1' or 'Jogging.2'.
	if numel(video) >= 2 && video(end-1) == '.' && ~isnan(str2double(video(end)))
		suffix = video(end-1:end);  %remember the suffix
		video = video(1:end-2);  %remove it from the video name
	else
		suffix = '';
	end

	%full path to the video's files
	if base_path(end) ~= '/' && base_path(end) ~= '\'
		base_path(end+1) = '/';
	end
	video_path = [base_path video '/'];

	%try to load ground truth from text file (Benchmark's format)
	filename = [video_path 'groundtruth_rect' suffix '.mat'];
    load(filename, 'gTruth');
	assert(isempty(gTruth) ~= 1, ['No initial position or ground truth to load ("' filename '").'])
	
    video_path = [video_path 'img/'];
%     oldPath = '/home/ilham/research/Dataset/data_test/';
    ground_truth = gTruth;
	
	
	%from now on, work in the subfolder where all the images are
	
    %general case, just list all images
    img_files = dir([video_path '*.png']);
    if isempty(img_files)
        img_files = dir([video_path '*.jpg']);
        assert(~isempty(img_files), 'No image files to load.')
    end
    img_files = sort({img_files.name});
	
	
end

