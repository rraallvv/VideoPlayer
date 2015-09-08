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

/* Custom notifications */
NSString * const VideoPlayerPrevItemNotification = @"VideoPlayerPrevItemNotification";
NSString * const VideoPlayerNextItemNotification = @"VideoPlayerNextItemNotification";

/* Animation parameters */
static const CGFloat FullscreenTransitionDuration = 0.375;//0.25//0.5
static const CGFloat BoundsElasticity = 0.625;//0.5;//0.75;
static const CGFloat BoundsRestitutionDuration = 0.1;
static const CGFloat SwipeFadeDuration = 0.2;//0.1;
static const CGFloat ControlsFadeDuration = 0.5;
static const CGFloat swipeVelocityThreshold = 1638.4;//819.2;//409.6;

/* Layout parameters */
static CGFloat const separation = 8.0;

/* Key-Value Observation keys */
static NSString * const PlayerCurrentItemObservationKeypath = @"player.currentItem";
static NSString * const PlayerRateObservationKeypath = @"player.rate";

/* Key-Value Observation contexts */
static void *PlayerCurrentItemObservationContext = &PlayerCurrentItemObservationContext;
static void *PlayerRateObservationContext = &PlayerRateObservationContext;

/* Time line indicator */
static CGFloat const TimeLineIndicatorWidth = 1.0;//2.0;

static NSString *stringFromCMTime(CMTime time) {
	int seconds = CMTimeGetSeconds(time);

	int hours = floor(seconds / 3600);
	int minutes = floor(seconds % 3600 / 60);
	seconds = floor(seconds % 3600 % 60);

	return [NSString stringWithFormat:@"%i:%02i:%02i", hours, minutes, seconds];
}

@interface VideoPlayerView ()

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UISlider *scrubber;
@property (weak, nonatomic) IBOutlet UILabel *playbackTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *remainingPlaybackTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *zoomButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *prevButton;
@property (weak, nonatomic) IBOutlet UIButton *nextButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeView;
@property (weak, nonatomic) IBOutlet UIView *topControlsView;
@property (weak, nonatomic) IBOutlet UIView *bottomControlsView;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapGestureRcognizer;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic) IBOutlet UIPinchGestureRecognizer *pinchGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *prevSwipeGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *nextSwipeGestureRecognizer;
@property (nonatomic) BOOL controlsHidden;
@property (nonatomic) BOOL showBorders;
@property (nonatomic) BOOL wantsToPlay;
@property (nonatomic, getter=isPlaying) BOOL playing;
@property (nonatomic) BOOL stalled;
@property (nonatomic) BOOL showsActivityIndicator;
@property (strong, nonatomic) IBOutlet UIImageView *thumbnailView;

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
}


#pragma mark Lifecycle

+ (Class)layerClass {
	return [AVPlayerLayer class];
}

- (void)awakeFromNib {
	//self.scrubber.hidden = YES;
	self.activityIndicator.hidesWhenStopped = YES;
	_canToggleFullscreen = YES;
	_shouldChangeContainerView = YES;

	[self.tapGestureRcognizer requireGestureRecognizerToFail:self.doubleTapGestureRecognizer];

	_timeLineLayer = [CALayer layer];
	_timeLineLayer.backgroundColor = [UIColor whiteColor].CGColor;
	[self.layer addSublayer:_timeLineLayer];

	self.showBorders = YES;
	self.layer.backgroundColor = [UIColor blackColor].CGColor;
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
	[super layoutSubviews];

	CGRect playerFrame = self.frame;
	CGFloat playerFrameWidth = CGRectGetWidth(playerFrame);

	/* Top view */
	CGRect topControlsFrame = self.topControlsView.frame;
	topControlsFrame = CGRectMake(0,
								  0,
								  playerFrameWidth,
								  CGRectGetHeight(topControlsFrame));
	self.topControlsView.frame = topControlsFrame;
	CGRect topControlsBounds = self.topControlsView.bounds;

	/* Close button */
	CGRect closeButtonFrame = self.closeButton.frame;
	self.closeButton.center = CGPointMake(separation + CGRectGetWidth(closeButtonFrame)/2,
										  CGRectGetMidY(topControlsBounds));

	/* Zoom button */
	CGRect zoomButtonFrame = self.zoomButton.frame;
	self.zoomButton.center = CGPointMake(CGRectGetWidth(topControlsBounds) - separation - CGRectGetWidth(zoomButtonFrame)/2,
										 CGRectGetMidY(topControlsBounds));

	/* Time labels and the scrubber */
	[self layoutTimeIndicatorsInRect:playerFrame];

	/* Bottom view */
	CGRect bottomControlsFrame = self.bottomControlsView.frame;
	bottomControlsFrame = CGRectMake(0,
									 CGRectGetMaxY(playerFrame) - CGRectGetHeight(bottomControlsFrame),
									 playerFrameWidth,
									 CGRectGetHeight(bottomControlsFrame));
	self.bottomControlsView.frame = bottomControlsFrame;
	CGRect bottomControlsBounds = self.bottomControlsView.bounds;

	/* Play button*/
	self.playButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds),
										 CGRectGetMidY(bottomControlsBounds));

	/* Volume view */
	CGRect volumeFrame = self.volumeView.frame;
	volumeFrame = CGRectMake(separation,
							 CGRectGetMidY(bottomControlsBounds) - CGRectGetHeight(volumeFrame)/2,
							 CGRectGetWidth(bottomControlsBounds)/4,
							 CGRectGetHeight(volumeFrame));
	self.volumeView.frame = volumeFrame;

	CGFloat const prevNextSeparation = (CGRectGetMidX(bottomControlsBounds) - CGRectGetMaxX(self.volumeView.frame)) / 2;

	/* Prev button*/
	self.prevButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) - prevNextSeparation,
										 CGRectGetMidY(bottomControlsBounds));

	/* Next button*/
	self.nextButton.center = CGPointMake(CGRectGetMidX(bottomControlsBounds) + prevNextSeparation,
										 CGRectGetMidY(bottomControlsBounds));

	/* Activity indicator */
	self.activityIndicator.center = CGPointMake(CGRectGetMidX(playerFrame),
												CGRectGetMidY(playerFrame));

	/* Content overlay and thumbnail views */
	self.contentOverlayView.frame = self.frame;
	self.thumbnailView.frame = self.playerLayer.videoRect;
}

