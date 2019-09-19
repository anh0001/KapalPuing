## KapalPuing
Wreckage airplane detector from UAV view using deep learning.
This code is modified from https://github.com/albanie/mcnSSD.

### Requirements

* `matconvnet (tested with v1.0-beta25)`
* `MATLAB (tested with 2018a)`

### Installation

* Install MatConvNet follow http://www.vlfeat.org/matconvnet/install/
* Run the script, change the MatConvNet path accordingly
```
run setup_kapal.m
run compile_kapal.m
```

### Training model

* Clone the wreckage airplane dataset KAPUK3700 from https://github.com/anh0001/KAPUK3700 and place it to the folder matconvnet/data/datasets
* Copy paste the KAPUK3700 test images to KapalPuing/misc/data
* Run this script
```
kapal_kapuk_train.m
```

### Demo

Change the deep model from the script.
```
run_kapal_dataset.m
run_kapal_video.m
```
