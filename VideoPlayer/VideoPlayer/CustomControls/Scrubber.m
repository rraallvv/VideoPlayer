/*
 * Scrubber.m
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

#import "Scrubber.h"

@implementation Scrubber {
	NSMutableDictionary *_maximumTrackImages;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
	if (self = [super initWithCoder:aDecoder]) {
		[self setThumbImage:[UIImage imageNamed:@"ScrubberThumb"] forState:UIControlStateNormal];

		_maximumTrackImages = [NSMutableDictionary dictionary];
		UIEdgeInsets capInsets = UIEdgeInsetsMake(0, 4, 0, 4);
		self.progressImage = [[UIImage imageNamed:@"Progress"] resizableImageWithCapInsets:capInsets];
		[self setMaximumTrackImage:[[UIImage imageNamed:@"ScrubberMax"] resizableImageWithCapInsets:capInsets] forState:UIControlStateNormal];
		[self setMinimumTrackImage:[[UIImage imageNamed:@"ScrubberMin"] resizableImageWithCapInsets:capInsets] forState:UIControlStateNormal];

		self.progress = 0.0;
	}
	return self;
}

- (void)setMaximumTrackImage:(UIImage *)image forState:(UIControlState)state {
	UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);
	UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	[super setMaximumTrackImage:[blankImage resizableImageWithCapInsets:image.capInsets]
					   forState:state];

	[_maximumTrackImages setObject:image forKey:[NSNumber numberWithInt:state]];
}

- (void)drawRect:(CGRect)rect {
	/* Draw track */
	CGRect trackRect = [self trackRectForBounds:self.bounds];

	UIImage *maximumTrackImage = [_maximumTrackImages objectForKey:[NSNumber numberWithInt:self.state]];
	[maximumTrackImage drawInRect:trackRect];

	/* Draw progress */
	if (self.progress > 0.0) {
		CGRect progressRect = CGRectMake(trackRect.origin.x, trackRect.origin.y, trackRect.size.width * self.progress, trackRect.size.height);

		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextSaveGState(context);
		CGPathRef clippath = [UIBezierPath bezierPathWithRect:progressRect].CGPath;
		CGContextAddPath(context, clippath);
		CGContextClip(context);

		[self.progressImage drawInRect:trackRect];
	}
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self setNeedsDisplay];
}

@end
