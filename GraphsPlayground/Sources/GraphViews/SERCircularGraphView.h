//
//  SERCircularGraphView.h
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SERCircularGraphView : UIView

@property (nonatomic, copy, readonly) NSArray *data;
@property (nonatomic, copy, readonly) NSNumber *minimumValue;
@property (nonatomic, copy, readonly) NSNumber *maximumValue;

@property (nonatomic, copy) NSArray *colors;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic) CGFloat lineDistance;
@property (nonatomic) CGFloat startAngleOffset;
@property (nonatomic) CGFloat padding;
@property (nonatomic) BOOL overshoot;

- (void)setData:(NSArray *)data minimumValue:(NSNumber *)minimumValue maximumValue:(NSNumber *)maximumValue;
- (void)animateIn;
- (void)animateOut;

@end
