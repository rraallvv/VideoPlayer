//
//  MainViewController.m
//  VideoPlayer
//
//  Created by Rhody Lugo.
//  Copyright (c) 2015 Rhody Lugo.
//

#import "MainViewController.h"
#import "VideoPlayerViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface MainViewController ()

@property (strong, nonatomic) VideoPlayerViewController *playerViewController;
@property (weak, nonatomic) IBOutlet UIView *videoView;

@end

@implementation MainViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	VideoPlayerViewController *playerViewController = [[VideoPlayerViewController alloc] init];
	[self.videoView addSubview:playerViewController.view];
	self.playerViewController = playerViewController;

	//[self addChildViewController:playerViewController];

	dispatch_async(dispatch_get_main_queue(), ^{
		//[self presentViewController:self.playerViewController animated:YES completion:nil];
	});
}

- (IBAction)playVideo1ButtonAction:(id)sender {
	AVPlayer *player = [AVPlayer playerWithURL:[[NSBundle mainBundle] URLForResource:@"video_1" withExtension:@"mp4"]];
	[player play];
	self.playerViewController.player = player;
	self.videoView.hidden = NO;
}

- (IBAction)playVideo2ButtonAction:(id)sender {
	AVPlayer *player = [AVPlayer playerWithURL:[[NSBundle mainBundle] URLForResource:@"video_2" withExtension:@"mp4"]];
	[player play];
	self.playerViewController.player = player;
	self.videoView.hidden = NO;
}

- (IBAction)playBothVideosButtonAction:(id)sender {
	AVPlayerItem *playerItem1 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video_1" withExtension:@"mp4"]];
	AVPlayerItem *playerItem2 = [AVPlayerItem playerItemWithURL:[[NSBundle mainBundle] URLForResource:@"video_2" withExtension:@"mp4"]];
	AVQueuePlayer *queuePlayer = [AVQueuePlayer queuePlayerWithItems:@[playerItem1, playerItem2]];
	[queuePlayer play];
	self.playerViewController.player = queuePlayer;
	self.videoView.hidden = NO;
}

@end
