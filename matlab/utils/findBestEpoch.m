function bestEpoch = findBestEpoch(expDir, varargin)
%FINDBESTEPOCH finds the best epoch of training
%   FINDBESTEPOCH(EXPDIR) evaluates the checkpoints
%   (the `net-epoch-%d.mat` files created during
%   training) in EXPDIR 
%
%   FINDBESTEPOCH(..., 'option', value, ...) accepts the following
%   options:
%
%   `priorityMetric`:: 'classError'
%    Determines the highest priority metric by which to rank the 
%    checkpoints.
%
%   `prune`:: false
%    Removes all saved checkpoints to save space except:
%
%       1. The checkpoint with the lowest validation error metric
%       2. The last checkpoint

opts.prune = false ;
opts.priorityMetric = 'classError' ;
opts = vl_argparse(opts, varargin) ;

lastEpoch = findLastCheckpoint(expDir);

% return if no checkpoints were found
if ~lastEpoch
    return
end

bestEpoch = findBestValCheckpoint(expDir, opts.priorityMetric);
preciousEpochs = [bestEpoch lastEpoch];
if opts.prune
  removeOtherCheckpoints(expDir, preciousEpochs);
  fprintf('----------------------- \n');
  fprintf('%s directory cleaned: \n', expDir);
  fprintf('----------------------- \n');
end

% -------------------------------------------------------------------------
function removeOtherCheckpoints(expDir, preciousEpochs)
% -------------------------------------------------------------------------
list = dir(fullfile(expDir, 'net-epoch-*.mat')) ;
tokens = regexp({list.name}, 'net-epoch-([\d]+).mat', 'tokens') ;
epochs = cellfun(@(x) sscanf(x{1}{1}, '%d'), tokens) ;
targets = ~ismember(epochs, preciousEpochs);
files = cellfun(@(x) fullfile(expDir, sprintf('net-epoch-%d.mat', x)), ...
        num2cell(epochs(targets)), 'UniformOutput', false);
cellfun(@(x) delete(x), files)

% -------------------------------------------------------------------------
function bestEpoch = findBestValCheckpoint(expDir, priorityMetric)
% -------------------------------------------------------------------------

lastEpoch = findLastCheckpoint(expDir) ;

% handle the different storage structures/error metrics
data = load(fullfile(expDir, sprintf('net-epoch-%d.mat', lastEpoch)));
if isfield(data, 'stats')
    valStats = data.stats.val;
elseif isfield(data, 'info')
    valStats = data.info.val;
else
    error('storage structure not recognised');
end

% find best checkpoint according to the following priority
metrics = {priorityMetric, 'top1error', 'error', 'mbox_loss', 'class_loss'} ;

for i = 1:numel(metrics)
    if isfield(valStats, metrics{i})
        errorMetric = [valStats.(metrics{i})] ;
        break ;
    end
end

assert(logical(exist('errorMetric')), 'error metrics not recognized') ;
[~, bestEpoch] = min(errorMetric);

% -------------------------------------------------------------------------
function epoch = findLastCheckpoint(expDir)
% -------------------------------------------------------------------------

list = dir(fullfile(expDir, 'net-epoch-*.mat')) ;
tokens = regexp({list.name}, 'net-epoch-([\d]+).mat', 'tokens') ;
epoch = cellfun(@(x) sscanf(x{1}{1}, '%d'), tokens) ;
epoch = max([epoch 0]) ;
