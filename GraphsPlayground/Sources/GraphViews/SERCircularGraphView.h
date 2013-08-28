//
//  SERCircularGraphView.h
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString * const kSERLegendColor    = @"LegendColor";
static NSString * const kSERDefaultColor   = @"DefaultColor";
static NSString * const kSERLegendFontName = @"LegendFontName";
static NSString * const kSERLegendFontSize = @"LegendFontSize";

@interface SERCircularGraphView : UIView

@property (nonatomic, copy, readonly) NSArray *values;
@property (nonatomic, copy, readonly) NSNumber *minimumValue;
@property (nonatomic, copy, readonly) NSNumber *maximumValue;

@property (nonatomic, copy) NSArray *colors;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic) CGFloat lineDistance;
@property (nonatomic) CGFloat startAngleOffset;
@property (nonatomic) CGFloat padding;
@property (nonatomic) BOOL overshoot;

@property (nonatomic, copy) NSDictionary *config;

- (void)setData:(NSArray *)data minimumValue:(NSNumber *)minimumValue maximumValue:(NSNumber *)maximumValue;
- (void)animateIn;

@end
