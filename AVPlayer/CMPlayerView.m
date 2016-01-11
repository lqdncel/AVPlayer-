//
//  CMPlayerView.m
//  testAVPlayer
//
//  Created by CY on 16/1/7.
//  Copyright © 2016年 CheeryMusic. All rights reserved.
//

#define CMToolbarHeight 48 // 播放条的高度
#define CMPlayBtnWH 48  // 播放按钮的宽高
#define CMFullPlayBtnWH 48 // 全屏播放按钮的宽高
#define CMTimeLabelW  80 // 时间Label宽度
#define CMTimeLabelH 14 // 时间Label高度
#define CMTimeLabelFontSize 12 // 字体大小
#define CMFullScreenLeftRightMargin 80 // 全屏播放时，左右间距
#import "CMPlayerView.h"

@interface CMPlayerView ()

@property (strong, nonatomic) AVPlayer *player;// 播放器对象

@property (strong, nonatomic) AVPlayerLayer *playerLayer;// 播放器层,用来显示视频内容
@property (weak, nonatomic) UIImageView  *backImgV;// 播放器的背景图片

@property (weak, nonatomic) UIView *playToolbar; // 播放工具条

@property (weak, nonatomic) UIButton *playBtn; // 播放/暂停按钮
@property (weak, nonatomic) UISlider *progressSlider;// 播放进度
@property (weak, nonatomic) UIButton *fullScreenPlayBtn; // 全屏播放

@property (weak, nonatomic) UILabel *currentTime;// 当前播放时间
@property (weak, nonatomic) UILabel *totalTime;// 总的播放时间

@property (copy, nonatomic) NSString *videoUrlStr;// 视频的url地址
@property (assign, nonatomic, getter=isNetworkVideo) BOOL networkVideo;// 是否是网络视频

@property (assign, nonatomic) CGRect originalFrame; // 原始的frame，退出全屏播放时使用
@property (strong, nonatomic) id observer;// 播放进度的观察者，真实类型是AVPeriodicTimebaseObserver
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;// loading指示器

@end
@implementation CMPlayerView

- (instancetype) initWithFrame:(CGRect)frame videoUrlStr:(NSString *)videoUrlStr isNetworkVideo:(BOOL)isNetworkVideo{
	
	// 需要利用到videoUrlStr 创建AVPlayerItem，再利用AVPlayerItem 创建AVPlayer对象
	if (self = [super initWithFrame:frame]) {
		
		self.videoUrlStr = videoUrlStr;
		self.networkVideo = isNetworkVideo;
		self.originalFrame = frame;
		
		// 创建子控件
		[self createUIComponent];
		
		// 注册通知
		[self addNotification];
	}
	return self;
}

// 如果使用autolayout的话，不需要写下面的代码？
-(void)layoutSubviews{
	[super layoutSubviews];
	
	// 调整子控件
	self.progressSlider.frame = CGRectMake(CMPlayBtnWH, 10, self.bounds.size.width - CMPlayBtnWH - CMFullPlayBtnWH, 20);
	self.totalTime.frame = CGRectMake(self.bounds.size.width - CMFullPlayBtnWH - CMTimeLabelW, CMToolbarHeight - CMTimeLabelH,CMTimeLabelW, CMTimeLabelH);
	
	self.fullScreenPlayBtn.frame = CGRectMake(self.bounds.size.width - CMFullPlayBtnWH, 0, CMFullPlayBtnWH, CMFullPlayBtnWH);
}

#pragma mark - 私有方法
#pragma mark - 创建子控件
-(void)createUIComponent{
	
	// 添加背景图片 -- 可以添加一张特别的图片
//	UIImageView *backImgV = [[UIImageView alloc] initWithFrame:self.container.bounds];
//	self.backImgV = backImgV;
//	backImgV.contentMode = UIViewContentModeScaleAspectFill;
//	backImgV.image = [UIImage imageNamed:@"backImg.png"];
//	[self.container addSubview:backImgV];
	self.backgroundColor = [UIColor blackColor];// 黑色背景
	
	//利用self.player 创建播放器层
	[self createPlayLayer];
	
	//播放工具条 - (默认是隐藏)
	[self createPlayToolbar];
	
	#warning 下面的方法需要在 createPlayToolbar之后调用，因为slider还没有创建
	// 设置播放进度
	[self addProgressObserver];
	// kvo观察
	[self addObserverToPlayerItem:self.player.currentItem];

	// 添加点按手势
	[self addTapGesture];
	
	// 添加指示器
	[self createIndicatorView];
}