- (void)dealloc {
	[self.layer removeObserver:self forKeyPath:PlayerCurrentItemObservationKeypath];
}


#pragma mark Drawing

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
	printf(".");
}

#pragma mark Accessors

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	self.thumbnailView.frame = self.playerLayer.videoRect;
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
						forKeyPath:PlayerCurrentItemObservationKeypath
						   context:PlayerCurrentItemObservationContext];
		[self.layer removeObserver:self
						forKeyPath:PlayerRateObservationKeypath
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
				if (minInterval < delta && delta < maxInterval) {
					self.stalled = NO;
					self.playing = YES;
					self.thumbnailView.image = nil;
				}
			}

			CMTime endTime = CMTimeConvertScale(weakPlayerRef.currentItem.asset.duration, time.timescale, kCMTimeRoundingMethod_RoundHalfAwayFromZero);
			if (CMTimeCompare(endTime, kCMTimeZero) != 0) {
				double normalizedTime = (double) time.value / (double) endTime.value;
				self.scrubber.value = normalizedTime;
			}

			self.playbackTimeLabel.text = stringFromCMTime(time);
			self.remainingPlaybackTimeLabel.text = [NSString stringWithFormat:@"-%@", stringFromCMTime(CMTimeSubtract(endTime, time))];
		}

		[self layoutTimeIndicatorsInRect:self.frame];

		lastTime = time;
	}];

	[self.layer addObserver:self
				 forKeyPath:PlayerCurrentItemObservationKeypath
					options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					context:PlayerCurrentItemObservationContext];

	[self.layer addObserver:self
				 forKeyPath:PlayerRateObservationKeypath
					options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					context:PlayerRateObservationContext];
}

- (AVPlayerLayer *)playerLayer {
	return (AVPlayerLayer *)self.layer;
}

- (BOOL)fullscreen {
	return self.containerView != self.superview && self.delegate.presentingViewController;
}

- (void)setFullscreen:(BOOL)fullscreen {
	if (!_canToggleFullscreen || fullscreen == self.fullscreen) {
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
		self.containerView.hidden = YES;
		[_timeLineLayer removeFromSuperlayer];

		[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
			self.frame = screenBounds;

		} completion:^(BOOL finished) {
			if (self.delegate.parentViewController) {
				[self.delegate removeFromParentViewController];
			}
			[UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:self.delegate animated:NO completion:^{
				[self.zoomButton setImage:[UIImage imageNamed:@"ZoomOut"] forState:UIControlStateNormal];

				self.controlsHidden = NO;
				self.showBorders = NO;

				if (self.stalled) {
					self.showsActivityIndicator = YES;
				}

				[self setNeedsLayout];

				_canToggleFullscreen = YES;
				_shouldChangeContainerView = YES;
			}];
		}];

	} else {
		self.topControlsView.hidden = YES;
		self.bottomControlsView.hidden = YES;

		[UIApplication.sharedApplication.keyWindow addSubview:self];

		void (^completionBlock)() = ^{
			[UIApplication.sharedApplication.keyWindow addSubview:self];
			self.frame = initialFrame;
			self.showBorders = YES;

			[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
				self.frame = [self containerViewFrame];

			} completion:^(BOOL finished) {
				[self.containerView addSubview:self];
				self.frame = self.containerView.bounds;
				self.containerView.hidden = NO;
				[self.layer addSublayer:_timeLineLayer];

				[self.zoomButton setImage:[UIImage imageNamed:@"ZoomIn"] forState:UIControlStateNormal];

				if (self.stalled) {
					self.showsActivityIndicator = YES;
				}

				[self setNeedsLayout];

				_canToggleFullscreen = YES;
				_shouldChangeContainerView = YES;
			}];
		};

		UIViewController *presentingViewController = self.delegate.presentingViewController;

		if (presentingViewController) {
			//[UIApplication.sharedApplication.keyWindow addSubview:self];
			[presentingViewController dismissViewControllerAnimated:NO completion:completionBlock];
		} else {
			completionBlock();
		}
	}
}

