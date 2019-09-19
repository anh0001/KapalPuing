function run_kapal_dataset(varargin)
%run_kapal_dataset Minimalistic demonstration of the detector
%   run_kapal_dataset an object detection
%
%   run_kapal_dataset(..., 'option', value, ...) accepts the following
%   options:
%
%   `modelPath`:: ''
%    Path to a valid R-FCN matconvnet model. If none is provided, a model
%    will be downloaded.
%
%   `gpu`:: []
%    Device on which to run network 
%
%   `wrapper`:: 'autonn'
%    The matconvnet wrapper to be used (both dagnn and autonn are supported) 

  opts.gpu = [] ;
  opts.gpu = 1 ;
  opts.modelPath = '' ;
  opts.wrapper = 'autonn' ;
  opts = vl_argparse(opts, varargin) ;

  % The network is trained to prediction occurences
  % of the following classes from the pascal VOC challenge
  classes = {'background', 'wreckage', 'bicycle', 'bird', ...
     'boat', 'bottle', 'bus', 'car', 'cat', 'chair', 'cow', 'diningtable', ...
     'dog', 'horse', 'motorbike', 'person', 'pottedplant', 'sheep', ...
     'sofa', 'train', 'tvmonitor'} ;
  desiredClassNumber = 2;
  thresholdConfidence = 0.01; % Default is set to the lowest confidence threshold
  

  % Load or download an example SSD model:
%   modelName = 'ssd-mcn-pascal-vggvd-300.mat';
%   modelName = 'ssd-pascal-mobilenet-ft-300.mat';
%   modelName = 'ssd-mcn-pascal-vggvd-512.mat';
%   modelName = 'mcn-vgg16-voc0712-300-owntrain.mat';
  modelName = 'mcn-vgg16-voc0712-kapuk3700-300-owntrain.mat';
  
  paths = {opts.modelPath, ...
           modelName, ...
           fullfile(vl_rootnn, 'data/models', modelName), ...
           fullfile(vl_rootnn, 'data', 'models-import', modelName)} ;
  ok = find(cellfun(@(x) exist(x, 'file'), paths), 1) ;

  if isempty(ok)
    fprintf('Downloading the SSD model ... this may take a while\n') ;
    opts.modelPath = fullfile(vl_rootnn, 'data/models', modelName) ;
    mkdir(fileparts(opts.modelPath)) ;
    base = 'http://www.robots.ox.ac.uk/~albanie/models/ssd/%s' ;
    url = sprintf(base, modelName) ; urlwrite(url, opts.modelPath) ;
  else
    opts.modelPath = paths{ok} ;
  end

  % Load the network with the chosen wrapper
  net = loadModel(opts) ;

  % Evaluate network either on CPU or GPU.
  if numel(opts.gpu) > 0
    gpuDevice(opts.gpu) ; net.move('gpu');
  end
  
  
  base_path ='./misc/data/';
  % Load video
  video = choose_video(base_path);
  [img_files, pos, target_sz, ground_truth, video_path] = load_video_info(base_path, video);
  
  num_files = length(img_files);
  % Create a table to store the results.
  results(num_files) = struct('Boxes',[],'Scores',[]);
  for i = 1:num_files
      im_ori = imread(strcat(video_path,img_files{i}));
      im = single(im_ori);
      im = imresize(im, net.meta.normalization.imageSize(1:2)) ;

      % Evaluate network either on CPU or GPU.
      if numel(opts.gpu) > 0
        im = gpuArray(im);
      end

      % set inputs and run network
      switch opts.wrapper
        case 'dagnn' 
          net.eval({'data', im}) ;
          preds = net.vars(end).value ;
        case 'autonn'
          net.eval({'data', im}, 'test') ;
          preds = net.getValue('detection_out') ;
      end

      [~, sortedIdx ] = sort(preds(:, 2), 'descend') ;
      preds = preds(sortedIdx, :) ;

      % Filter only to the desired class
      preds = preds(preds(:,1)==desiredClassNumber, :);
      % threshold based on confidence value
      preds = preds(preds(:,2)>thresholdConfidence, :);
      numKeep = size(preds,1);

      % Extract the most confident predictions
      box = double(preds(1:numKeep,3:end)) ;
      confidence = preds(1:numKeep,2) ;
      label = classes(preds(1:numKeep,1)) ;

      % Return image to cpu for visualisation
      if numel(opts.gpu) > 0, im = gather(im) ; end

      %
      x = box(:,1) * size(im_ori, 2) ; y = box(:,2) * size(im_ori, 1) ;
      width = box(:,3) * size(im_ori, 2) - x ; height = box(:,4) * size(im_ori, 1) - y ;
      rectangle = [x y width height];
      gt_rectangle = ground_truth.LabelData.puing{i};
      
      % 
      results(i).Boxes = rectangle;
      results(i).Scores = confidence;
      
      % Diplay prediction as a sanity check
      figure(1);
      im = im / 255 ; CM = spring(numKeep);
      x = box(:,1) * size(im, 2) ; y = box(:,2) * size(im, 1);
      width = box(:,3) * size(im, 2) - x ; height = box(:,4) * size(im, 1) - y ;
      rectangle = [x y width height];
      im = insertShape(single(im), 'Rectangle', rectangle, 'LineWidth', 4, ...
                         'Color', CM(1:numKeep,:));
