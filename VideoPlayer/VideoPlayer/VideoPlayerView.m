/*
 * VideoPlayerView.m
 * VideoPlayer
 *
 * Copyright (c) 2015 Rhody Lugo.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "VideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "Scrubber.h"

/* Custom notifications */
NSString * const VideoPlayerPrevItemNotification = @"VideoPlayerPrevItemNotification";
NSString * const VideoPlayerNextItemNotification = @"VideoPlayerNextItemNotification";
NSString * const VideoPlayerCloseNotification = @"VideoPlayerCloseNotification";

/* Animation parameters */
static const CGFloat FullscreenTransitionDuration = 0.375;//0.25//0.5
static const CGFloat BoundsElasticity = 0.625;//0.5;//0.75;
static const CGFloat BoundsRestitutionDuration = 0.1;
static const CGFloat SwipeFadeDuration = 0.2;//0.1;
static const CGFloat ControlsFadeDuration = 0.5;
static const CGFloat SwipeVelocityThreshold = 1638.4;//819.2;//409.6;
static const CGFloat TitleFadeDuration = 0.25;//0.5;//1.0;

/* Layout parameters */
static CGFloat const separation = 8.0;

/* Key-Value Observation keys */
static NSString * const PlayerCurrentItemObservationKeyPath = @"player.currentItem";
static NSString * const PlayerRateObservationKeyPath = @"player.rate";
static NSString * const PlayerItemLoadedTimeRangesKeyPath = @"loadedTimeRanges";

/* Key-Value Observation contexts */
static void *PlayerCurrentItemObservationContext = &PlayerCurrentItemObservationContext;
static void *PlayerRateObservationContext = &PlayerRateObservationContext;
static void *PlayerItemLoadedTimeRangesContext = &PlayerItemLoadedTimeRangesContext;

/* Time line indicator */
static CGFloat const TimeLineIndicatorWidth = 1.0;//2.0;

static NSString *stringFromCMTime(CMTime time) {
	int seconds = CMTimeGetSeconds(time);

	int hours = seconds / 3600;
	int minutes = (seconds % 3600) / 60;
	seconds = (seconds % 3600) % 60;

	if (hours) {
		return [NSString stringWithFormat:@"%i:%02i:%02i", hours, minutes, seconds];
	}

	return [NSString stringWithFormat:@"%i:%02i", minutes, seconds];
}

/* System localized strings */
static inline NSString *UIKitLocalizedString(NSString *key) {
	return [[NSBundle bundleWithIdentifier:@"com.apple.UIKit"] localizedStringForKey:key value:@"" table:nil];
}


@interface VideoPlayerView ()

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet Scrubber *scrubber;
@property (weak, nonatomic) IBOutlet UILabel *playbackTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *remainingPlaybackTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *prevButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *jumpBackButton;
@property (weak, nonatomic) IBOutlet UIButton *jumpAheadButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIButton *contentModeButton;
@property (weak, nonatomic) IBOutlet UIButton *zoomModeButton;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeView;
@property (weak, nonatomic) IBOutlet UIToolbar *bottomControlsToolbar;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapGestureRcognizer;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic) IBOutlet UIPinchGestureRecognizer *pinchGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *prevSwipeGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *nextSwipeGestureRecognizer;
@property (nonatomic) BOOL showBorders;
@property (nonatomic) BOOL wantsToPlay;
@property (nonatomic, getter=isPlaying) BOOL playing;
@property (nonatomic) BOOL stalled;
@property (nonatomic) BOOL showsActivityIndicator;
@property (strong, nonatomic) UIView *standbyView;
@property (strong, nonatomic) CALayer *standbyLayer;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (assign, nonatomic) BOOL shouldShowStatusbar;
@property (assign, nonatomic) BOOL shouldAutohideControls;
@property (nonatomic) BOOL titleHidden;

- (BOOL)titleHidden UNAVAILABLE_ATTRIBUTE;

@end


@implementation VideoPlayerView {
	NSTimer *_hideControlsTimer;
	CGPoint _initialPanPosition;
	BOOL _swipeGestureRecognized;
	CGPoint _swipeVelocity;
	id _periodicTimeObserver;
	BOOL _canToggleFullscreen;
	CALayer *_timeLineLayer;
	BOOL _shouldChangeContainerView;
	AVPlayerItem *_currentItem;
	UIImage *_standbyImage;
	float _loadedTime;
	float _remainingToLoad;
}


#pragma mark Lifecycle

+ (Class)layerClass {
	return [AVPlayerLayer class];
}

- (void)awakeFromNib {
	self.layer.allowsGroupOpacity = NO;

	self.topControlsToolbar.hidden = YES;
	self.topControlsToolbar.clipsToBounds = YES;
	self.bottomControlsToolbar.hidden = YES;
	self.bottomControlsToolbar.clipsToBounds = YES;
	self.activityIndicator.hidden = YES;
	self.shouldShowStatusbar = NO;

	[self.closeButton setTitle:UIKitLocalizedString([self.closeButton titleForState:UIControlStateNormal]) forState:UIControlStateNormal];

	self.activityIndicator.hidesWhenStopped = YES;
	_canToggleFullscreen = YES;
	_shouldChangeContainerView = YES;

	[self.tapGestureRcognizer requireGestureRecognizerToFail:self.doubleTapGestureRecognizer];

	_timeLineLayer = [CALayer layer];
	_timeLineLayer.backgroundColor = [UIColor whiteColor].CGColor;
	[self.layer addSublayer:_timeLineLayer];

	self.showBorders = YES;
	//self.layer.backgroundColor = self.backgroundColor.CGColor;

	self.titleHidden = NO;

	/* Add a gesture recognizer to detect touches on the volume control */
	UIPanGestureRecognizer *volumeGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(volumeAdjusted:)];
	volumeGestureRecognizer.cancelsTouchesInView = NO;
	[self.volumeView addGestureRecognizer:volumeGestureRecognizer];
}

- (void)didMoveToSuperview {
	[super didMoveToSuperview];
	if (_shouldChangeContainerView) {
		self.containerView = self.superview;
		self.frame = CGRectMake(0, 0, CGRectGetWidth(self.containerView.frame), CGRectGetHeight(self.containerView.frame));
	}
}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	return YES;
}

