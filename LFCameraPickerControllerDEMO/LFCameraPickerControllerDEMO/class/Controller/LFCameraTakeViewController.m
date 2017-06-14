//
//  LFCameraTakeViewController.m
//  LFCameraPickerControllerDEMO
//
//  Created by LamTsanFeng on 2017/5/11.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFCameraTakeViewController.h"
#import "LFCameraHeader.h"
#import "LFCameraPickerController.h"
#import "LFCameraDisplayController.h"

#import "UIImage+LFCamera_Orientation.h"

#import "LFRecordButton.h"
#import "SCRecorder.h"

@interface LFCameraTakeViewController () <SCRecorderDelegate, LFCameraDisplayDelegate>

/** 录制神器 */
@property (strong, nonatomic) SCRecorder *recorder;
/** 拍照图片 */
@property (strong, nonatomic) UIImage *photo;
/** 预览视图 */
@property (weak, nonatomic) UIView *previewView;
/** 录制视图 */
@property (strong, nonatomic) SCRecorderToolsView *focusView;

/** 闪光灯 */
@property (weak, nonatomic) UIButton *flashButton;
/** 摄像头切换 */
@property (weak, nonatomic) UIButton *flipCameraButton;
/** 回制按钮 */
@property (weak, nonatomic) UIButton *backToRecord;
/** 停止按钮 */
@property (weak, nonatomic) UIButton *stopButton;

/** 提示消息 */
@property (weak, nonatomic) UILabel *tipsLabel;

/** 录制按钮 */
@property (weak, nonatomic) LFRecordButton *recordButton;

@end

@implementation LFCameraTakeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor blackColor];
    
    /** 监听设备方向改变 */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    /** 初始化视图 */
    [self initView];
    
    /** 初始化Recorder */
    [self initRecorder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)deviceOrientationDidChange:(NSNotification *)notify
{
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    switch (orientation) {
        case UIDeviceOrientationPortrait:
        {
            if (self.recorder.session.segments.count == 0 && self.recorder.isRecording == NO) {
                self.recorder.videoConfiguration.affineTransform = CGAffineTransformIdentity;
                [self retakeRecordSession];
            }
            [UIView animateWithDuration:0.25f animations:^{
                self.flashButton.transform = CGAffineTransformMakeRotation(0);
                self.flipCameraButton.transform = CGAffineTransformMakeRotation(0);
            }];
        }
            break;
        case UIDeviceOrientationLandscapeLeft:
        {
            if (self.recorder.session.segments.count == 0 && self.recorder.isRecording == NO) {
                self.recorder.videoConfiguration.affineTransform = CGAffineTransformMakeRotation(-M_PI_2);
                [self retakeRecordSession];
            }
            [UIView animateWithDuration:0.25f animations:^{
                self.flashButton.transform = CGAffineTransformMakeRotation(M_PI_2);
                self.flipCameraButton.transform = CGAffineTransformMakeRotation(M_PI_2);
            }];
        }
            break;
        case UIDeviceOrientationLandscapeRight:
        {
            if (self.recorder.session.segments.count == 0 && self.recorder.isRecording == NO) {
                self.recorder.videoConfiguration.affineTransform = CGAffineTransformMakeRotation(M_PI_2);
                [self retakeRecordSession];
            }
            [UIView animateWithDuration:0.25f animations:^{
                self.flashButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
                self.flipCameraButton.transform = CGAffineTransformMakeRotation(-M_PI_2);
            }];
        }
            break;
        case UIDeviceOrientationPortraitUpsideDown:
        {
            if (self.recorder.session.segments.count == 0 && self.recorder.isRecording == NO) {
                self.recorder.videoConfiguration.affineTransform = CGAffineTransformMakeRotation(M_PI);
                [self retakeRecordSession];
            }
            [UIView animateWithDuration:0.25f animations:^{
                self.flashButton.transform = CGAffineTransformMakeRotation(M_PI);
                self.flipCameraButton.transform = CGAffineTransformMakeRotation(M_PI);
            }];
        }
            break;
        default:
            break;
    }
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self prepareSession];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    [_recorder previewViewFrameChanged];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [_recorder startRunning];
    [UIView animateWithDuration:0.25f delay:.5f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.tipsLabel.alpha = 1.f;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.25f delay:4.5f options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.tipsLabel.alpha = 0.f;
        } completion:^(BOOL finished) {
            
        }];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    self.tipsLabel.alpha = 0.f;
    /** 还原缩放 */
    _recorder.videoZoomFactor = 1;
    /** 拍照系统需要播放声音，马上关闭录制会导致声音卡顿 */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.navigationController.topViewController != self) {
            [_recorder stopRunning];
        }
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _recorder.previewView = nil;
    [_recorder.session removeAllSegments];
}