/**
 *  利用self.player 创建播放器层
 */
- (void)createPlayLayer{
	// 播放器层
	AVPlayerLayer *playerLayer=[AVPlayerLayer playerLayerWithPlayer:self.player];
	playerLayer.frame=self.bounds;
	self.playerLayer = playerLayer;
	//	playerLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//视频填充模式
	//	playerLayer.videoGravity=AVLayerVideoGravityResizeAspect;
	playerLayer.videoGravity = AVLayerVideoGravityResize;
	
	// 添加到容器层中
	[self.layer addSublayer:playerLayer];

}

/**
 *  创建播放工具条
 */
- (void)createPlayToolbar{
	
	UIView *toolbar = [[UIView alloc] initWithFrame:CGRectMake(0, self.bounds.size.height - CMToolbarHeight, self.bounds.size.width, CMToolbarHeight)];
	toolbar.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];// 半透明
	
	self.playToolbar.hidden = YES;
	self.playToolbar = toolbar;
	[self addSubview:toolbar];
	
	// 1.播放按钮
	UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	playBtn.frame = CGRectMake(0, 0, CMPlayBtnWH, CMPlayBtnWH);
	[playBtn setImage:[UIImage imageNamed:@"videoPlay.png"] forState:UIControlStateNormal];
	[playBtn setImage:[UIImage imageNamed:@"videoPause.png"] forState:UIControlStateSelected];
//	[playBtn setImageEdgeInsets:UIEdgeInsetsMake(12, 12, 12, 12)];
	[playBtn addTarget:self action:@selector(playBtnClick:) forControlEvents:UIControlEventTouchUpInside];
	
	self.playBtn = playBtn;
	[toolbar addSubview:playBtn];
	
	// 2.进度条
	UISlider *progressSlider = [[UISlider alloc] initWithFrame:CGRectMake(CMPlayBtnWH, 10, toolbar.bounds.size.width - CMPlayBtnWH - CMFullPlayBtnWH, 20)];
	progressSlider.minimumValue = 0.0f;
	progressSlider.value = 0.0;
	// 监听slider的值改变事件
	[progressSlider addTarget:self action:@selector(sliderProgress:) forControlEvents:UIControlEventValueChanged];
	self.progressSlider = progressSlider;
	
	[toolbar addSubview:progressSlider];
	
	// 2.播放时间/ 总的时间
	UILabel *currentTime = [[UILabel alloc] initWithFrame:CGRectMake(CMPlayBtnWH, CMToolbarHeight - CMTimeLabelH, CMTimeLabelW, CMTimeLabelH)];
	currentTime.font = [UIFont systemFontOfSize:CMTimeLabelFontSize];
	currentTime.textAlignment = NSTextAlignmentLeft;// 靠左
	currentTime.textColor = [UIColor whiteColor];
	
	self.currentTime = currentTime;
	[toolbar addSubview:currentTime];
	
	UILabel *totalTime = [[UILabel alloc] initWithFrame:CGRectMake(toolbar.bounds.size.width - CMFullPlayBtnWH - CMTimeLabelW, CMToolbarHeight - CMTimeLabelH,CMTimeLabelW, CMTimeLabelH)];
	totalTime.font = [UIFont systemFontOfSize:CMTimeLabelFontSize];
	totalTime.textAlignment = NSTextAlignmentRight;
	totalTime.textColor = [UIColor whiteColor];
	
	self.totalTime = totalTime;
	[toolbar addSubview:totalTime];
	
	// 3.显示弹幕按钮
	
	// 4.全屏播放按钮
	UIButton *fullPlayBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	fullPlayBtn.frame = CGRectMake(toolbar.bounds.size.width - CMFullPlayBtnWH, 0, CMFullPlayBtnWH, CMFullPlayBtnWH);
	[fullPlayBtn setImage:[UIImage imageNamed:@"fullScreenPlay.png"] forState:UIControlStateNormal];
	[fullPlayBtn setImage:[UIImage imageNamed:@"originalScreenPlay.png"] forState:UIControlStateSelected];
	[fullPlayBtn setImageEdgeInsets:UIEdgeInsetsMake(12, 12, 12, 12)];
	
	[fullPlayBtn addTarget:self action:@selector(fullScreenPlay:) forControlEvents:UIControlEventTouchUpInside];
	
	self.fullScreenPlayBtn = fullPlayBtn;
	[toolbar addSubview:fullPlayBtn];
}