- (void)layoutSubviews {
	//[super layoutSubviews];

	[self.closeButton sizeToFit];
	[self.contentModeButton sizeToFit];
	[self.zoomModeButton sizeToFit];

	CGRect playerFrame = self.frame;
	CGRect playerBounds = self.bounds;

	if (playerBounds.size.width > playerBounds.size.height && playerFrame.size.width < playerFrame.size.height) {
		CGFloat x = playerFrame.origin.x;
		CGFloat y = playerFrame.origin.y;
		CGFloat width = playerFrame.size.width;
		CGFloat height = playerFrame.size.height;
		playerFrame = CGRectMake(y, x, height, width);
	}

	CGFloat playerFrameWidth = CGRectGetWidth(playerFrame);
	CGRect statusbarFrame = UIApplication.sharedApplication.statusBarFrame;

	CGFloat statusBarHeight = MIN(CGRectGetWidth(statusbarFrame), CGRectGetHeight(statusbarFrame));
	CGFloat topButtonsMaxHeight = MAX(CGRectGetHeight(self.closeButton.frame), CGRectGetHeight(self.contentModeButton.frame));

	/* Top view */
	CGFloat topControlsHeight = topButtonsMaxHeight;

	if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
		topControlsHeight += statusBarHeight - 4.0;
		statusBarHeight = 0;
	}

	CGRect topControlsFrame = CGRectMake(0,
										 statusBarHeight,
										 playerFrameWidth,
										 topControlsHeight);
	self.topControlsToolbar.frame = topControlsFrame;
	CGRect topControlsBounds = self.topControlsToolbar.bounds;

	/* Close button */
	CGRect closeButtonFrame = self.closeButton.frame;
	self.closeButton.center = CGPointMake(2 * separation + CGRectGetWidth(closeButtonFrame)/2,
										  CGRectGetHeight(topControlsBounds) - topButtonsMaxHeight/2);

	/* Content mode button */
	CGRect contentModeButtonFrame = self.contentModeButton.frame;
	self.contentModeButton.center = CGPointMake(CGRectGetWidth(topControlsBounds) - 2 * separation - CGRectGetWidth(contentModeButtonFrame)/2,
												CGRectGetHeight(topControlsBounds) - topButtonsMaxHeight/2);

	/* Title label */
	[self.titleLabel sizeToFit];
	CGRect titleFrame = self.titleLabel.frame;
	titleFrame = CGRectMake(CGRectGetMaxX(closeButtonFrame) + separation,
							CGRectGetHeight(topControlsBounds) - topButtonsMaxHeight / 2 - CGRectGetHeight(titleFrame) / 2,
							CGRectGetMinX(contentModeButtonFrame) - CGRectGetMaxX(closeButtonFrame) - 2 * separation,
							CGRectGetHeight(titleFrame));
	self.titleLabel.frame = titleFrame;

	/* Time labels and the scrubber */
	[self layoutTimeIndicatorsInRect:playerFrame];

	/* Bottom view */
	CGRect bottomControlsFrame = CGRectMake(0,
											CGRectGetMaxY(playerFrame) - CGRectGetHeight(topControlsFrame),
											playerFrameWidth,
											CGRectGetHeight(topControlsFrame));
	self.bottomControlsToolbar.frame = bottomControlsFrame;
	CGRect bottomControlsBounds = self.bottomControlsToolbar.bounds;

	/* Play button*/
	self.playButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds),
										 CGRectGetMidY(bottomControlsBounds));

	/* Volume view */
	CGFloat prevNextSeparation;

	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)) {
		CGRect volumeFrame = self.volumeView.frame;
		volumeFrame = CGRectMake(2 * separation,
								 CGRectGetMidY(bottomControlsBounds) - CGRectGetHeight(volumeFrame)/2,
								 CGRectGetWidth(bottomControlsBounds)/4 - 4 * separation,
								 CGRectGetHeight(volumeFrame));
		self.volumeView.frame = volumeFrame;
		prevNextSeparation = (CGRectGetMidX(bottomControlsBounds) - CGRectGetMaxX(self.volumeView.frame)) / 3 - separation;

	} else {
		CGRect volumeFrame = self.volumeView.frame;
		volumeFrame = CGRectMake(separation,
								 CGRectGetMidY(bottomControlsBounds) - CGRectGetHeight(volumeFrame)/2,
								 CGRectGetWidth(bottomControlsBounds)/3 - 4 * separation,
								 CGRectGetHeight(volumeFrame));
		self.volumeView.frame = volumeFrame;
		prevNextSeparation = 3 * (CGRectGetMidX(bottomControlsBounds) - CGRectGetMaxX(self.volumeView.frame)) / 5 - separation;
	}

	/* Prev button*/
	self.prevButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) - prevNextSeparation,
										 CGRectGetMidY(bottomControlsBounds));

	/* Next button*/
	self.nextButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) + prevNextSeparation,
										 CGRectGetMidY(bottomControlsBounds));

	/* Jump Back button*/
	self.jumpBackButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) - 2 * prevNextSeparation,
											 CGRectGetMidY(bottomControlsBounds));

	/* Jump Ahead button*/
	self.jumpAheadButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) + 2 * prevNextSeparation,
											  CGRectGetMidY(bottomControlsBounds));

	/* Zoom mode button */
	CGRect zoomModeButtonFrame = self.zoomModeButton.frame;
	self.zoomModeButton.center = CGPointMake(CGRectGetWidth(bottomControlsBounds) - 2 * separation - CGRectGetWidth(zoomModeButtonFrame)/2,
											 CGRectGetMidY(bottomControlsBounds));

	/* Activity indicator */
	self.activityIndicator.center = CGPointMake(CGRectGetMidX(playerFrame),
												CGRectGetMidY(playerFrame));

	/* Content overlay and thumbnail views */
	self.contentOverlayView.frame = playerBounds;
	self.standbyLayer.frame = playerBounds;
	self.standbyView.frame = playerBounds;
}

