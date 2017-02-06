//
//  QRCodeViewController.m
//  TinyPlus
//
//  Created by 小鱼儿 on 15/11/12.
//  Copyright © 2015年 Sunline. All rights reserved.
//

#import "QRCodeViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "UIColorAdditions.h"
#import "UIView+Frame.h"

#define ScreenWidth   [[UIScreen mainScreen] bounds].size.width
#define ScreenHeight  [[UIScreen mainScreen] bounds].size.height
#define ScreenSize    [[UIScreen mainScreen] bounds].size
#define ratio         [[UIScreen mainScreen] bounds].size.width/320.0
#define kBgImgX             45*ratio
#define kBgImgY             (64+60)*ratio
#define kBgImgWidth         230*ratio

#define kScrollLineHeight   20*ratio

#define kTipY               (kBgImgY+kBgImgWidth+kTipHeight)
#define kTipHeight          40*ratio

#define kLampX              ([[UIScreen mainScreen] bounds].size.width-kLampWidth)/2
#define kLampY              ([[UIScreen mainScreen] bounds].size.height-kLampWidth-30*ratio)
#define kLampWidth          61

#define kBgAlpha            0.6

static NSString *bgImg_img = @"QRCode.bundle/scanBackground";
static NSString *Line_img = @"QRCode.bundle/scanLine";
static NSString *turn_on = @"QRCode.bundle/turn_on";
static NSString *turn_off = @"QRCode.bundle/turn_off";
static NSString *ringPath = @"QRCode.bundle/ring";
static NSString *backPath = @"QRCode.bundle/back.png";


static NSString *ringType = @"wav";

@interface QRCodeViewController ()<AVCaptureMetadataOutputObjectsDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate>
{
    NSString *QRCode;
}

#pragma mark - ---属性---
/**
 *输入输出中间桥梁(会话)
 */
@property (strong, nonatomic) AVCaptureSession *session;

/**
 *计时器
 */
@property (strong, nonatomic) CADisplayLink *link;

/**
 *实际有效扫描区域的背景图(亦或者自己设置一个边框)
 */
@property (strong, nonatomic) UIImageView *bgImg;

/**
 *有效扫描区域循环往返的一条线（这里用的是一个背景图）
 */
@property (strong, nonatomic) UIImageView *scrollLine;

/**
 *扫码有效区域外自加的文字提示
 */
@property (strong, nonatomic) UILabel *tip;

/**
 *用于控制照明灯的开启
 */
@property (strong, nonatomic) UIButton *lamp;

/**
 *用于记录scrollLine的上下循环状态
 */
@property (assign, nonatomic) BOOL up;

#pragma mark -------

@end

@implementation QRCodeViewController

#pragma mark - ---Life Cycle---
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    _up = YES;
    
    [self session];
    
    //1.添加一个可见的扫描有效区域的框（这里直接是设置一个背景图片）
    [self.view addSubview:self.bgImg];
    
    //2.添加一个上下循环运动的线条（这里直接是添加一个背景图片来运动）
    [self.view addSubview:self.scrollLine];
    
    //3.添加其他有效控件
    [self.view addSubview:self.tip];
    [self.view addSubview:self.lamp];
    [self setNavigationItem];

}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.session startRunning];
    //计时器添加到循环中去
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.session stopRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - ---lazy load---
- (UIImageView *)bgImg {
    if (!_bgImg) {
        _bgImg = [[UIImageView alloc]initWithFrame:CGRectMake(kBgImgX, kBgImgY, kBgImgWidth, kBgImgWidth)];
        _bgImg.image = [UIImage imageNamed:bgImg_img];
    }
    return _bgImg;
}

- (UIImageView *)scrollLine {
    if (!_scrollLine) {
        _scrollLine = [[UIImageView alloc]initWithFrame:CGRectMake(kBgImgX, kBgImgY, kBgImgWidth, kScrollLineHeight)];
        _scrollLine.image = [UIImage imageNamed:Line_img];
    }
    return _scrollLine;
}

- (UILabel *)tip {
    if (!_tip) {
        _tip = [[UILabel alloc]initWithFrame:CGRectMake(kBgImgX, kTipY, kBgImgWidth, kTipHeight)];
        _tip.text = @"自动扫描框内二维码/条形码";
        _tip.numberOfLines = 0;
        _tip.textColor = [UIColor whiteColor];
        _tip.textAlignment = NSTextAlignmentCenter;
        _tip.font = [UIFont systemFontOfSize:14];
    }
    return _tip;
}

- (CADisplayLink *)link {
    if (!_link) {
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(LineAnimation)];
    }
    return _link;
}