- (BOOL)controlsHidden {
	return self.topControlsView.hidden || self.bottomControlsView.hidden;
}

- (void)setControlsHidden:(BOOL)controlsHidden {
	if (controlsHidden) {
		[_hideControlsTimer invalidate];

		[UIView animateWithDuration:ControlsFadeDuration animations:^{
			self.topControlsView.alpha = 0.0;
			self.bottomControlsView.alpha = 0.0;
		} completion:^(BOOL finished) {
			self.topControlsView.hidden = YES;
			self.bottomControlsView.hidden = YES;
		}];

	} else if ([self.delegate shouldShowPlaybackControls]) {
		self.topControlsView.hidden = NO;
		self.bottomControlsView.hidden = NO;
		self.topControlsView.alpha = 1.0;
		self.bottomControlsView.alpha = 1.0;
		_hideControlsTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
															  target:self
															selector:@selector(hideControlsTimer)
															userInfo:nil
															 repeats:NO];
	}
}

- (void)setWantsToPlay:(BOOL)wantsToPlay {
	if (!self.player.currentItem) {
		return;
	}
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
		[self.playButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
	} else {
		[self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
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
	self.showsActivityIndicator = stalled;
	_stalled = stalled;
}

#pragma mark Actions

- (IBAction)scrubberTouchDown:(id)sender {
	[_hideControlsTimer invalidate];
	[self.player pause];
}

- (IBAction)scrubberTouchUp:(id)sender {
	self.controlsHidden = NO;
	if (self.wantsToPlay) {
		self.stalled = YES;
		self.playing = NO;
		[self.player play];
	}
}

- (IBAction)scrubberValueChanged:(id)sender {
	NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
	CMTime newTime = CMTimeMakeWithSeconds(self.scrubber.value * duration, self.player.currentTime.timescale);
	[self.player seekToTime:newTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}


- (IBAction)zoomButtonTouchUpInside:(UIButton *)sender {
	self.fullscreen = !self.fullscreen;
}

- (IBAction)playButtonTouchUpInside:(UIButton *)sender {
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

- (IBAction)tapGestureRecognizer:(UITapGestureRecognizer *)sender {
	if (!self.fullscreen) {
		self.fullscreen = YES;
	} else {
		self.controlsHidden = !self.controlsHidden;
	}
}

- (IBAction)doubleTapGestureRecognizer:(UITapGestureRecognizer *)sender {
	[self toggleWantsToPlay];
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

			if (velocityMagnitud > swipeVelocityThreshold) {
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
										 self.containerView.hidden = YES;
										 self.containerView.alpha = 1.0;
										 [self closePlayer];
									 }];
				});
			}
		}
	}
}