- (void)dealloc {
	[self.layer removeObserver:self forKeyPath:PlayerCurrentItemObservationKeyPath];
}

#pragma mark Accessors

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	CGRect bounds = self.bounds;
	self.contentOverlayView.frame = bounds;
	self.standbyLayer.frame = bounds;
	self.standbyView.frame = bounds;
}

- (void)setShowBorders:(BOOL)showBorders {
	if (showBorders) {
		self.layer.borderColor = UIColor.blackColor.CGColor;
		self.layer.borderWidth = 2.0;
	} else {
		self.layer.borderColor = UIColor.clearColor.CGColor;
		self.layer.borderWidth = 0.0;
	}
}

- (AVPlayer*)player {
	return self.playerLayer.player;
}

- (void)setPlayer:(AVPlayer *)player {
	if (self.player) {
		[self.layer removeObserver:self
						forKeyPath:PlayerCurrentItemObservationKeyPath
						   context:PlayerCurrentItemObservationContext];
		[self.layer removeObserver:self
						forKeyPath:PlayerRateObservationKeyPath
						   context:PlayerRateObservationContext];
		if (_periodicTimeObserver) {
			[self.player removeTimeObserver:_periodicTimeObserver];
			_periodicTimeObserver = nil;
		}
	}

	self.playerLayer.player = player;

	if (!player) {
		return;
	}

	self.showBorders = YES;
	[self hideStandbyView];

	BOOL showPrevAndNextButtons = [player isKindOfClass:[AVQueuePlayer class]];
	self.prevButton.hidden = self.nextButton.hidden = !showPrevAndNextButtons;

	__weak AVPlayer *weakPlayerRef = player;

	CMTime interval = CMTimeMake(33, 1000);
	CFTimeInterval intervalSeconds = CMTimeGetSeconds(interval);
	CFTimeInterval minInterval = 0.5 * intervalSeconds;
	CFTimeInterval maxInterval = 1.5 * intervalSeconds;

	__block CMTime lastTime = player.currentTime;

	_periodicTimeObserver = [player addPeriodicTimeObserverForInterval:interval queue:NULL usingBlock: ^(CMTime time) {
		if (weakPlayerRef.currentItem) {
			if (self.stalled && CMTIME_IS_VALID(lastTime) && weakPlayerRef.rate != 0) {
				CFTimeInterval delta = CMTimeGetSeconds(CMTimeSubtract(time, lastTime));
				if (minInterval < delta && delta < maxInterval && _remainingToLoad < 0) {
					self.stalled = NO;
					//self.playing = YES;
					self.shouldAutohideControls = YES;
					self.controlsHidden = YES;
					self.titleHidden = YES;
					[self hideStandbyView];
				}
			}

			[self updateTimeIndicatorsWithTime:time];
		}

		[self layoutTimeIndicatorsInRect:self.frame];

		lastTime = time;
	}];

	[self.layer addObserver:self
				 forKeyPath:PlayerCurrentItemObservationKeyPath
					options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
					context:PlayerCurrentItemObservationContext];

	[self.layer addObserver:self
				 forKeyPath:PlayerRateObservationKeyPath
					options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
					context:PlayerRateObservationContext];
}

- (AVPlayerLayer *)playerLayer {
	return (AVPlayerLayer *)self.layer;
}

- (BOOL)fullscreen {
	return self.containerView != self.superview && self.delegate.presentingViewController;
}

- (void)setFullscreen:(BOOL)fullscreen {
	[self setFullscreen:fullscreen completion:nil];
}

- (void)setFullscreen:(BOOL)fullscreen completion:(void (^)(void))completion {
	if (!_canToggleFullscreen || fullscreen == self.fullscreen) {
		if (completion) {
			completion();
		}
		return;
	}

	_canToggleFullscreen = NO;
	_shouldChangeContainerView = NO;

	self.showsActivityIndicator = NO;

	CGRect screenBounds = [[UIScreen mainScreen] bounds];

	CGRect initialFrame = [self.superview convertRect:self.frame toView:UIApplication.sharedApplication.keyWindow];

	if (fullscreen) {
		[UIApplication.sharedApplication.keyWindow addSubview:self];
		self.frame = initialFrame;
		//self.containerView.hidden = YES;
		[_timeLineLayer removeFromSuperlayer];

		[self clearControlsHiddenTimer];

		[[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];

		[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
			[CATransaction begin];
			[CATransaction setAnimationDuration:FullscreenTransitionDuration];
			[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
			self.frame = screenBounds;
			self.standbyLayer.contentsScale = [self standbyLayerContentScaleWithVideoBounds:screenBounds];
			[CATransaction commit];

		} completion:^(BOOL finished) {
			if (self.delegate.parentViewController) {
				[self.delegate removeFromParentViewController];
			}
			[UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:self.delegate animated:NO completion:^{
				self.controlsHidden = NO;
				self.showBorders = NO;

				/*
				 if (self.stalled) {
					self.showsActivityIndicator = YES;
				 }
				 */

				[self setNeedsLayout];

				_canToggleFullscreen = YES;
				_shouldChangeContainerView = YES;

				if (completion) {
					completion();
				}
			}];
		}];

	} else {
		[UIApplication.sharedApplication.keyWindow addSubview:self];

		void (^block)() = ^{
			[self setControlsHidden:YES animated:NO];

			[UIApplication.sharedApplication.keyWindow addSubview:self];
			self.frame = initialFrame;
			self.showBorders = YES;

			CGRect containerViewFrame = [self containerViewFrame];

			[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
				[CATransaction begin];
				[CATransaction setAnimationDuration:FullscreenTransitionDuration];
				[CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]];
				self.frame = containerViewFrame;
				self.standbyLayer.contentsScale = [self standbyLayerContentScaleWithVideoBounds:containerViewFrame];
				[CATransaction commit];

			} completion:^(BOOL finished) {
				[self.containerView addSubview:self];
				self.frame = self.containerView.bounds;
				//self.containerView.hidden = NO;
				[self.layer addSublayer:_timeLineLayer];

				if (self.stalled) {
					self.showsActivityIndicator = YES;
				}

				[self setNeedsLayout];

				_canToggleFullscreen = YES;
				_shouldChangeContainerView = YES;

				if (completion) {
					completion();
				}
			}];
		};

		UIViewController *presentingViewController = self.delegate.presentingViewController;

		if (presentingViewController) {
			//[UIApplication.sharedApplication.keyWindow addSubview:self];
			[presentingViewController dismissViewControllerAnimated:NO completion:block];
		} else {
			block();
		}
	}
}

