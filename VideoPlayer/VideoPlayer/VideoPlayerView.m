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


/* Animation parameters */
static const CGFloat FullscreenTransitionDuration = 0.375;//0.25//0.5
static const CGFloat PanBorderSpringFactor = 0.625;//0.5;//0.75;
static const CGFloat PanBorderSpringRestitutionDuration = 0.1;
static const CGFloat FadeDuration = 0.2;//0.1;

/* Key-Value Observation keys */
NSString * const PlayerRateObservationKeypath	= @"player.rate";
NSString * const PlayerCurrentItemObservationKeypath	= @"player.currentItem";

/* Key-Value Observation contexts */
static void *PlayerRateObservationContext = &PlayerRateObservationContext;
static void *PlayerCurrentItemObservationContext = &PlayerCurrentItemObservationContext;

static NSString *stringFromCMTime(CMTime time) {
	NSUInteger seconds = CMTimeGetSeconds(time);

	NSUInteger hours = floor(seconds / 3600);
	NSUInteger minutes = floor(seconds % 3600 / 60);
	seconds = floor(seconds % 3600 % 60);

	return [NSString stringWithFormat:@"%i:%02i:%02i", hours, minutes, seconds];
}

@interface VideoPlayerView ()

@property (weak, nonatomic) IBOutlet UISlider *scrubber;
@property (weak, nonatomic) IBOutlet UILabel *playBackTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *zoomButton;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet MPVolumeView *volumeView;
@property (weak, nonatomic) IBOutlet UIView *topControlsView;
@property (weak, nonatomic) IBOutlet UIView *bottomControlsView;
@property (weak, nonatomic) UIView *containerView;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *tapGestureRcognizer;
@property (strong, nonatomic) IBOutlet UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic) IBOutlet UISwipeGestureRecognizer *swipeGestureRecognizer;
@property (assign, nonatomic) BOOL fullscreen;
@property (assign, nonatomic) BOOL controlsHidden;
@property (assign, nonatomic) BOOL showBorders;

@end


@implementation VideoPlayerView {
	NSTimer *_hideControlsTimer;
	BOOL _shouldPlayAfterScrubbing;
	CGPoint _initialPanPosition;
	BOOL _swipeGestureRecognized;
	CGPoint _swipeVelocity;
}


#pragma mark Lifecycle

+ (Class)layerClass {
	return [AVPlayerLayer class];
}

- (void)didMoveToSuperview {
	[super didMoveToSuperview];
	self.layer.backgroundColor = [UIColor blackColor].CGColor;
	if (!self.containerView) {
		self.containerView = self.superview;
		self.frame = CGRectMake(0, 0, CGRectGetWidth(self.containerView.frame), CGRectGetHeight(self.containerView.frame));
		self.showBorders = YES;
	}
}

- (void)dealloc {
	[self.layer removeObserver:self forKeyPath:PlayerCurrentItemObservationKeypath];
	[self.layer removeObserver:self forKeyPath:PlayerRateObservationKeypath];
}

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	return YES;
}


#pragma mark Accessors

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
	return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)player {
	if (self.player) {
		[self.layer removeObserver:self
						forKeyPath:PlayerCurrentItemObservationKeypath
						   context:PlayerCurrentItemObservationContext];
	}

	[(AVPlayerLayer*)[self layer] setPlayer:player];

	if (!player) {
		return;
	}

	self.showBorders = YES;

	__weak AVPlayer *weakPlayerRef = player;

	CMTime interval = CMTimeMake(33, 1000);
	[player addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock: ^(CMTime time) {
		CMTime endTime = CMTimeConvertScale(weakPlayerRef.currentItem.asset.duration, weakPlayerRef.currentTime.timescale, kCMTimeRoundingMethod_RoundHalfAwayFromZero);
		if (CMTimeCompare(endTime, kCMTimeZero) != 0) {
			double normalizedTime = (double) player.currentTime.value / (double) endTime.value;
			self.scrubber.value = normalizedTime;
		}
		self.playBackTimeLabel.text = stringFromCMTime(weakPlayerRef.currentTime);
	}];

	[self.layer addObserver:self
				 forKeyPath:PlayerCurrentItemObservationKeypath
					options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
					context:PlayerCurrentItemObservationContext];
}

- (BOOL)fullscreen {
	return self.containerView != self.superview;
}