- (IBAction)pinchGestureRecognizer:(UIPinchGestureRecognizer *)sender {
	if (self.fullscreen) {
#if 0 // TODO: This fails to continue the pinch gesture after dismissing the view controller
		UIGestureRecognizerState state = sender.state;

		static CGRect initialFrame;

		if (state == UIGestureRecognizerStateBegan) {
			self.bottomControlsView.hidden = YES;
			self.topControlsView.hidden = YES;

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
	}
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
}


#pragma mark Helper methods

- (void)toggleWantsToPlay {
	self.wantsToPlay = !self.isPlaying;
}

- (void)closePlayer {
	if ([self.player isKindOfClass:[AVQueuePlayer class]]) {
		[(AVQueuePlayer *)self.player removeAllItems];
	} else {
		[self.player replaceCurrentItemWithPlayerItem:nil];
	}
	self.fullscreen = NO;
}

- (void)hideControlsTimer {
	self.controlsHidden = YES;
}

- (CGRect)containerViewFrame {
	CGRect frame = self.containerView.frame;
	frame.origin = [self.containerView.superview convertPoint:frame.origin toView:[UIApplication sharedApplication].keyWindow.rootViewController.view];
	return frame;
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
	/* Playback time */
	[self.playbackTimeLabel sizeToFit];
	CGRect playbackTimeFrame = self.playbackTimeLabel.frame;
	self.playbackTimeLabel.center = CGPointMake(CGRectGetMaxX(self.closeButton.frame) + separation + CGRectGetWidth(playbackTimeFrame)/2,
												CGRectGetMidY(playbackTimeFrame));

	/* Remaining playback time */
	[self.remainingPlaybackTimeLabel sizeToFit];
	CGRect remainingPlaybackTimeFrame = self.remainingPlaybackTimeLabel.frame;
	self.remainingPlaybackTimeLabel.center = CGPointMake(CGRectGetMinX(self.zoomButton.frame) - separation - CGRectGetWidth(remainingPlaybackTimeFrame)/2,
														 CGRectGetMidY(remainingPlaybackTimeFrame));

	/* Scrubber */
	CGRect scrubberFrame = self.scrubber.frame;
	CGFloat scrubberMinX = CGRectGetMaxX(self.playbackTimeLabel.frame) + separation;
	CGFloat scrubberMaxX = CGRectGetMinX(self.remainingPlaybackTimeLabel.frame) - separation;
	scrubberFrame = CGRectMake(scrubberMinX,
							   CGRectGetMinY(scrubberFrame),
							   scrubberMaxX - scrubberMinX,
							   CGRectGetHeight(scrubberFrame));
	self.scrubber.frame = scrubberFrame;

	/* Time line progess indicator */
	CGFloat borderWidth = self.layer.borderWidth;
	_timeLineLayer.frame = CGRectMake(borderWidth,
											  CGRectGetHeight(rect) - TimeLineIndicatorWidth - borderWidth,
											  self.scrubber.value * (CGRectGetWidth(rect) - 2 * borderWidth),
											  TimeLineIndicatorWidth);
}


#pragma mark Notification handlers

- (void)playerItemDidStalled:(NSNotification *)notification {
	if (!self.thumbnailView.image) {
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

			UIImage *thumbnail = [UIImage imageWithCGImage:imageRef];
			CGImageRelease(imageRef);

			if (!self.stalled) {
				NSLog(@"Playback stalled but failed to get the video capture on time.");
				return;
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				self.thumbnailView.image = thumbnail;
				self.thumbnailView.frame = self.playerLayer.videoRect;
			});
		});

	} else {
		NSLog(@"Stalled with a thumbnail image already generated.");
	}

	self.stalled = YES;
	self.playing = NO;
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification {
	self.stalled = NO;
	if (![self.player isKindOfClass:[AVQueuePlayer class]] || [(AVQueuePlayer *)self.player items].count <= 1) {
		self.wantsToPlay = NO;
	}
}


#pragma mark Key-Value Observance

- (void)observeValueForKeyPath:(NSString*) path
					  ofObject:(id)object
						change:(NSDictionary*)change
					   context:(void*)context {

	if (context == PlayerCurrentItemObservationContext) {
		AVPlayerItem *oldItem = [change objectForKey:@"old"];

		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

		if (oldItem && oldItem != (id)[NSNull null]) {
			[defaultCenter removeObserver:self
									 name:AVPlayerItemPlaybackStalledNotification
								   object:oldItem];

			[defaultCenter removeObserver:self
									 name:AVPlayerItemDidPlayToEndTimeNotification
								   object:oldItem];
		}

		AVPlayerItem *newItem = [change objectForKey:@"new"];

		if (newItem && newItem != (id)[NSNull null]) {
			[defaultCenter addObserver:self
							  selector:@selector(playerItemDidStalled:)
								  name:AVPlayerItemPlaybackStalledNotification
								object:newItem];

			[defaultCenter addObserver:self
							  selector:@selector(playerItemDidPlayToEndTime:)
								  name:AVPlayerItemDidPlayToEndTimeNotification
								object:newItem];

			//self.scrubber.hidden = NO;
			if (self.player.rate != 0) {
				self.wantsToPlay = YES;
			}

			//self.nextButton.enabled = [self.player isKindOfClass:[AVQueuePlayer class]] && [(AVQueuePlayer *)self.player items].count > 1;
			
		} else {
			//self.scrubber.hidden = YES;
			self.scrubber.value = 0;
			self.playbackTimeLabel.text = @"-:--:--";
			self.remainingPlaybackTimeLabel.text = @"-:--:--";
		}

		self.stalled = YES;

	} else if (context == PlayerRateObservationContext) {
		if (!self.isPlaying && self.player.rate != 0) {
			self.wantsToPlay = YES;
		}

	} else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}

@end
