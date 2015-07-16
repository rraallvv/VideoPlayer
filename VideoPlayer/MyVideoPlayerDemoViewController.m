//
//  MyVideoPlayerDemoViewController.m
//  VideoPlayer
//
//  Created by Rhody Lugo.
//  Copyright (c) 2015 Rhody Lugo.
//

#import "MyVideoPlayerDemoViewController.h"
#import "VideoPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>

static NSString * const onlineVideo = @"http://media.w3.org/2010/05/sintel/trailer.mp4";

@interface MyVideoPlayerDemoViewController ()

@property (strong, nonatomic) VideoPlayerViewController *playerViewController;
@property (weak, nonatomic) IBOutlet UIView *videoView;

@end

@implementation MyVideoPlayerDemoViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	/* The Custom Video Player */
	VideoPlayerViewController *playerViewController = [[VideoPlayerViewController alloc] init];
	[self.videoView addSubview:playerViewController.view];
	self.playerViewController = playerViewController;

	//self.playerViewController.player = [[AVPlayer alloc] init];

	//[self addChildViewController:playerViewController];
	//[self performSelector:@selector(presentModally) withObject:nil afterDelay:0.0];
}

- (void)presentModally {
	[self presentViewController:self.playerViewController animated:YES completion:nil];
}

#pragma mark Player actions

- (IBAction)playVideoFromURL:(id)sender {
	NSURL *url = [NSURL URLWithString:onlineVideo];
	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
	self.videoView.hidden = NO;
}

- (IBAction)playVideo1ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video1" withExtension:@"mp4"];

	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
	self.videoView.hidden = NO;
}

- (IBAction)playVideo2ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"];

	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
	self.videoView.hidden = NO;
}

- (IBAction)playBothVideosButtonAction:(id)sender {
	AVPlayerItem *playerItem1 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video1" withExtension:@"mp4"]];
	AVPlayerItem *playerItem2 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"]];
	AVQueuePlayer *queuePlayer = [AVQueuePlayer queuePlayerWithItems:@[playerItem1, playerItem2]];
	[queuePlayer play];
	self.playerViewController.player = queuePlayer;
	self.videoView.hidden = NO;
}

@end
