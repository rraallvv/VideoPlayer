/*
 * VideoPlayerView.h
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

#import <UIKit/UIKit.h>

extern NSString * const VideoPlayerPrevItemNotification;
extern NSString * const VideoPlayerNextItemNotification;
extern NSString * const VideoPlayerCloseNotification;


@protocol VideoPlayerViewDelegate

- (BOOL)shouldShowPlaybackControls;

@end


@class AVPlayer, AVPlayerLayer;

@interface VideoPlayerView : UIView

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic, readonly) AVPlayerLayer *playerLayer;
@property (weak, nonatomic) UIViewController <VideoPlayerViewDelegate> *delegate;
@property (weak, nonatomic) IBOutlet UIView *contentOverlayView;

@property (nonatomic) BOOL fullscreen;
@property (weak, nonatomic) UIView *containerView;

@property (weak, nonatomic, readonly) UIButton *prevButton;
@property (weak, nonatomic, readonly) UIButton *nextButton;

@property (strong, nonatomic, readonly) UITapGestureRecognizer *tapGestureRcognizer;
@property (strong, nonatomic, readonly) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property (strong, nonatomic, readonly) UIPinchGestureRecognizer *pinchGestureRecognizer;
@property (strong, nonatomic, readonly) UISwipeGestureRecognizer *prevSwipeGestureRecognizer;
@property (strong, nonatomic, readonly) UISwipeGestureRecognizer *nextSwipeGestureRecognizer;

- (void)setFullscreen:(BOOL)fullscreen completion:(void (^)(void))completion;
- (void)closePlayer;

@end