- (void)setFullscreen:(BOOL)fullscreen {
	if (fullscreen == self.fullscreen) {
		return;
	}

	static CGRect theRect;

	if (CGRectIsEmpty(theRect)) {
		theRect = self.containerView.frame;
	}

	if (fullscreen) {
		[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
			CGRect screenRect = [[UIScreen mainScreen] bounds];
			theRect = self.containerView.frame;
			self.containerView.frame = screenRect;
			[self.zoomButton setImage:[UIImage imageNamed:@"ZoomOut"] forState:UIControlStateNormal];

		} completion:^(BOOL finished) {
			[self.delegate presentInFullscreen];
			self.controlsHidden = NO;

			self.showBorders = NO;
		}];

	} else {
		self.topControlsView.hidden = YES;
		self.bottomControlsView.hidden = YES;

		UIViewController *presentingViewController = [(id)self.delegate presentingViewController];

		if (!presentingViewController) {
			self.containerView.frame = theRect;
			self.frame = CGRectMake(0, 0, CGRectGetWidth(theRect), CGRectGetHeight(theRect));

		} else {
			[presentingViewController dismissViewControllerAnimated:NO completion:^{
				CGRect screenRect = [[UIScreen mainScreen] bounds];
				self.containerView.frame = screenRect;
				self.frame = screenRect;
				[self.containerView addSubview:self];

				self.showBorders = YES;

				[UIView animateWithDuration:FullscreenTransitionDuration animations:^{
					self.containerView.frame = theRect;
					[self.zoomButton setImage:[UIImage imageNamed:@"ZoomIn"] forState:UIControlStateNormal];
				}];
			}];
		}
	}
}

- (BOOL)isPlaying {
	return self.player.rate > 0 && !self.player.error;
}

- (BOOL)controlsHidden {
	return self.topControlsView.hidden || self.bottomControlsView.hidden;
}