%       im_ori = insertShape(im_ori, 'Rectangle', gt_rectangle, 'LineWidth', 4, ...
%                          'Color', 'yellow') ;
      imagesc(im);
      title(sprintf('Image-%d',i), ...
                       'FontSize', 15) ;
      for ii = 1:numKeep
        str = sprintf('%s: %.2f', label{ii}, confidence(ii)) ;
        text(x(ii), y(ii)-10, str, 'FontSize', 14, ...
            'BackgroundColor', CM(ii,:)) ;
      end
      
      axis off ;
      

  end
  
  % Free up the GPU allocation
  if numel(opts.gpu) > 0, net.move('cpu') ; end

  % Compute AP, precision, and recall
  thresholds = 0.01 : 0.05 : 1.0;
  num_thresh = length(thresholds);
  evaluation(num_thresh) = struct('AP',[],'Precision',[],'Recall',[]);
  for i = 1 : num_thresh
    threshold = thresholds(i);
    res = thresholdBoundingBoxResults(results, threshold);
    res = struct2table(res);
    [ap,recall,precision] = evaluateDetectionPrecision(res, ground_truth.LabelData);
    
    evaluation(i).AP = ap;
    evaluation(i).Recall = recall;
    evaluation(i).Precision = precision;
  end
  
  % Plot Precision and Recall curve for the specified threshold confidence
  figure(2)
  hold on
  threshold = 0.2;
  i = find(thresholds >= threshold);
  i = i(1);
  plot(evaluation(i).Recall, evaluation(i).Precision)
  xlabel('Recall'); ylabel('Precision');
  legend(sprintf('thresh=%.2f', thresholds(i)));
  grid on
  hold off
  
%   % Plot Precision and Recall curve for all thresholds confidence
%   figure(2)
%   hold on
%   for i=1:num_thresh
%     plot(evaluation(i).Recall, evaluation(i).Precision)
%   end
%   xlabel('Recall'); ylabel('Precision');
%   grid on
%   hold off
  
  % plot average precision
  figure(3)
  hold on
  plot(thresholds, [evaluation(:).AP])
  xlabel('Confidence Threshold');ylabel('Average Precision');
  grid on
  hold off
  
  %title(sprintf('Average Precision = %.3f',ap))
  
% ----------------------------
function net = loadModel(opts)
% ----------------------------
  net = load(opts.modelPath) ; 
  if ~isfield(net, 'forward') % dagnn loader
    net = dagnn.DagNN.loadobj(net) ;
    switch opts.wrapper
      case 'dagnn' 
        net.mode = 'test' ; 
      case 'autonn'
        out = Layer.fromDagNN(net, @extras_autonn_custom_fn) ; 
        net = Net(out{:}) ;
    end
  else % load directly using autonn
    net = Net(net) ;
  end

  
% ----------------------------
function res = thresholdBoundingBoxResults(results, threshold)
% ----------------------------
    res = results;
    num_data = size(results,2);
    for i=1:num_data
        idx = res(i).Scores < threshold;
        res(i).Scores(idx) = [];
        res(i).Boxes(idx,:) = [];
    end

