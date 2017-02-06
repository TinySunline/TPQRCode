//
//  QRCodeViewController.h
//  TinyPlus
//
//  Created by 小鱼儿 on 15/11/12.
//  Copyright © 2015年 Sunline. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol QRCodeDelegate <NSObject>

-(void)scanData:(NSString *)data;

-(void)close:(NSInteger)type;

@end

@interface QRCodeViewController : UIViewController

@property(nonatomic, strong) id<QRCodeDelegate> delegate;

@property(nonatomic, strong) NSString *bottomTitle;



@end


