//
//  ViewController.m
//  LearnOpenGL-Earth&Moon
//
//  Created by FengLe on 2017/8/17.
//  Copyright © 2017年 FengLe. All rights reserved.
//

#import "ViewController.h"
#import "FLOpenGLView.h"

@interface ViewController ()

@property (nonatomic, strong) FLOpenGLView *mView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.mView = [[FLOpenGLView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.mView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
