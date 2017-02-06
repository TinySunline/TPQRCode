//
//  QRCodeReader.h
//  TinyPlus
//
//  Created by 小鱼儿 on 15/11/9.
//  Copyright © 2015年 Sunline. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JSExport.h>
#import <UIKit/UIKit.h>
#import "QRCodeViewController.h"

@protocol QRCodeReaderProtocol <JSExport>

@property(nonatomic, strong) JSValue *success;

@property(nonatomic, strong) JSValue *error;

@property(nonatomic, strong) NSString *bottomTitle;

- (void)startReading;     //开始扫描二维码

@end

@interface TPQRCode : NSObject<QRCodeReaderProtocol, QRCodeDelegate>

@property(nonatomic, assign) UIViewController *viewController;

@end
