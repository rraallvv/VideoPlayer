//
//  MPMoviePlayerDemoViewController.m
//  VideoPlayer
//
//  Created by Rhody Lugo.
//  Copyright (c) 2015 Rhody Lugo.
//

#import "MPMoviePlayerDemoViewController.h"
#import "VideoPlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>

static NSString * const onlineVideo = @"http://media.w3.org/2010/05/sintel/trailer.mp4";

@interface MPMoviePlayerDemoViewController ()

@property (strong, nonatomic) MPMoviePlayerViewController *playerViewController;
@property (weak, nonatomic) IBOutlet UIView *playerView;

@end

@implementation MPMoviePlayerDemoViewController

- (void)viewDidLoad {
	[super viewDidLoad];

	/* MediaPlayer controller */
	MPMoviePlayerViewController *playerViewController = [[MPMoviePlayerViewController alloc] init];
	playerViewController.moviePlayer.shouldAutoplay = YES;
	playerViewController.moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
	playerViewController.view.frame = self.playerView.bounds;
	[self.playerView addSubview:playerViewController.view];
	self.playerViewController = playerViewController;
}

#pragma mark MPMoviePlayerViewController actions

- (IBAction)playVideoFromURL:(id)sender {
	NSURL *url = [NSURL URLWithString:onlineVideo];
	self.playerViewController.moviePlayer.contentURL = url;
}

- (IBAction)playVideo1ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video1" withExtension:@"mp4"];
	self.playerViewController.moviePlayer.contentURL = url;
	[self.playerViewController.moviePlayer play];
}

- (IBAction)playVideo2ButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"video2" withExtension:@"mp4"];
	self.playerViewController.moviePlayer.contentURL = url;
	[self.playerViewController.moviePlayer play];
}

- (IBAction)playBothVideosButtonAction:(id)sender {
	NSURL *url = [[NSBundle mainBundle] URLForResource:@"playlist" withExtension:@"m3u"];
	self.playerViewController.moviePlayer.contentURL = url;
	[self.playerViewController.moviePlayer play];
}

@end