- (void)setControlsHidden:(BOOL)controlsHidden {
	if (controlsHidden) {
		[_hideControlsTimer invalidate];

		[UIView animateWithDuration:0.5 animations:^{
			self.topControlsView.alpha = 0.0;
			self.bottomControlsView.alpha = 0.0;
		} completion:^(BOOL finished) {
			self.topControlsView.hidden = YES;
			self.bottomControlsView.hidden = YES;
		}];

	} else {
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


#pragma mark Actions

- (IBAction)scrubberTouchDown:(id)sender {
	[_hideControlsTimer invalidate];
	_shouldPlayAfterScrubbing = [self isPlaying];
	if (_shouldPlayAfterScrubbing) {
		[self.player pause];
	}
}

- (IBAction)scrubberTouchUp:(id)sender {
	self.controlsHidden = NO;
	if (_shouldPlayAfterScrubbing) {
		[self.player play];
	}
}

- (IBAction)scrubberValueChanged:(id)sender {
	NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.asset.duration);
	CMTime newTime = CMTimeMakeWithSeconds(self.scrubber.value * duration, self.player.currentTime.timescale);
	[self.player seekToTime:newTime];
}


- (IBAction)zoomButtonTouchUpInside:(UIButton *)sender {
	self.fullscreen = !self.fullscreen;
}

- (IBAction)playButtonTouchUpInside:(UIButton *)sender {
	if (self.isPlaying) {
		[self.player pause];
	} else {
		[self.player play];
		//self.controlsHidden = YES;
	}
}

- (IBAction)handleTapGestureRecognizer:(UITapGestureRecognizer *)sender {
	if (!self.fullscreen) {
		self.fullscreen = YES;
	} else {
		self.controlsHidden = !self.controlsHidden;
	}
}

- (IBAction)handlePanGestureRecognizer:(UIPanGestureRecognizer *)sender {
	if (!self.fullscreen) {

		CGPoint locationInView = [sender locationInView:self.containerView.superview];
		CGPoint center = self.containerView.center;

		CGRect screenRect = UIScreen.mainScreen.bounds;
		CGRect viewFrame = self.containerView.frame;

		CGFloat minX = CGRectGetWidth(viewFrame)/2;
		CGFloat maxX = CGRectGetMaxX(screenRect) - CGRectGetWidth(viewFrame)/2;
		CGFloat minY = CGRectGetHeight(viewFrame)/2;
		CGFloat maxY = CGRectGetMaxY(screenRect) - CGRectGetHeight(viewFrame)/2;

		if (sender.state == UIGestureRecognizerStateBegan) {
			_swipeVelocity = CGPointZero;
			_initialPanPosition = CGPointMake(locationInView.x - center.x, locationInView.y - center.y);
			_swipeGestureRecognized = NO;

		} else if (sender.state == UIGestureRecognizerStateChanged) {
			center = CGPointMake(locationInView.x - _initialPanPosition.x, locationInView.y - _initialPanPosition.y);

			if (center.x < minX) {
				center.x = minX - PanBorderSpringFactor * (minX - center.x);
			} else if (center.x > maxX) {
				center.x = maxX + PanBorderSpringFactor * (center.x - maxX);
			}

			if (center.y < minY) {
				center.y = minY - PanBorderSpringFactor * (minY - center.y);
			} else if (center.y > maxY) {
				center.y = maxY + PanBorderSpringFactor * (center.y - maxY);
			}

			self.containerView.center = center;

		} else if (!_swipeGestureRecognized) {
			center = CGPointMake(locationInView.x - _initialPanPosition.x, locationInView.y - _initialPanPosition.y);
			CGRect limitsRect = CGRectMake(minX, minY, maxX - minX, maxY - minY);

			if (CGRectContainsPoint(limitsRect, center)) {
				self.containerView.center = center;

			} else {
				/* Spring effect */
				[UIView animateWithDuration:PanBorderSpringRestitutionDuration animations:^{
					self.containerView.center = CGPointMake(MAX(minX, MIN(center.x, maxX)),
															MAX(minY, MIN(center.y, maxY)));
				}];
			}
		}

		if (!_swipeGestureRecognized) {
			CGPoint velocity = [sender velocityInView:self.containerView.superview];
			_swipeVelocity = CGPointMake(_swipeVelocity.x * 0.9 + velocity.x * 0.1,
										 _swipeVelocity.y * 0.9 + velocity.y * 0.1);
		}
	}
}

- (IBAction)swipeGestureRecognizer:(UISwipeGestureRecognizer *)sender {
	if (!self.fullscreen) {
		_swipeGestureRecognized = YES;

		dispatch_async(dispatch_get_main_queue(), ^{
			CGRect screenRect = UIScreen.mainScreen.bounds;
			CGRect viewFrame = self.containerView.frame;

			CGFloat minX = CGRectGetWidth(viewFrame)/2;
			CGFloat maxX = CGRectGetMaxX(screenRect) - CGRectGetWidth(viewFrame)/2;
			CGFloat minY = CGRectGetHeight(viewFrame)/2;
			CGFloat maxY = CGRectGetMaxY(screenRect) - CGRectGetHeight(viewFrame)/2;

			CGPoint center = self.containerView.center;
			CGPoint endPosition = CGPointMake(center.x + FadeDuration * _swipeVelocity.x,
											  center.y + FadeDuration * _swipeVelocity.y);
			[UIView animateWithDuration:FadeDuration
								  delay:0
								options:UIViewAnimationOptionCurveLinear
							 animations:^{
								 self.containerView.center = endPosition;
								 self.containerView.alpha = 0.0;
							 } completion:^(BOOL finished) {
								 self.containerView.center = CGPointMake(MAX(minX, MIN(endPosition.x, maxX)),
																		 MAX(minY, MIN(endPosition.y, maxY)));
								 self.containerView.alpha = 1.0;
								 [self closePlayer];
							 }];
		});
	}
}

- (IBAction)closeButtonTouchUpInside:(UIButton *)sender {
	[self closePlayer];
}


#pragma mark Helper methods

- (void)closePlayer {
	[self.player pause];
	self.player = nil;
	//if (self.fullscreen)
	{
		self.containerView.hidden = YES;
		[(id)self.delegate setModalTransitionStyle:UIModalTransitionStyleCrossDissolve];
		[[(id)self.delegate presentingViewController] dismissViewControllerAnimated:YES completion:^{
			self.fullscreen = NO;
			[self.containerView addSubview:self];
		}];
	}
}

- (void)hideControlsTimer {
	self.controlsHidden = YES;
}


#pragma mark Key-Value Observance

- (void)observeValueForKeyPath:(NSString*) path
					  ofObject:(id)object
						change:(NSDictionary*)change
					   context:(void*)context {

	if (context == PlayerCurrentItemObservationContext) {
		AVPlayerItem *oldItem = [change objectForKey:@"old"];
		if (oldItem) {
			[self.layer removeObserver:self
							forKeyPath:PlayerRateObservationKeypath
							   context:PlayerRateObservationContext];
		}

		AVPlayerItem *newItem = [change objectForKey:@"new"];
		if (newItem) {
			[self.layer addObserver:self
						 forKeyPath:PlayerRateObservationKeypath
							options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
							context:PlayerRateObservationContext];
		}

	} else if (context == PlayerRateObservationContext) {
		if (self.isPlaying) {
			[self.playButton setImage:[UIImage imageNamed:@"Pause"] forState:UIControlStateNormal];
		} else {
			[self.playButton setImage:[UIImage imageNamed:@"Play"] forState:UIControlStateNormal];
		}

	} else {
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
}

@end