#pragma mark - SCRecorder 操作
- (void)prepareSession {
    
    if (_recorder.session == nil) {
        SCRecordSession *session = [SCRecordSession recordSession];
        session.fileType = AVFileTypeQuickTimeMovie;
        
        _recorder.session = session;
    }
    
    [self updateTimeRecorded];
}

- (void)updateTimeRecorded {
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    CMTime currentTime = kCMTimeZero;
    
    if (_recorder.session != nil) {
        currentTime = _recorder.session.duration;
    }
    
    CGFloat time = CMTimeGetSeconds(currentTime);
    self.recordButton.progress = time / cameraPicker.maxRecordSeconds;
}

- (void)saveAndShowSession:(SCRecordSession *)recordSession {
    
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    /** 非暂停模式才启用最小限制 */
    if (!cameraPicker.canPause && CMTimeGetSeconds(recordSession.duration) < cameraPicker.minRecordSeconds) {
        [self takePhoto];
    } else {
        [self showVideoView];
    }
    /** 重置录制按钮 */
    [self.recordButton reset];
    
}

- (void)retakeRecordSession {

    self.photo = nil;
    self.backToRecord.selected = NO;
    self.backToRecord.enabled = NO;
    self.stopButton.enabled = NO;
    
    SCRecordSession *recordSession = _recorder.session;
    
    if (recordSession != nil) {
        _recorder.session = nil;
        [recordSession cancelSession:nil];
    }
    
    [self prepareSession];
}

- (void)takePhoto
{
    __weak typeof(self) weakSelf = self;
    [self.recorder capturePhoto:^(NSError *error, UIImage *image) {
        if (image != nil) {
            weakSelf.photo = [image easyFixDeviceOrientation];
            [weakSelf showImageView];
        } else {
            [weakSelf showAlertViewWithTitle:@"Failed to capture photo" message:error.localizedDescription];
        }
    }];
}


#pragma mark - SCRecorderDelegate
- (void)recorder:(SCRecorder *)recorder didSkipVideoSampleBufferInSession:(SCRecordSession *)recordSession {
    NSLog(@"Skipped video buffer");
}

- (void)recorder:(SCRecorder *)recorder didReconfigureAudioInput:(NSError *)audioInputError {
    NSLog(@"Reconfigured audio input: %@", audioInputError);
}

- (void)recorder:(SCRecorder *)recorder didReconfigureVideoInput:(NSError *)videoInputError {
    NSLog(@"Reconfigured video input: %@", videoInputError);
}

- (void)recorder:(SCRecorder *)recorder didCompleteSession:(SCRecordSession *)recordSession {
    NSLog(@"didCompleteSession:");
    [self saveAndShowSession:recordSession];
}