- (UIButton *)lamp {
    if (!_lamp) {
        _lamp = [[UIButton alloc]initWithFrame:CGRectMake(kLampX, kLampY, kLampWidth, kLampWidth)];
       // _lamp.alpha = kBgAlpha;
        _lamp.imageView.contentMode = UIViewContentModeScaleAspectFit;
        _lamp.selected = NO;
//        [_lamp.layer setMasksToBounds:YES];
//        [_lamp.layer setCornerRadius:kLampWidth/2];
//        [_lamp.layer setBorderWidth:2.0];
//        [_lamp.layer setBorderColor:[[UIColor whiteColor] CGColor]];
//        _lamp.backgroundColor = [UIColor whiteColor];
        [_lamp setBackgroundImage:[UIImage imageNamed:turn_off] forState:UIControlStateNormal];
        [_lamp addTarget:self action:@selector(touchLamp:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _lamp;
}

- (AVCaptureSession *)session {
    if (!_session) {
        //1.获取输入设备（摄像头）
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        //2.根据输入设备创建输入对象
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];
        if (input == nil) {
            return nil;
        }
        
        //3.创建元数据的输出对象
        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc]init];
        //4.设置代理监听输出对象输出的数据,在主线程中刷新
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        // 5.创建会话(桥梁)
        AVCaptureSession *session = [[AVCaptureSession alloc]init];
        //实现高质量的输出和摄像，默认值为AVCaptureSessionPresetHigh，可以不写
        [session setSessionPreset:AVCaptureSessionPresetHigh];
        // 6.添加输入和输出到会话中（判断session是否已满）
        if ([session canAddInput:input]) {
            [session addInput:input];
        }
        if ([session canAddOutput:output]) {
            [session addOutput:output];
        }
        
        // 7.告诉输出对象, 需要输出什么样的数据 (二维码还是条形码等) 要先创建会话才能设置
        output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode,AVMetadataObjectTypeCode128Code,AVMetadataObjectTypeEAN8Code,AVMetadataObjectTypeUPCECode,AVMetadataObjectTypeCode39Code,AVMetadataObjectTypePDF417Code,AVMetadataObjectTypeAztecCode,AVMetadataObjectTypeCode93Code,AVMetadataObjectTypeEAN13Code,AVMetadataObjectTypeCode39Mod43Code];
        
        // 8.创建预览图层
        AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        previewLayer.frame = self.view.bounds;
        [self.view.layer insertSublayer:previewLayer atIndex:0];
        
        //9.设置有效扫描区域，默认整个图层(很特别，1、要除以屏幕宽高比例，2、其中x和y、width和height分别互换位置)
        CGRect rect = CGRectMake(kBgImgY/ScreenHeight, kBgImgX/ScreenWidth, kBgImgWidth/ScreenHeight, kBgImgWidth/ScreenWidth);
        output.rectOfInterest = rect;
        
        //10.设置中空区域，即有效扫描区域(中间扫描区域透明度比周边要低的效果)
        UIView *maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:kBgAlpha];
        [self.view addSubview:maskView];
        UIBezierPath *rectPath = [UIBezierPath bezierPathWithRect:self.view.bounds];
        [rectPath appendPath:[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(kBgImgX, kBgImgY, kBgImgWidth, kBgImgWidth) cornerRadius:1] bezierPathByReversingPath]];
        CAShapeLayer *shapeLayer = [CAShapeLayer layer];
        shapeLayer.path = rectPath.CGPath;
        maskView.layer.mask = shapeLayer;
        
        _session = session;
    }
    return _session;
}


