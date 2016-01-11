//
//  ViewController.m
//  AVPlayer
//
//  Created by CY on 16/1/11.
//  Copyright © 2016年 CheeryCompany. All rights reserved.
//

#import "ViewController.h"
#import "CMPlayerView.h"

@interface ViewController ()
@property (nonatomic, weak) CMPlayerView *playView;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	NSString *path = [[NSBundle mainBundle] pathForResource:@"test0.mp4" ofType:nil];
	CMPlayerView *playView = [[CMPlayerView alloc] initWithFrame:CGRectMake(20, 50, self.view.frame.size.width - 20 * 2, 180) videoUrlStr:path isNetworkVideo:NO];
	
	self.playView = playView;
	[self.view addSubview:playView];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

@end