- (void)recorder:(SCRecorder *)recorder didInitializeAudioInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized audio in record session");
    } else {
        NSLog(@"Failed to initialize audio in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didInitializeVideoInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized video in record session");
    } else {
        NSLog(@"Failed to initialize video in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didBeginSegmentInSession:(SCRecordSession *)recordSession error:(NSError *)error {
    NSLog(@"Began record segment: %@", error);
}

- (void)recorder:(SCRecorder *)recorder didCompleteSegment:(SCRecordSessionSegment *)segment inSession:(SCRecordSession *)recordSession error:(NSError *)error {
    NSLog(@"Completed record segment at %@: %@ (frameRate: %f)", segment.url, error, segment.frameRate);
    self.backToRecord.enabled = YES;
    self.stopButton.enabled = YES;
}

- (void)recorder:(SCRecorder *)recorder didAppendVideoSampleBufferInSession:(SCRecordSession *)recordSession {
    [self updateTimeRecorded];
}

#pragma mark - LFCameraDisplayDelegate
- (void)lf_cameraDisplayDidCancel:(LFCameraDisplayController *)cameraDisplay
{
    [self retakeRecordSession];
    [self.navigationController popViewControllerAnimated:NO];
}
- (void)lf_cameraDisplay:(LFCameraDisplayController *)cameraDisplay didFinishVideo:(NSURL *)videoURL
{
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    /** 代理回调 */
    if ([cameraPicker.pickerDelegate respondsToSelector:@selector(lf_cameraPickerController:didFinishPickingVideo:duration:)]) {
        [cameraPicker.pickerDelegate lf_cameraPickerController:cameraPicker didFinishPickingVideo:videoURL duration:CMTimeGetSeconds(self.recorder.session.duration)];
    }
    [cameraPicker dismissViewControllerAnimated:YES completion:nil];
}
- (void)lf_cameraDisplay:(LFCameraDisplayController *)cameraDisplay didFinishImage:(UIImage *)image
{
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    /** 代理回调 */
    if ([cameraPicker.pickerDelegate respondsToSelector:@selector(lf_cameraPickerController:didFinishPickingImage:)]) {
        [cameraPicker.pickerDelegate lf_cameraPickerController:cameraPicker didFinishPickingImage:image];
    }
    [cameraPicker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - 点击事件操作
- (void)closeAction
{
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    /** 代理回调 */
    if ([cameraPicker.pickerDelegate respondsToSelector:@selector(lf_cameraPickerDidCancel:)]) {
        [cameraPicker.pickerDelegate lf_cameraPickerDidCancel:cameraPicker];
    }
    [cameraPicker dismissViewControllerAnimated:YES completion:nil];
}

- (void)stopAction
{
    __weak typeof(self) weakSelf = self;
    [self.recorder pause:^{
        [weakSelf saveAndShowSession:weakSelf.recorder.session];
    }];
}

- (void)flipCameraAction
{
    [_recorder switchCaptureDevices];
}

- (void)flashAction:(UIButton *)button
{
    switch (_recorder.flashMode) {
        case SCFlashModeOff:
            _recorder.flashMode = SCFlashModeAuto;
            [button setImage:LFCamera_bundleImageNamed(@"LFCamera_flashlight_auto") forState:UIControlStateNormal];
            break;
        case SCFlashModeAuto:
            _recorder.flashMode = SCFlashModeOn;
            [button setImage:LFCamera_bundleImageNamed(@"LFCamera_flashlight_on") forState:UIControlStateNormal];
            break;
        case SCFlashModeOn:
            _recorder.flashMode = SCFlashModeLight;
            [button setImage:LFCamera_bundleImageNamed(@"LFCamera_flashlight_light") forState:UIControlStateNormal];
            break;
        case SCFlashModeLight:
            _recorder.flashMode = SCFlashModeOff;
            [button setImage:LFCamera_bundleImageNamed(@"LFCamera_flashlight_off") forState:UIControlStateNormal];
            break;
        default:
            break;
    }
}

- (void)selectedOrDeleteLastProgress:(UIButton *)button
{
    if (button.isSelected) {
        [self.recordButton deleteSelectedProgress];
        [self.recorder.session removeLastSegment];
        button.selected = NO;
        /** 删除后，进度被重置，关闭按钮 */
        if (self.recordButton.progress == 0) {
            self.backToRecord.enabled = NO;
            self.stopButton.enabled = NO;
        }
    } else {
        button.selected = [self.recordButton selectedLastProgress];
    }
    
}

#pragma mark - previte
#pragma mark - 初始化视图
- (void)initView
{
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    __weak typeof(self) weakSelf = self;
    __weak typeof(cameraPicker) weakCameraPicker = cameraPicker;
    
    /** 预览视图 */
    UIView *previewView = [[UIView alloc] initWithFrame:self.view.bounds];
    previewView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:previewView];
    self.previewView = previewView;
    
    CGFloat width = CGRectGetWidth(self.view.frame);
    CGFloat height = CGRectGetHeight(self.view.frame);
    
    /** 底部工具栏 */
    UIView *boomView = [[UIView alloc] initWithFrame:CGRectMake(0, height-LFCamera_boomViewHeight-LFCamera_boomMargin, width, LFCamera_boomViewHeight)];
    [self.view addSubview:boomView];
    
    /** 底部工具栏 - 开始按钮 */
    LFRecordButton *recordButton = [[LFRecordButton alloc] initWithFrame:CGRectMake((CGRectGetWidth(boomView.frame)-LFCamera_recordButtonHeight)/2, (CGRectGetHeight(boomView.frame)-LFCamera_recordButtonHeight)/2, LFCamera_recordButtonHeight, LFCamera_recordButtonHeight)];
    recordButton.onlySingleTap = (cameraPicker.cameraType == LFCameraType_Photo);
    recordButton.onlyLongTap = (cameraPicker.cameraType == LFCameraType_Video);
    recordButton.special = (cameraPicker.cameraType&LFCameraType_Video && cameraPicker.canPause);
    /** 单击 */
    recordButton.didTouchSingle = ^{
        [weakSelf takePhoto];
    };
    /** 长按开始 */
    recordButton.didTouchLongBegan = ^{
        weakSelf.backToRecord.selected = NO;
        [weakSelf.recorder record];
    };
    /** 长按结束 */
    recordButton.didTouchLongEnd = ^{
        
        if (weakCameraPicker.canPause) { /** 拍摄暂停模式 */
            [weakSelf.recorder pause];
        } else {
            [weakSelf stopAction];
        }
    };
    
    
    /** 移动 */
    recordButton.didTouchLongMove = ^(CGPoint screenPoint) {
        /**
         * 公式1：(x+y)/2+y=中间值
         * 公式2：z/(x+y)*(x1+y1)=z1 顺序
         * 公式3：(x1+y1)-z/(x+y)*(x1+y1)=z1 倒序
         */
        CGFloat x = 0, y = 0, z = screenPoint.y, x1 = weakSelf.focusView.minZoomFactor, y1 = weakSelf.focusView.maxZoomFactor, z1 = 0;
        /** 从下往上 递减 */
        x = CGRectGetHeight(weakSelf.view.frame)*.6;
        y = CGRectGetHeight(weakSelf.view.frame)*.4;
        
        /** 代入公式 */
        z1 = (x1+y1)-z/(x+y)*(x1+y1);
        weakSelf.recorder.videoZoomFactor = MIN(MAX(z1, x1), y1);
    };
    [boomView addSubview:recordButton];
    self.recordButton = recordButton;
    
    if (cameraPicker.cameraType&LFCameraType_Video && cameraPicker.canPause) {
        /** 底部工具栏 - 选择／删除按钮 */
        UIButton *backToRecord = [UIButton buttonWithType:UIButtonTypeCustom];
        backToRecord.frame = CGRectMake((CGRectGetMinX(recordButton.frame)-LFCamera_buttonHeight)/2, (CGRectGetHeight(boomView.frame)-LFCamera_buttonHeight)/2, LFCamera_buttonHeight, LFCamera_buttonHeight);
        [backToRecord setImage:LFCamera_bundleImageNamed(@"LFCamera_backTo") forState:UIControlStateNormal];
        [backToRecord setImage:LFCamera_bundleImageNamed(@"LFCamera_DeleteBtn") forState:UIControlStateSelected];
        [backToRecord addTarget:self action:@selector(selectedOrDeleteLastProgress:) forControlEvents:UIControlEventTouchUpInside];
        backToRecord.enabled = NO;
        [boomView addSubview:backToRecord];
        self.backToRecord = backToRecord;
        /** 底部工具栏 - 完成按钮 */
        UIButton *stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        stopButton.frame = CGRectMake((CGRectGetWidth(boomView.frame)-CGRectGetMaxX(recordButton.frame)-LFCamera_buttonHeight)/2+CGRectGetMaxX(recordButton.frame), (CGRectGetHeight(boomView.frame)-LFCamera_buttonHeight)/2, LFCamera_buttonHeight, LFCamera_buttonHeight);
        [stopButton setImage:LFCamera_bundleImageNamed(@"LFCamera_stop") forState:UIControlStateNormal];
        [stopButton addTarget:self action:@selector(stopAction) forControlEvents:UIControlEventTouchUpInside];
        stopButton.enabled = NO;
        [boomView addSubview:stopButton];
        self.stopButton = stopButton;
    } else {
        /** 底部工具栏 - 关闭按钮 */
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.frame = CGRectMake((CGRectGetMinX(recordButton.frame)-LFCamera_buttonHeight)/2, (CGRectGetHeight(boomView.frame)-LFCamera_buttonHeight)/2, LFCamera_buttonHeight, LFCamera_buttonHeight);
        [closeButton setImage:LFCamera_bundleImageNamed(@"LFCamera_back") forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(closeAction) forControlEvents:UIControlEventTouchUpInside];
        [boomView addSubview:closeButton];
    }
    
    /** 顶部栏 */
    UIView *topView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, LFCamera_topViewHeight)];
    [self.view addSubview:topView];
    
    /** 顶部栏 - 关闭按钮 */
    if (cameraPicker.cameraType&LFCameraType_Video && cameraPicker.canPause) {
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        closeButton.frame = CGRectMake(10, 5, CGRectGetHeight(topView.frame) - 10, CGRectGetHeight(topView.frame) - 10);
        [closeButton setImage:LFCamera_bundleImageNamed(@"LFCamera_close") forState:UIControlStateNormal];
        [closeButton addTarget:self action:@selector(closeAction) forControlEvents:UIControlEventTouchUpInside];
        [topView addSubview:closeButton];
    }
    
    /** 顶部栏 - 摄像头切换按钮 */
    UIButton *flipCameraButton = nil;
    if (cameraPicker.flipCamera) {
        flipCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        flipCameraButton.frame = CGRectMake(width - CGRectGetHeight(topView.frame) - 10, 5, CGRectGetHeight(topView.frame)-10, CGRectGetHeight(topView.frame)-10);
        [flipCameraButton setImage:LFCamera_bundleImageNamed(@"LFCamera_flip_camera") forState:UIControlStateNormal];
        [flipCameraButton addTarget:self action:@selector(flipCameraAction) forControlEvents:UIControlEventTouchUpInside];
        [topView addSubview:flipCameraButton];
        self.flipCameraButton = flipCameraButton;
    }
    
    /** 顶部栏 - 闪光灯按钮 */
    if (cameraPicker.flash) {
        UIButton *flashButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat tmpWidth = flipCameraButton ? CGRectGetMinX(flipCameraButton.frame) : width;
        flashButton.frame = CGRectMake(tmpWidth - CGRectGetHeight(topView.frame) - 10, 5, CGRectGetHeight(topView.frame)-10, CGRectGetHeight(topView.frame)-10);
        [flashButton setImage:LFCamera_bundleImageNamed(@"LFCamera_flashlight_auto") forState:UIControlStateNormal];
        [flashButton addTarget:self action:@selector(flashAction:) forControlEvents:UIControlEventTouchUpInside];
        [topView addSubview:flashButton];
        self.flashButton = flashButton;
    }
    
    /** 提示消息 */
    UILabel *tipsLabel = [[UILabel alloc] init];
    tipsLabel.text = @"轻触拍照，按住摄像";
    tipsLabel.font = [UIFont boldSystemFontOfSize:13.f];
    tipsLabel.textColor = [UIColor whiteColor];
    tipsLabel.highlighted = YES;
    tipsLabel.highlightedTextColor = [UIColor whiteColor];
    tipsLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    tipsLabel.layer.shadowOpacity = 1.f;
    tipsLabel.layer.shadowOffset = CGSizeMake(0, 0);
    tipsLabel.layer.shadowRadius = 8;
    CGSize tipsTextSize = [tipsLabel.text sizeWithAttributes:@{NSFontAttributeName:tipsLabel.font, NSForegroundColorAttributeName:tipsLabel.textColor}];
    tipsLabel.frame = CGRectMake((CGRectGetWidth(self.view.frame)-tipsTextSize.width)/2, CGRectGetMinY(boomView.frame)-tipsTextSize.height-5, tipsTextSize.width, tipsTextSize.height);
    tipsLabel.alpha = 0.f;
    [self.view insertSubview:tipsLabel belowSubview:boomView];
    self.tipsLabel = tipsLabel;
}