#pragma mark - ---NavigationItem---
- (void)setNavigationItem{
//    self.navigationController.navigationBar.tintColor = [UIColor blackColor];
//    self.navigationItem.title = @"二维码/条形码";
//    UIBarButtonItem *rightBtn = [[UIBarButtonItem alloc]
//                                 initWithTitle:@"相册"
//                                 style:UIBarButtonItemStylePlain
//                                 target:self
//                                 action:@selector(openPhoto)];
//    self.navigationItem.rightBarButtonItem = rightBtn;
    
    //    //页面的头部标题
    CGRect frame_1 = CGRectMake(0,0,[UIScreen mainScreen].bounds.size.width, 60);
    CGRect frame_2 = CGRectMake(0,20,[UIScreen mainScreen].bounds.size.width, 40);
    CGRect frame_3 = CGRectMake(0,20,50, 40);
    CGRect frame_4 = CGRectMake(0,[UIScreen mainScreen].bounds.size.height - 44, [UIScreen mainScreen].bounds.size.width, 44);


    UIView *header = [[UIView alloc] initWithFrame:frame_1];
    header.backgroundColor = [UIColor colorWithHex:@"#53525f"];

    UILabel *titleLabel = [[UILabel alloc]initWithFrame:frame_2];
    titleLabel.backgroundColor = [UIColor colorWithHex:@"#53525f"];
    titleLabel.textColor = [UIColor colorWithHex:@"#ffffff"];
    titleLabel.text = @"二维码/条码扫描";
    titleLabel.textAlignment = NSTextAlignmentCenter;//居中
    [self.view addSubview:header];
    [header addSubview:titleLabel];

    
    UIButton *back = [[UIButton alloc] initWithFrame:frame_3];
    back.titleLabel.font = [UIFont systemFontOfSize:24.0];
    [back setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [back addTarget:self action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:back];
    [back setImage:[UIImage imageNamed:backPath] forState:UIControlStateNormal];
    back.imageView.contentMode = UIViewContentModeScaleAspectFill;
    
    if(self.bottomTitle != nil) {
        UIButton *bottom = [[UIButton alloc] initWithFrame:frame_4];
        [bottom setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [bottom addTarget:self action:@selector(back2) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:bottom];
        [bottom setBackgroundColor:[UIColor colorWithHex:@"#53525f"]];
        [bottom setTitle:self.bottomTitle forState:UIControlStateNormal];
    }
}


//返回按钮
-(void)back
{
    [self.delegate close:0];
    [self dismissViewControllerAnimated:YES completion:nil];
}

//返回按钮
-(void)back2
{
    [self.delegate close:100];
    [self dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark - 线条运动的动画
- (void)LineAnimation {
    if (_up == YES) {
        CGFloat y = self.scrollLine.frame.origin.y;
        y += 2;
        [self.scrollLine setY:y];
        if (y >= (kBgImgY+kBgImgWidth-kScrollLineHeight)) {
            _up = NO;
        }
    }else{
        CGFloat y = self.scrollLine.frame.origin.y;
        y -= 2;
        [self.scrollLine setY:y];
        if (y <= kBgImgY) {
            _up = YES;
        }
    }
}


#pragma mark - 开灯或关灯
- (void)touchLamp:(id)sender {
    UIButton *btn = (UIButton *)sender;
    if (btn.selected == YES) {
        [btn setBackgroundImage:[UIImage imageNamed:turn_off] forState:UIControlStateNormal];
        
        [self closeFlashlight];
    }else{
        [btn setBackgroundImage:[UIImage imageNamed:turn_on] forState:UIControlStateNormal];
        
        [self openFlashlight];
    }
    btn.selected = !btn.selected;
}




#pragma mark - UIImagePickerControllerDelegate

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
// 扫描到数据时会调用
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    if (metadataObjects.count > 0) {
        // 1.停止扫描
        //        [self.session stopRunning];
        // 2.停止冲击波
        //        [self.link removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        
        // 3.取出扫描到得数据
        AVMetadataMachineReadableCodeObject *obj = [metadataObjects lastObject];
        if (obj) {
            NSLog(@"执行回调");
            //返回的结果放在 [metadataObj stringValue]中
            NSString *json = [obj stringValue];
            [self.delegate scanData:json];
            //[self performSelectorOnMainThread:@selector(stopReading) withObject:nil waitUntilDone:NO];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}



-(void)openFlashlight
{
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device.torchMode == AVCaptureTorchModeOff) {
        //Create an AV session
//        AVCaptureSession * session = [[AVCaptureSession alloc]init];
//        
//        // Create device input and add to current session
//        AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
//        [session addInput:input];
//        
//        // Create video output and add to current session
//        AVCaptureVideoDataOutput * output = [[AVCaptureVideoDataOutput alloc]init];
//        [session addOutput:output];
//        
//        // Start session configuration
//        [session beginConfiguration];
        [device lockForConfiguration:nil];
//        
        // Set torch to on
        [device setTorchMode:AVCaptureTorchModeOn];
        
        [device unlockForConfiguration];
       // [session commitConfiguration];
        
        // Start the session
//        [session startRunning];
//        
//        // Keep the session around
//        [self setAVSession:_session];
//        
//        [output release];
    }
}

-(void)closeFlashlight
{
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device.torchMode == AVCaptureTorchModeOn) {
        [device lockForConfiguration:nil];

        [device setTorchMode:AVCaptureTorchModeOff];
        [device unlockForConfiguration];

    }
//    [_session stopRunning];
//    [_session release];
}



@end