- (BOOL)controlsHidden {
	return self.topControlsToolbar.hidden || self.bottomControlsToolbar.hidden;
}

- (void)setControlsHidden:(BOOL)controlsHidden {
	[self setControlsHidden:controlsHidden animated:YES];
}

- (void)setControlsHidden:(BOOL)controlsHidden animated:(BOOL)animated {
	[self setControlsHidden:controlsHidden animated:animated shouldAutohide:YES];
}

- (void)setControlsHidden:(BOOL)controlsHidden animated:(BOOL)animated shouldAutohide:(BOOL)shouldAutohide {
	[self clearControlsHiddenTimer];

	if (_canToggleFullscreen && !self.fullscreen)
		return;

	//if (controlsHidden == self.controlsHidden)
	//	return;

	if (controlsHidden) {
		if (animated) {
			[UIView animateWithDuration:ControlsFadeDuration animations:^{
				self.topControlsToolbar.alpha = 0.0;
				self.bottomControlsToolbar.alpha = 0.0;
				self.shouldShowStatusbar = YES;

			} completion:^(BOOL finished) {
				self.topControlsToolbar.hidden = YES;
				self.bottomControlsToolbar.hidden = YES;
				[self setTitleHidden:YES animated:NO];
			}];

		} else {
			self.topControlsToolbar.hidden = YES;
			self.bottomControlsToolbar.hidden = YES;
			self.shouldShowStatusbar = YES;
			[self setTitleHidden:YES animated:NO];
		}

	} else {
		self.topControlsToolbar.hidden = NO;
		self.bottomControlsToolbar.hidden = NO;
		self.shouldShowStatusbar = NO;
		self.topControlsToolbar.alpha = 1.0;
		self.bottomControlsToolbar.alpha = 1.0;
		if (shouldAutohide) {
			[self startControlsHiddednTimer];
		}
	}

	if (!controlsHidden) {
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
		[self setNeedsLayout];
		[self layoutIfNeeded];
		[CATransaction commit];
	}
}

- (void)setWantsToPlay:(BOOL)wantsToPlay {
	//	if (!self.player.currentItem) {
	//		return;
	//	}
	self.playing = wantsToPlay;
	if (wantsToPlay) {
		[self.player play];
	} else {
		[self.player pause];
	}
	_wantsToPlay = wantsToPlay;
}

- (void)setPlaying:(BOOL)playing {
	if (playing) {
		[self.playButton setImage:[UIImage imageNamed:@"Pause-Highlighted"] forState:UIControlStateNormal];
		[self.playButton setImage:[UIImage imageNamed:@"Pause-Highlighted"] forState:UIControlStateHighlighted];
	} else {
		[self.playButton setImage:[UIImage imageNamed:@"Play-Highlighted"] forState:UIControlStateNormal];
		[self.playButton setImage:[UIImage imageNamed:@"Play-Highlighted"] forState:UIControlStateHighlighted];
	}
	_playing = playing;
}

- (BOOL)showsActivityIndicator {
	return self.activityIndicator.isAnimating;
}

- (void)setShowsActivityIndicator:(BOOL)showsActivityIndicator {
	if (showsActivityIndicator) {
		if (!self.activityIndicator.isAnimating) {
			[self.activityIndicator startAnimating];
		}
	} else {
		if (self.activityIndicator.isAnimating) {
			[self.activityIndicator stopAnimating];
		}
	}
}

- (void)setStalled:(BOOL)stalled {
	if (!self.fullscreen) {
		self.showsActivityIndicator = stalled;
	}
	_stalled = stalled;
	if (stalled) {
		_loadedTime = 0;
		_remainingToLoad = INFINITY;
	}
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
	[super setBackgroundColor:backgroundColor];
	self.standbyView.backgroundColor = backgroundColor;
}

- (UIView *)standbyView {
	if (!_standbyView && self.contentOverlayView) {
		_standbyView = [[UIView alloc] init];
		_standbyView.backgroundColor = self.backgroundColor;
		_standbyView.hidden = YES;
		_standbyLayer = [[CALayer alloc] init];
		_standbyLayer.contentsGravity = kCAGravityCenter;
		[_standbyView.layer addSublayer:_standbyLayer];
		[self insertSubview:_standbyView belowSubview:self.contentOverlayView];
	}
	return _standbyView;
}

- (void)setTitle:(NSString *)title {
	self.titleLabel.text = title;
	[self layoutIfNeeded];
}

- (NSString *)title {
	return self.titleLabel.text;
}

- (void)setShouldAutohideControls:(BOOL)shouldAutohideControls {
	if (!shouldAutohideControls) {
		[self clearControlsHiddenTimer];
	}
	_shouldAutohideControls = shouldAutohideControls;
}

- (void)setShouldShowStatusbar:(BOOL)shouldShowStatusbar {
	_shouldShowStatusbar = shouldShowStatusbar;

	if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
		[self.delegate setNeedsStatusBarAppearanceUpdate];
	} else {
		[[UIApplication sharedApplication] setStatusBarHidden:shouldShowStatusbar withAnimation:UIStatusBarAnimationNone];
	}
}

- (CGFloat)standbyLayerContentScaleWithVideoBounds:(CGRect)videoBounds {
	CGSize imageSize = _standbyImage.size;

	CGFloat widthScale = imageSize.width / videoBounds.size.width;
	CGFloat heightScale = imageSize.height / videoBounds.size.height;

	CGFloat scale = [UIScreen mainScreen].scale;

	if (self.playerLayer.videoGravity == AVLayerVideoGravityResizeAspect) {
		scale *= MAX(widthScale, heightScale);
	} else {
		scale *= MIN(widthScale, heightScale);
	}

	return scale;
}