#pragma mark - 初始化Recorder
- (void)initRecorder
{
#if !TARGET_OS_SIMULATOR
    LFCameraPickerController *cameraPicker = (LFCameraPickerController *)self.navigationController;
    
    _recorder = [SCRecorder recorder];
    _recorder.captureSessionPreset = [SCRecorderTools bestCaptureSessionPresetCompatibleWithAllDevices];
    _recorder.maxRecordDuration = CMTimeMake(cameraPicker.framerate * cameraPicker.maxRecordSeconds, (int32_t)cameraPicker.framerate);
    
    //    _recorder.fastRecordMethodEnabled = YES;
    if (cameraPicker.frontCamera) {
        _recorder.device = AVCaptureDevicePositionFront;
    }
    if (cameraPicker.flash) {
        _recorder.flashMode = SCFlashModeAuto;
    }
    
    _recorder.delegate = self;
    //    _recorder.autoSetVideoOrientation = YES; //YES causes bad orientation for video from camera roll
    //    _recorder.videoConfiguration.size = CGSizeMake(640, 480);
    
    UIView *previewView = self.previewView;
    _recorder.previewView = previewView;
    
    self.focusView = [[SCRecorderToolsView alloc] initWithFrame:previewView.bounds];
    self.focusView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    self.focusView.recorder = _recorder;
    [previewView addSubview:self.focusView];
    
    self.focusView.outsideFocusTargetImage = LFCamera_bundleImageNamed(@"LFCamera_scan_focus");
    //    self.focusView.insideFocusTargetImage = LFCamera_bundleImageNamed(@"LFCamera_scan_focus");
    
    _recorder.initializeSessionLazily = NO;
    
    NSError *error;
    if (![_recorder prepare:&error]) {
        NSLog(@"Prepare error: %@", error.localizedDescription);
    }
#endif
    
    /** 设备不支持闪光灯 */
    if (self.flashButton && self.recorder.deviceHasFlash == NO) {
        [self.flashButton removeFromSuperview];
        self.flashButton = nil;
    }
}

#pragma mark - 显示拍照图片
- (void)showImageView
{
    LFCameraDisplayController *cameraDisplay = [[LFCameraDisplayController alloc] init];
    cameraDisplay.delegate = self;
    cameraDisplay.photo = self.photo;
    [self.navigationController pushViewController:cameraDisplay animated:NO];
}

#pragma mark - 显示录制视频
- (void)showVideoView
{
    LFCameraDisplayController *cameraDisplay = [[LFCameraDisplayController alloc] init];
    cameraDisplay.delegate = self;
    cameraDisplay.photo = ((SCRecordSessionSegment *)self.recorder.session.segments.lastObject).thumbnail;
    cameraDisplay.recordSession = self.recorder.session;
    [self.navigationController pushViewController:cameraDisplay animated:NO];
}

@end
