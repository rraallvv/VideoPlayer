//
//  AVPlayerDemoViewController.m
//  VideoPlayer
//
//  Created by Rhody Lugo.
//  Copyright (c) 2015 Rhody Lugo.
//

#import "AVPlayerDemoViewController.h"
#import "VideoPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

static NSString * const onlineVideo = @"http://media.w3.org/2010/05/sintel/trailer.mp4";

@interface AVPlayerDemoViewController ()

@property (strong, nonatomic) AVPlayerViewController *playerViewController;
@property (weak, nonatomic) IBOutlet UIView *playerView;

@end

@implementation AVPlayerDemoViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	/* AVKit player view controller */
	AVPlayerViewController *playerViewController = [[AVPlayerViewController alloc] init];
	playerViewController.view.frame = self.playerView.bounds;
	[self.playerView addSubview:playerViewController.view];
	self.playerViewController = playerViewController;
}

#pragma mark playerViewController actions

- (IBAction)playVideoFromURL:(id)sender {
	NSURL *url = [NSURL URLWithString:onlineVideo];
	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
}

- (IBAction)playVideo1ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video1" withExtension:@"mp4"];

	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
}

- (IBAction)playVideo2ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"];

	AVPlayer *player = [AVPlayer playerWithURL:url];
	[player play];
	self.playerViewController.player = player;
}

- (IBAction)playBothVideosButtonAction:(id)sender {
	AVPlayerItem *playerItem1 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video1" withExtension:@"mp4"]];
	AVPlayerItem *playerItem2 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"]];
	AVQueuePlayer *queuePlayer = [AVQueuePlayer queuePlayerWithItems:@[playerItem1, playerItem2]];
	[queuePlayer play];
	self.playerViewController.player = queuePlayer;
}

@end
