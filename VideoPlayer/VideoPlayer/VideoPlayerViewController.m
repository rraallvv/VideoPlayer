/*
 * VideoPlayerViewController.m
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

#import "VideoPlayerViewController.h"
#import "VideoPlayerView.h"
#import <AVFoundation/AVFoundation.h>


@interface VideoPlayerViewController () <VideoPlayerViewDelegate>

@end


@implementation VideoPlayerViewController


#pragma mark Accessors

- (VideoPlayerView *)playerView {
	return (VideoPlayerView *)self.view;
}

- (AVPlayer *)player {
	return self.playerView.player;
}

- (void)setPlayer:(AVPlayer *)player {
	self.playerView.player = player;
}

- (CGRect)videoBounds {
	CALayer *layer = self.playerView.playerLayer.sublayers.firstObject;
	CGRect transformedBounds = CGRectApplyAffineTransform(layer.bounds, CATransform3DGetAffineTransform(layer.sublayerTransform));
	return transformedBounds;
}

- (NSString *)videoGravity {
	return self.playerView.playerLayer.videoGravity;
}

- (void)setVideoGravity:(NSString *)videoGravity {
	self.playerView.playerLayer.videoGravity = videoGravity;
}

- (BOOL)isReadyForDisplay {
	return self.player.status == AVPlayerStatusReadyToPlay;
}

- (UIView *)contentOverlayView {
	return self.playerView.contentOverlayView;
}

- (void)setFullscreen:(BOOL)fullscreen {
	self.playerView.fullscreen = fullscreen;
}


#pragma mark Lifecycle

- (void)loadView {
	self.showsPlaybackControls = YES;

	VideoPlayerView *playerView = [[[NSBundle mainBundle] loadNibNamed:@"VideoPlayerView"
																 owner:self
															   options:nil] objectAtIndex:0];
	self.view = playerView;

	self.playerView.delegate = self;
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)dealloc {
	[self.player pause];
	self.player = nil;
}


#pragma mark Delegate methods

- (BOOL)shouldShowPlaybackControls {
	return self.showsPlaybackControls;
}

@end