/**
 *  添加指示器
 */
- (void)createIndicatorView{
	
	UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	
	indicatorView.center = CGPointMake(self.bounds.size.width * 0.5, self.bounds.size.height * 0.5);
	self.indicatorView = indicatorView;
	[self addSubview:indicatorView];
}

#pragma mark - UI事件
/**
 *  点击播放/暂停按钮
 *
 *  @param sender 播放/暂停按钮
 */
- (void)playBtnClick:(UIButton *)pressedBtn{
	//    AVPlayerItemDidPlayToEndTimeNotification
	//AVPlayerItem *playerItem= self.player.currentItem;
	if(self.player.rate==0){ //说明点击按钮之前是暂停,现在需要播放
		
		pressedBtn.selected = YES;// 显示暂停图片
		[self.player play];
	}else if(self.player.rate==1){//正在播放，需要暂停
		
		pressedBtn.selected = NO;// 显示播放图片
		[self.player pause];

	}
}



/**
 *  全屏播放按钮点击
 */
- (void)fullScreenPlay:(UIButton *)pressedBtn{
	
	NSLog(@"全屏/恢复 播放视频");
	
	pressedBtn.selected = !pressedBtn.selected;
	
	if (pressedBtn.selected == YES) {
		// 修改播放器层的 frame
		[UIView animateWithDuration:0.25 animations:^{
			// 顺时针旋转90°
			self.transform = CGAffineTransformMakeRotation(M_PI_2);
			
			self.frame = CGRectMake(0, 0, self.superview.frame.size.width, self.superview.frame.size.height);
			self.playToolbar.frame = CGRectMake(0, self.superview.frame.size.width - CMToolbarHeight, self.superview.frame.size.height, CMToolbarHeight);
			
			self.backImgV.frame = self.bounds;
			self.playerLayer.frame = CGRectMake(CMFullScreenLeftRightMargin, 0, self.superview.frame.size.height - 2 * CMFullScreenLeftRightMargin, self.superview.frame.size.width);
		}];
	}else{
		[UIView animateWithDuration:0.25 animations:^{
			
			self.transform = CGAffineTransformIdentity;
			self.frame = self.originalFrame;
			self.playToolbar.frame = CGRectMake(0, self.bounds.size.height - CMToolbarHeight, self.bounds.size.width, CMToolbarHeight);
			
			self.backImgV.frame = self.bounds;
			self.playerLayer.frame = self.bounds;
		}];
	}

}

#pragma mark - 添加点按手势
/**
 *  添加点按手势
 */
- (void)addTapGesture{
	
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction)];
	
	[self addGestureRecognizer:tapGesture];
}

- (void)tapAction{
	
	NSLog(@"点击了我，根据工具条显示的状态，决定是否显示工具条");
	self.playToolbar.hidden = !self.playToolbar.hidden;
	
}

/**
 *  初始化播放器
 *
 *  @return 播放器对象
 */
-(AVPlayer *)player{
	if (!_player) {
		// 设置要播放的 视频
		AVPlayerItem *playerItem = nil;
		if (self.isNetworkVideo) {// 网络视频
			playerItem = [self getPlayItemWithNetWorkVideoUrlStr:self.videoUrlStr];
		}else{//  本地视频
			NSLog(@"self.videoUrlstr:%@",self.videoUrlStr);
			playerItem = [self getPlayItemWithLocalVideoUrlStr:self.videoUrlStr];
		}
		
		if (playerItem) {
			
			_player=[AVPlayer playerWithPlayerItem:playerItem];
			
		}else{
			
			_player = nil;
		}
	}
	return _player;
}