- (CGFloat)standbyLayerContentScale {
	return [self standbyLayerContentScaleWithVideoBounds:self.bounds];
}

- (void)setTitleHidden:(BOOL)titleHidden {
	[self setTitleHidden:titleHidden animated:YES];
}

- (void)setTitleHidden:(BOOL)titleHidden animated:(BOOL)animated {
	if (titleHidden) {
		self.playbackTimeLabel.alpha = 0;
		self.playbackTimeLabel.hidden = NO;

		self.remainingPlaybackTimeLabel.alpha = 0;
		self.remainingPlaybackTimeLabel.hidden = NO;

		self.scrubber.alpha = 0;
		self.scrubber.hidden = NO;

		if (animated) {
			[UIView animateWithDuration:TitleFadeDuration animations:^{
				self.playbackTimeLabel.alpha = 1;
				self.remainingPlaybackTimeLabel.alpha = 1;
				self.scrubber.alpha = 1;

				self.titleLabel.alpha = 0;

			} completion:^(BOOL finished) {
				self.titleLabel.hidden = YES;
			}];

		} else {
			self.playbackTimeLabel.alpha = 1;
			self.remainingPlaybackTimeLabel.alpha = 1;
			self.scrubber.alpha = 1;

			self.titleLabel.alpha = 0;
			self.titleLabel.hidden = YES;
		}

	} else {
		self.titleLabel.alpha = 0;
		self.titleLabel.hidden = NO;

		if (animated) {
			[UIView animateWithDuration:TitleFadeDuration animations:^{
				self.playbackTimeLabel.alpha = 0;
				self.remainingPlaybackTimeLabel.alpha = 0;
				self.scrubber.alpha = 0;

				self.titleLabel.alpha = 1;

			} completion:^(BOOL finished) {
				self.playbackTimeLabel.hidden = YES;
				self.remainingPlaybackTimeLabel.hidden = YES;
				self.scrubber.hidden = YES;
			}];

		} else {
			self.playbackTimeLabel.alpha = 0;
			self.playbackTimeLabel.hidden = YES;

			self.remainingPlaybackTimeLabel.alpha = 0;
			self.remainingPlaybackTimeLabel.hidden = YES;

			self.scrubber.alpha = 0;
			self.scrubber.hidden = YES;

			self.titleLabel.alpha = 1;
		}
	}
}

#pragma mark Actions

- (IBAction)scrubberTouchDown:(id)sender {
	[self clearControlsHiddenTimer];
	[self.player pause];
}

- (IBAction)scrubberTouchUp:(id)sender {
	self.controlsHidden = NO;
	if (self.wantsToPlay) {
		self.stalled = YES;
		//self.playing = NO;
		[self.player play];
	}
}

