//
//  CMPlayerView.h
//  testAVPlayer
//
//  Created by CY on 16/1/7.
//  Copyright © 2016年 CheeryMusic. All rights reserved.
//  播放视频(本地、网络视频)的View

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface CMPlayerView : UIView

@property (copy, nonatomic) void (^videoPlayEnd)(); // 无参数，和返回值的block，视频播放结束调用
/**
 *  返回一个 能够播放视频的View
 *
 *  @param frame          尺寸和位置
 *  @param videoUrlStr    网络视频的地址/ 本地视频直接写文件名
 *  @param isNetworkVideo 是否是网络视频
 */
- (instancetype) initWithFrame:(CGRect)frame videoUrlStr:(NSString *)videoUrlStr isNetworkVideo:(BOOL)isNetworkVideo;

- (void)startToPlay;
@end