/**
 *  根据本地视频videoUrlStr 返回AVPlayerItem对象
 *
 *  @param videoUrlStr 本地视频路径
 *
 *  @return AVPlayerItem对象
 */
-(AVPlayerItem *)getPlayItemWithLocalVideoUrlStr:(NSString *)videoUrlStr{
	
	NSString *encodeVideoPathStr =[videoUrlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	NSLog(@"本地视频url：%@",encodeVideoPathStr);
	NSURL *url = nil;
	if (encodeVideoPathStr.length) {
		
		url = [NSURL fileURLWithPath:encodeVideoPathStr];
	}else{
		url = nil;
	}
	
	if (url) {
		AVPlayerItem *playerItem=[AVPlayerItem playerItemWithURL:url];
		return playerItem;
	}else{
		return nil;
	}
}

/**
 *  根据 网络视频videoUrlStr 返回AVPlayerItem对象
 *
 *  @param videoUrlStr 网络视频地址
 *
 *  @return AVPlayerItem对象
 */
-(AVPlayerItem *)getPlayItemWithNetWorkVideoUrlStr:(NSString *)videoUrlStr{
	
	// 如果含有中文，就进行编码
	NSString *encodeVideoPathStr =[videoUrlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	NSURL *url = nil;
	if (encodeVideoPathStr.length) {
		
		url = [NSURL URLWithString:encodeVideoPathStr];
	}else{
		url = nil;
	}
	
	if (url) {
		AVPlayerItem *playerItem=[AVPlayerItem playerItemWithURL:url];
		return playerItem;
	}else{
		return nil;
	}
}

/**
 *  给播放器添加进度更新
 */
-(void)addProgressObserver{
	AVPlayerItem *playerItem=self.player.currentItem;
	UISlider *progress=self.progressSlider;
	
	__weak typeof(self) weakSelf = self;
	//这里设置每秒执行一次 Periodic:定期 ,返回的是观察者
	self.observer = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
		// 当前时间
		float current=CMTimeGetSeconds(time);
		// 总的时间
		float total=CMTimeGetSeconds([playerItem duration]);
		NSLog(@"当前已经播放%.2fs.",current);
		
		// 显示当前播放时间
		Float64 currentTime = CMTimeGetSeconds(playerItem.currentTime);
		weakSelf.currentTime.text = [weakSelf getMinuteSecondWithSecond:currentTime];
		
		if (current) {
			// 更新slider的播放进度 （百分比）
			[progress setValue:(current/total) animated:YES];
		}
	}];
	
	NSLog(@"observer:%@",self.observer);
}

#pragma mark - 给AVPlayerItem添加监控
/**
 *  给AVPlayerItem添加监控
 *
 *  @param playerItem AVPlayerItem对象
 */