- (IBAction)scrubberValueChanged:(id)sender {
	NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
	CMTime newTime = CMTimeMakeWithSeconds(self.scrubber.value * duration, self.player.currentTime.timescale);
	[self.player seekToTime:newTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (IBAction)playButtonTouchUpInside:(UIButton *)sender {
	self.controlsHidden = NO;
	if (CMTimeCompare(_currentItem.currentTime, _currentItem.duration) == 0) {
		[self.player seekToTime:kCMTimeZero];
	}
	[self toggleWantsToPlay];
}

- (IBAction)prevButtonTouchUpInside:(UIButton *)sender {
	self.controlsHidden = NO;
	[self.player seekToTime:kCMTimeZero];
	[[NSNotificationCenter defaultCenter] postNotificationName:VideoPlayerPrevItemNotification object:self];
}

- (IBAction)nextButtonTouchUpInside:(UIButton *)sender {
	self.controlsHidden = NO;
	if ([self.player isKindOfClass:[AVQueuePlayer class]]) {
		[(AVQueuePlayer *)self.player advanceToNextItem];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:VideoPlayerNextItemNotification object:self];
}

- (IBAction)jumpBackTouchUpInside:(id)sender {
	self.controlsHidden = NO;
	NSTimeInterval jumpTime = CMTimeGetSeconds(self.player.currentTime) - 15.0;
	if (jumpTime < 0) {
		jumpTime = 0;
	}
	CMTime newTime = CMTimeMakeWithSeconds(jumpTime, self.player.currentTime.timescale);
	[self.player seekToTime:newTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (IBAction)jumpAheadTouchUpInside:(id)sender {
	self.controlsHidden = NO;
	NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
	NSTimeInterval jumpTime = CMTimeGetSeconds(self.player.currentTime) + 15.0;
	if (jumpTime > duration) {
		jumpTime = duration;
	}
	CMTime newTime = CMTimeMakeWithSeconds(jumpTime, self.player.currentTime.timescale);
	[self.player seekToTime:newTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (IBAction)tapGestureRecognizer:(UITapGestureRecognizer *)sender {
	if (self.fullscreen) {
		BOOL shouldToggleControlsHidden = YES;

		if (!self.controlsHidden) {
			CGPoint location = [sender locationInView:self];

			if (CGRectContainsPoint([self convertRect:self.titleLabel.bounds fromView:self.titleLabel], location)
				&& !self.titleLabel.hidden) {
				self.titleHidden = YES;
				shouldToggleControlsHidden = NO;

			} else if (CGRectContainsPoint([self convertRect:self.scrubber.bounds fromView:self.scrubber], location)
					   && !self.scrubber.hidden) {
				self.titleHidden = NO;
				shouldToggleControlsHidden = NO;
			}
		}

		if (shouldToggleControlsHidden) {
			self.controlsHidden = !self.controlsHidden;
		} else {
			self.controlsHidden = NO;
		}

	} else {
		self.fullscreen = YES;
	}
}

- (IBAction)doubleTapGestureRecognizer:(UITapGestureRecognizer *)sender {
	if (self.fullscreen) {
		[self toggleContentMode];
	}
}

- (IBAction)panGestureRecognizer:(UIPanGestureRecognizer *)sender {
	if (!self.fullscreen) {

		CGPoint locationInView = [sender locationInView:self.containerView.superview];
		CGPoint center = self.containerView.center;

		if (sender.state == UIGestureRecognizerStateBegan) {
			_swipeVelocity = CGPointZero;
			_initialPanPosition = CGPointMake(locationInView.x - center.x, locationInView.y - center.y);
			_swipeGestureRecognized = NO;

		} else if (!_swipeGestureRecognized) {
			if (sender.state == UIGestureRecognizerStateChanged) {
				center = CGPointMake(locationInView.x - _initialPanPosition.x, locationInView.y - _initialPanPosition.y);
				self.containerView.center = [self capCenterToBounds:center withElasticity:BoundsElasticity];

			} else {
				center = CGPointMake(locationInView.x - _initialPanPosition.x, locationInView.y - _initialPanPosition.y);
				CGRect boundsLimit = [self boundsLimit];

				if (CGRectContainsPoint(boundsLimit, center)) {
					self.containerView.center = center;

				} else {
					/* Spring effect */
					[UIView animateWithDuration:BoundsRestitutionDuration animations:^{
						self.containerView.center = [self capCenterToBounds:center withElasticity:0.0];
					}];
				}
			}

			CGPoint velocity = [sender velocityInView:self.containerView.superview];
			_swipeVelocity = CGPointMake(_swipeVelocity.x * 0.9 + velocity.x * 0.1,
										 _swipeVelocity.y * 0.9 + velocity.y * 0.1);

			CGFloat velocityMagnitud = sqrt(_swipeVelocity.x * _swipeVelocity.x + _swipeVelocity.x * _swipeVelocity.x);

			if (velocityMagnitud > SwipeVelocityThreshold) {
				_swipeGestureRecognized = YES;

				dispatch_async(dispatch_get_main_queue(), ^{
					CGPoint center = self.containerView.center;
					CGPoint endPosition = CGPointMake(center.x + SwipeFadeDuration * _swipeVelocity.x,
													  center.y + SwipeFadeDuration * _swipeVelocity.y);
					[UIView animateWithDuration:SwipeFadeDuration
										  delay:0
										options:UIViewAnimationOptionCurveLinear
									 animations:^{
										 self.containerView.center = endPosition;
										 self.containerView.alpha = 0.0;
									 } completion:^(BOOL finished) {
										 self.containerView.center = [self capCenterToBounds:endPosition withElasticity:0.0];
										 //self.containerView.hidden = YES;
										 self.containerView.alpha = 1.0;
										 [self closePlayer];
									 }];
				});
			}
		}
	}
}

- (IBAction)pinchGestureRecognizer:(UIPinchGestureRecognizer *)sender {
	if (self.fullscreen && sender.scale < 1) {
#if 0 // TODO: This fails to continue the pinch gesture after dismissing the view controller
		UIGestureRecognizerState state = sender.state;

		static CGRect initialFrame;

		if (state == UIGestureRecognizerStateBegan) {
			[self setControlsHidden:YES animated:NO];

			initialFrame = [self.superview convertRect:self.frame toView:UIApplication.sharedApplication.keyWindow];

			[UIApplication.sharedApplication.keyWindow addSubview:self];

			[self.delegate.presentingViewController dismissViewControllerAnimated:NO completion:^{
				[UIApplication.sharedApplication.keyWindow addSubview:self];
				self.frame = initialFrame;
				self.showBorders = YES;
			}];

		} else if (state == UIGestureRecognizerStateChanged) {
			CGFloat scale = MAX(0.0, MIN(sender.scale, 1.0));
			CGFloat reverseScale = 1.0 - scale;

			CGRect finalFrame = [self containerViewFrame];

			CGRect frame = CGRectMake(scale * initialFrame.origin.x + reverseScale * finalFrame.origin.x,
									  scale * initialFrame.origin.y + reverseScale * finalFrame.origin.y,
									  scale * initialFrame.size.width + reverseScale * finalFrame.size.width,
									  scale * initialFrame.size.height + reverseScale * finalFrame.size.height);

			self.frame = frame;

		} else {
			self.fullscreen = NO;
		}
#else
		self.fullscreen = NO;
#endif
	} else if (!self.fullscreen && sender.scale > 1) {
		self.fullscreen = YES;
	}
}

- (void)volumeAdjusted:(UIPanGestureRecognizer *)recognizer {
	[self setControlsHidden:NO animated:NO];
}

- (IBAction)prevSwipeGestureRecognizer:(UISwipeGestureRecognizer *)sender {
	if (self.fullscreen) {
		[self prevButtonTouchUpInside:self.prevButton];
	}
}

- (IBAction)nextSwipeGestureRecognizer:(UISwipeGestureRecognizer *)sender {
	if (self.fullscreen) {
		[self nextButtonTouchUpInside:self.nextButton];
	}
}

- (IBAction)closeButtonTouchUpInside:(UIButton *)sender {
	[self closePlayer];
	[[NSNotificationCenter defaultCenter] postNotificationName:VideoPlayerCloseNotification object:self];
}

- (IBAction)contentModeButtonTouchUpInside:(UIButton *)sender {
	[self toggleContentMode];
}

- (IBAction)zoomModeButtonTouchUpInside:(UIButton *)sender {
	if (self.fullscreen) {
		self.fullscreen = NO;
	}
}

#pragma mark Helper methods

- (void)hideStandbyView {
	self.standbyLayer.contents = nil;
	_standbyImage = nil;
	self.standbyView.hidden = YES;
}

- (void)clearControlsHiddenTimer {
	if (_hideControlsTimer) {
		[_hideControlsTimer invalidate];
		_hideControlsTimer = nil;
	}
}

- (void)startControlsHiddednTimer {
	_hideControlsTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
														  target:self
														selector:@selector(hideControlsTimer)
														userInfo:nil
														 repeats:NO];
}

- (void)updateTimeIndicatorsWithTime:(CMTime)time {
	CMTime endTime = CMTimeConvertScale(self.player.currentItem.asset.duration, time.timescale, kCMTimeRoundingMethod_RoundHalfAwayFromZero);
	if (CMTimeCompare(endTime, kCMTimeZero) != 0) {
		double normalizedTime = (double) time.value / (double) endTime.value;
		self.scrubber.value = normalizedTime;
	}
	self.playbackTimeLabel.text = stringFromCMTime(time);
	self.remainingPlaybackTimeLabel.text = [NSString stringWithFormat:@"-%@", stringFromCMTime(CMTimeSubtract(endTime, time))];
}

- (void)toggleWantsToPlay {
	self.wantsToPlay = !self.wantsToPlay;
}

- (void)toggleContentMode {
	if (self.playerLayer.videoGravity == AVLayerVideoGravityResizeAspect) {
		[self.contentModeButton setImage:[UIImage imageNamed:@"Fit-Highlighted"] forState:UIControlStateNormal];
		[self.contentModeButton setImage:[UIImage imageNamed:@"Fit-Highlighted"] forState:UIControlStateHighlighted];
		self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
		self.standbyLayer.contentsScale = [self standbyLayerContentScale];
	} else {
		[self.contentModeButton setImage:[UIImage imageNamed:@"Fill-Highlighted"] forState:UIControlStateNormal];
		[self.contentModeButton setImage:[UIImage imageNamed:@"Fill-Highlighted"] forState:UIControlStateHighlighted];
		self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
		self.standbyLayer.contentsScale = [self standbyLayerContentScale];
	}
}

- (void)closePlayer {
	[self closePlayerWithCompletition:nil];
}

- (void)closePlayerWithCompletition:(void (^)(void))completion {
	if ([self.player isKindOfClass:[AVQueuePlayer class]]) {
		[(AVQueuePlayer *)self.player removeAllItems];
	} else {
		[self.player replaceCurrentItemWithPlayerItem:nil];
	}
	__weak VideoPlayerView *weakRef = self;
	[self setFullscreen:NO completion:^{
		[weakRef removeFromSuperview];
		weakRef.containerView = nil;
		weakRef.wantsToPlay = YES;

		if (completion) {
			completion();
		}
	}];
}

- (void)hideControlsTimer {
	if (self.shouldAutohideControls) {
		self.controlsHidden = YES;
	}
}

- (CGRect)containerViewFrame {
	return [self.containerView.superview convertRect:self.containerView.frame toView:UIApplication.sharedApplication.keyWindow];
}

- (CGRect)boundsLimit {
	CGRect screenRect = UIScreen.mainScreen.bounds;
	CGRect viewFrame = [self containerViewFrame];
	return CGRectInset(screenRect, CGRectGetWidth(viewFrame)/2, CGRectGetHeight(viewFrame)/2);
}

- (CGPoint)capCenterToBounds:(CGPoint)center withElasticity:(CGFloat)elasticity {
	CGRect boundsLimit = [self boundsLimit];

	CGFloat minX = CGRectGetMinX(boundsLimit);
	CGFloat maxX = CGRectGetMaxX(boundsLimit);
	CGFloat minY = CGRectGetMinY(boundsLimit);
	CGFloat maxY = CGRectGetMaxY(boundsLimit);

	if (center.x < minX) {
		center.x = minX - elasticity * (minX - center.x);
	} else if (center.x > maxX) {
		center.x = maxX + elasticity * (center.x - maxX);
	}

	if (center.y < minY) {
		center.y = minY - elasticity * (minY - center.y);
	} else if (center.y > maxY) {
		center.y = maxY + elasticity * (center.y - maxY);
	}

	return center;
}

- (void)layoutTimeIndicatorsInRect:(CGRect)rect {
	CGFloat midY = CGRectGetMidY(self.closeButton.frame);

	/* Playback time */
	NSString *timeString = self.playbackTimeLabel.text;
	self.playbackTimeLabel.text = @"0:00:00";
	[self.playbackTimeLabel sizeToFit];
	self.playbackTimeLabel.text = timeString;
	CGRect playbackTimeFrame = self.playbackTimeLabel.frame;
	self.playbackTimeLabel.center = CGPointMake(CGRectGetMaxX(self.closeButton.frame) + separation + CGRectGetWidth(playbackTimeFrame)/2,
												midY);

	/* Remaining playback time */
	timeString = self.remainingPlaybackTimeLabel.text;
	self.remainingPlaybackTimeLabel.text = @"-0:00:00";
	[self.remainingPlaybackTimeLabel sizeToFit];
	self.remainingPlaybackTimeLabel.text = timeString;
	CGRect remainingPlaybackTimeFrame = self.remainingPlaybackTimeLabel.frame;
	self.remainingPlaybackTimeLabel.center = CGPointMake(CGRectGetMinX(self.contentModeButton.frame) - separation - CGRectGetWidth(remainingPlaybackTimeFrame)/2,
														 midY);

	/* Scrubber */
	CGRect scrubberFrame = self.scrubber.frame;
	CGFloat scrubberMinX = CGRectGetMaxX(self.playbackTimeLabel.frame) + 0.5 * separation;
	CGFloat scrubberMaxX = CGRectGetMinX(self.remainingPlaybackTimeLabel.frame) - 0.5 * separation;
	scrubberFrame = CGRectMake(scrubberMinX,
							   midY - 0.5 * CGRectGetHeight(scrubberFrame),
							   scrubberMaxX - scrubberMinX,
							   CGRectGetHeight(scrubberFrame));
	self.scrubber.frame = scrubberFrame;

	/* Time line progess indicator */
	CGFloat borderWidth = self.layer.borderWidth;
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	_timeLineLayer.frame = CGRectMake(borderWidth,
									  CGRectGetHeight(rect) - TimeLineIndicatorWidth - borderWidth,
									  self.scrubber.value * (CGRectGetWidth(rect) - 2 * borderWidth),
									  TimeLineIndicatorWidth);
	[CATransaction commit];
}


#pragma mark Notification handlers

- (void)playerItemDidStalled:(NSNotification *)notification {
	if (!self.standbyView.layer.contents) {
		AVPlayerItem *playerItem = self.player.currentItem;
		CMTime currentTime = playerItem.currentTime;
		AVAsset *asset = playerItem.asset;

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
			AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
			if (!imageGenerator) {
				NSLog(@"Could't create the thumbnail image generator.");
				return;
			}

			if ([imageGenerator respondsToSelector:@selector(setRequestedTimeToleranceBefore:)]
				&& [imageGenerator respondsToSelector:@selector(setRequestedTimeToleranceAfter:)]) {
				imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
				imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
			}

			CGImageRef imageRef = [imageGenerator copyCGImageAtTime:currentTime actualTime:NULL error:NULL];
			if (!imageRef) {
				NSLog(@"Could't create the thumbnail image.");
				return;
			}

			_standbyImage = [UIImage imageWithCGImage:imageRef];
			CGImageRelease(imageRef);

			if (!self.stalled) {
				NSLog(@"Playback stalled but failed to get the video capture on time.");
				return;
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				self.standbyLayer.contents = (id)_standbyImage.CGImage;

				[CATransaction begin];
				[CATransaction setDisableActions:YES];
				self.standbyLayer.contentsScale = [self standbyLayerContentScale];
				[CATransaction commit];

				CGRect bounds = self.bounds;
				self.standbyLayer.frame = bounds;
				self.standbyView.frame = bounds;

				self.standbyView.hidden = NO;
			});
		});

	} else {
		NSLog(@"Stalled with a thumbnail image already generated.");
	}

	self.stalled = YES;
	//self.playing = NO;

	self.shouldAutohideControls = NO;
	self.controlsHidden = NO;
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification {
	self.stalled = NO;
	//[self updateTimeIndicatorsWithTime:_currentItem.currentTime];
	if (![self.player isKindOfClass:[AVQueuePlayer class]] || [(AVQueuePlayer *)self.player items].count <= 1) {
		self.wantsToPlay = NO;
	}
}

- (void)playerItemNewAccessLogEntry:(NSNotification *)notification {
	AVPlayerItem *playerItem = notification.object;
	NSArray *logEvents=playerItem.accessLog.events;
	AVPlayerItemAccessLogEvent *event = (AVPlayerItemAccessLogEvent *)[logEvents lastObject];
	float observedBitrate = event.observedBitrate / 8;
	NSLog(@">>>Download rate (kB/s): %.1f", observedBitrate);
}

#pragma mark Key-Value Observance

- (void)observeValueForKeyPath:(NSString*) path
					  ofObject:(id)object
						change:(NSDictionary*)change
					   context:(void*)context {

	if (context == PlayerCurrentItemObservationContext) {
		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

		if (_currentItem) {
			[defaultCenter removeObserver:self
									 name:AVPlayerItemPlaybackStalledNotification
								   object:_currentItem];

			[defaultCenter removeObserver:self
									 name:AVPlayerItemDidPlayToEndTimeNotification
								   object:_currentItem];

			[_currentItem removeObserver:self
							  forKeyPath:PlayerItemLoadedTimeRangesKeyPath
								 context:PlayerItemLoadedTimeRangesContext];

			[defaultCenter removeObserver:self
									 name:AVPlayerItemNewAccessLogEntryNotification
								   object:_currentItem];
		}

		_currentItem = self.player.currentItem;

		if (_currentItem) {
			[defaultCenter addObserver:self
							  selector:@selector(playerItemDidStalled:)
								  name:AVPlayerItemPlaybackStalledNotification
								object:_currentItem];

			[defaultCenter addObserver:self
							  selector:@selector(playerItemDidPlayToEndTime:)
								  name:AVPlayerItemDidPlayToEndTimeNotification
								object:_currentItem];

			[_currentItem addObserver:self
						   forKeyPath:PlayerItemLoadedTimeRangesKeyPath
							  options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
							  context:PlayerItemLoadedTimeRangesContext];

			[defaultCenter addObserver:self
							  selector:@selector(playerItemNewAccessLogEntry:)
								  name:AVPlayerItemNewAccessLogEntryNotification
								object:_currentItem];

			//self.scrubber.hidden = NO;
			if (self.player.rate != 0) {
				//self.wantsToPlay = YES;
				self.player.rate = 0;
			}

			//self.nextButton.enabled = [self.player isKindOfClass:[AVQueuePlayer class]] && [(AVQueuePlayer *)self.player items].count > 1;

		} else {
			//self.scrubber.hidden = YES;
			self.scrubber.value = 0;
			self.scrubber.progress = 0;
			self.playbackTimeLabel.text = @"-:--";
			self.remainingPlaybackTimeLabel.text = @"-:--";
			[self hideStandbyView];
			self.shouldAutohideControls = NO;
		}

		self.stalled = YES;

	} else if (context == PlayerRateObservationContext) {
		if (!self.isPlaying && self.player.rate != 0) {
			//self.wantsToPlay = YES;
		}

	} else if (context == PlayerItemLoadedTimeRangesContext) {
		float loadedDuration = 0.0;

		for (NSValue *time in _currentItem.loadedTimeRanges) {
			CMTimeRange range = [time CMTimeRangeValue];
			loadedDuration = MAX(loadedDuration, CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration));
		}

		float duration = CMTimeGetSeconds(_currentItem.duration);

		if (self.stalled) {
			static float lastDuration = 0;
			static float loadingRate = 0;

			float time = CACurrentMediaTime();
			float currentTime = CMTimeGetSeconds(_currentItem.currentTime);

			if (_loadedTime != 0) {
				loadingRate = (loadedDuration - lastDuration)/(time - _loadedTime) * 0.1 + loadingRate * 0.9;

				_remainingToLoad = (duration - currentTime) * (1.0 / loadingRate -  1.0);

				NSLog(@">>>Remaining to load: %.1f", _remainingToLoad);

				if (_remainingToLoad < 0 || loadedDuration >= duration) {
					self.wantsToPlay = YES;
					self.stalled = NO;
					lastDuration = 0;
					loadingRate = 0;

				} else {
					self.player.rate = 0;
				}

			} else {
				[self updateTimeIndicatorsWithTime:_currentItem.currentTime];
				[self setTitleHidden:YES animated:NO];
				self.player.rate = 0;
			}

			_loadedTime = time;
			lastDuration = loadedDuration;
		}

		self.scrubber.progress = loadedDuration / duration;
		[self.scrubber setNeedsDisplay];
		
	} else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}

@end
