function imdb = kapukSetup(varargin)
% KAPUKSETUP setup data from the KAPUK3700
%
% This script was sourced from the Matconvnet-fcn project, written by 
% Sebastien Erhardt and Andrea Vedaldi:
% https://github.com/vlfeat/matconvnet-fcn

  opts.edition = '3700' ;
  opts.dataDir = fullfile('data','kapuk3700') ;
  opts.includeDetection = true ;
  opts = vl_argparse(opts, varargin) ;

  % Source images and classes
  imdb.paths.image = esc(fullfile(opts.dataDir, 'img', '%s.jpg')) ;
  imdb.sets.id = uint8([1 2 3]) ;
  imdb.sets.name = {'train', 'val', 'test'} ;
  imdb.classes.id = uint8(1:20) ;
  imdb.classes.name = {...
    'aeroplane', 'bicycle', 'bird', 'boat', 'bottle', 'bus', 'car', ...
    'cat', 'chair', 'cow', 'diningtable', 'dog', 'horse', 'motorbike', ...
    'person', 'pottedplant', 'sheep', 'sofa', 'train', 'tvmonitor'} ;
  imdb.classes.images = cell(1,20) ;
  imdb.images.id = [] ;
  imdb.images.name = {} ;
  imdb.images.set = [] ;
  index = containers.Map() ;
  [imdb, index] = kapuk_addImageSet(opts, imdb, index, 'train', 1) ;

  % Compress data types
  imdb.images.id = uint32(imdb.images.id) ;
  imdb.images.set = uint8(imdb.images.set) ;
  for i=1:20
    imdb.classes.images{i} = uint32(imdb.classes.images{i}) ;
  end

  % Source detections
  if opts.includeDetection
    imdb = kapuk_addDetections(opts, imdb) ;
  end
  
  % Check images on disk and get their size
  imdb = kapuk_getImageSizes(imdb) ;

% -------------------------------------------------------------------------
function [imdb, index] = kapuk_addImageSet(opts, imdb, index, setName, setCode)
% -------------------------------------------------------------------------
% ONLY for aeroplane

j = length(imdb.images.id) ;
listFiles = dir(fullfile(opts.dataDir, 'img', '*.jpg'));
ci = 1; % class index for aeroplane
  className = imdb.classes.name{ci} ;
  names = {listFiles(:).name};
  for i=1:length(listFiles)
    filepath = fullfile(opts.dataDir, 'img', listFiles(i).name);
    fprintf('%s: reading %s\n', mfilename, filepath) ;
    [~,names{i},~] = fileparts(names{i});
    if ~index.isKey(names{i})
      j = j + 1 ;
      index(names{i}) = j ;
      imdb.images.id(j) = j ;
      imdb.images.set(j) = setCode ;
      imdb.images.name{j} = names{i} ;
      imdb.images.classification(j) = true ;
    else
      j = index(names{i}) ;
    end
    imdb.classes.images{ci}(end+1) = j ;
  end

% -------------------------------------------------------------------------
function imdb = kapuk_getImageSizes(imdb)
% -------------------------------------------------------------------------
  for j=1:numel(imdb.images.id)
    info = imfinfo(sprintf(imdb.paths.image, imdb.images.name{j})) ;
    imdb.images.size(:,j) = uint16([info.Width ; info.Height]) ;
    msg = '%s: checked image %s [%d x %d]\n' ;
    fprintf(msg, mfilename, imdb.images.name{j}, info.Height, info.Width) ;
  end

% -------------------------------------------------------------------------
function imdb = kapuk_addDetections(opts, imdb)
% -------------------------------------------------------------------------
  rois = {} ; k = 0 ; msg = '%s: getting detections for %d images\n' ;
  fprintf(msg, mfilename, numel(imdb.images.id)) ;
  gtFilename = fullfile(opts.dataDir,'groundtruth_rect.mat');
  load(gtFilename, 'gTruth');
  assert(isempty(gTruth) ~= 1, ['No initial position or ground truth to load ("' gtFilename '").'])
  for j=1:numel(imdb.images.id)
    fprintf('.') ; if mod(j,80)==0,fprintf('\n') ; end
    name = imdb.images.name{j} ;
    [~,gt_name,~] = fileparts(gTruth.DataSource.Source{j});
    assert( strcmp(name,gt_name), 'Filename name must be similar with the ground truth name')
    gtRect = gTruth.LabelData.puing{j};
    assert( ~isempty(gtRect), sprintf('Found empty ground truth %s.jpg', name) );
    
    for q = 1:size(gtRect,1)
      xmin = gtRect(q,1);
      ymin = gtRect(q,2);
      xmax = gtRect(q,1) + gtRect(q,3);
      ymax = gtRect(q,2) + gtRect(q,4);
      
      k = k + 1 ; roi.id = k ;
      roi.image = imdb.images.id(j) ;
      roi.class = find(strcmp(imdb.classes.name{1}, imdb.classes.name)) ; % aeroplane class only
      roi.box = [xmin;ymin;xmax;ymax] ;
      rois{k} = roi ; %#ok
    end
  end
  fprintf('\n') ;

  rois = horzcat(rois{:}) ;
  imdb.objects = struct(...
      'id', uint32([rois.id]), ...
      'image', uint32([rois.image]), ...
      'class', uint8([rois.class]), ...
      'box', single([rois.box])) ;
  
% -------------------------------------------------------------------------
function str=esc(str)
% -------------------------------------------------------------------------
  str = strrep(str, '\', '\\') ;
