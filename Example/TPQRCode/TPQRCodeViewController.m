//
//  TPQRCodeViewController.m
//  TPQRCode
//
//  Created by sunjf@sunline.cn on 02/06/2017.
//  Copyright (c) 2017 sunjf@sunline.cn. All rights reserved.
//

#import "TPQRCodeViewController.h"
#import <TPQRCode/TPQRCode.h>
@interface TPQRCodeViewController ()

@end

@implementation TPQRCodeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    [btn setBackgroundColor:[UIColor redColor]];
    [btn addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
	// Do any additional setup after loading the view, typically from a nib.
}

-(void)click{
    TPQRCode *code = [[TPQRCode alloc] init];
    [code startReading];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