-(void)addObserverToPlayerItem:(AVPlayerItem *)playerItem{
	//监控状态属性，注意AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态
	[playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
	//监控网络加载情况属性
	[playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
}

/**
 *  移除kvo的监听
 */
- (void)removeKvoObserver{
	[self.player.currentItem removeObserver:self forKeyPath:@"status"];
	[self.player.currentItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
}

/**
 *  通过KVO监控播放器状态
 *
 *  @param keyPath 监控属性
 *  @param object  被监听的对象
 *  @param change  状态改变
 *  @param context 上下文
 */
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	
	AVPlayerItem *playerItem = object;
	
	if ([keyPath isEqualToString:@"status"]) {// 被监听的属性
		AVPlayerStatus status= [[change objectForKey:@"new"] intValue];
		if(status == AVPlayerStatusReadyToPlay){
			NSLog(@"正在播放...，视频总长度:%.2f",CMTimeGetSeconds(playerItem.duration));
			
			Float64 duration = CMTimeGetSeconds(playerItem.duration);
			self.totalTime.text = [self getMinuteSecondWithSecond:duration];
		}
	}else if([keyPath isEqualToString:@"loadedTimeRanges"]){
		NSArray *array=playerItem.loadedTimeRanges;
		CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];//本次缓冲时间范围
		
		// 之前缓存的时间（也就是本次缓存开始的时间）
		float startSeconds = CMTimeGetSeconds(timeRange.start);
		// 本次缓存总的时间
		float durationSeconds = CMTimeGetSeconds(timeRange.duration);
		// 缓冲总长度
		NSTimeInterval totalBuffer = startSeconds + durationSeconds;
		NSLog(@"总共缓冲时间：%.2f",totalBuffer);
		
		// 如果由于网卡了,需要在这里 重新播放，这个方法在缓存过程中调用多次
		if (self.playBtn.selected == YES) {
			// 结束loading动画
			[self.indicatorView stopAnimating];
			// 显示playToolbar
			self.playToolbar.hidden = NO;
			[self.player play];
		}
		
		#warning 此处可以更新缓存进度条值（需要自定义sliderView）
	}
}

/**
 *  将秒转换成 12:09 格式
 *
 *  @param time 秒数
 *
 *  @return 返回规定格式的时间
 */
-(NSString *)getMinuteSecondWithSecond:(NSTimeInterval)time{
	
	int minute = (int)time / 60;
	int second = (int)time % 60;
	
	if (minute > 9) {
		
		if (second > 9) { //12:10
			return [NSString stringWithFormat:@"%d:%d",minute,second];
		}
		
		//12:09
		return [NSString stringWithFormat:@"%d:0%d",minute,second];
	}else{
		
		if (second > 9) { //02:10
			return [NSString stringWithFormat:@"0%d:%d",minute,second];
		}
		
		//02:09
		return [NSString stringWithFormat:@"0%d:0%d",minute,second];
	}
}

#pragma mark - 通知
/**
 *  添加播放器通知
 */
-(void)addNotification{
	
	//给AVPlayerItem添加播放完成通知
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}

/**
 *  移除通知中心的通知
 */
-(void)removeNotification{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 播放完成通知
/**
 *  播放完成通知
 *
 *  @param notification 通知对象
 */
-(void)playbackFinished:(NSNotification *)notification{
	NSLog(@"视频播放完成.");
	
	[UIView animateWithDuration:0.25 animations:^{
		
		self.transform = CGAffineTransformIdentity;
		self.frame = self.originalFrame;
		self.playToolbar.frame = CGRectMake(0, self.bounds.size.height - CMToolbarHeight, self.bounds.size.width, CMToolbarHeight);
		
		self.backImgV.frame = self.bounds;
		self.playerLayer.frame = self.bounds;
	}completion:^(BOOL finished) {
		if (self.videoPlayEnd) {
			self.videoPlayEnd(); // 执行block
		}
	}];
}

#pragma mark - 开始播放视频
- (void)startToPlay{
	
	// 开始loading动画
	[self.indicatorView startAnimating];
	
	[self playBtnClick:self.playBtn];
}

#pragma mark - dealloc
- (void)dealloc{
	
	NSLog(@"CMPlayView dealloc");
	
	// 移除self.player的时间观察者
	[self.player removeTimeObserver:self.observer];
	// 移除kvo的通知
	[self removeKvoObserver];
	// 移除通知中心的通知
	[self removeNotification];
}

#pragma mark - slider的代理方法
/**
 *  拖动进度条
 */
- (void)sliderProgress:(id)sender {
	
	UISlider *slider = sender	;
	
	// 总的时间
	Float64 duration = CMTimeGetSeconds(self.player.currentItem.duration);
	;
	// 滑动到的时间
	NSInteger dragedSeconds = floorf(duration * slider.value);
	NSLog(@"dragedSeconds:%zd",dragedSeconds);
	
	//转换成CMTime才能给player来控制播放进度
	CMTime dragedCMTime = CMTimeMake(dragedSeconds, 1);
	
	[self.player pause];
	
	[self.player seekToTime:dragedCMTime completionHandler:^(BOOL finish){
		
		NSLog(@"------");
		[self.player play];
		
	}];
}
@end
