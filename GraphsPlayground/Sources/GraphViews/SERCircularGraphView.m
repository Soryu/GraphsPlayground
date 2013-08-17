//
//  SERCircularGraphView.m
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import "SERCircularGraphView.h"

const double kOvershootFactor   = 1.1;
const double kInOutAnimationDuration  = 1.0;
const double kChangeAnimationDuration = 0.25;

@interface SERCircularGraphView ()

@property (nonatomic, strong) CAShapeLayer *legendLayer;
@property (nonatomic, strong) NSMutableArray *graphLayers;
@property (nonatomic, strong) UIColor *defaultColor;

@property (nonatomic, copy, readwrite) NSArray *data;
@property (nonatomic, copy, readwrite) NSNumber *minimumValue;
@property (nonatomic, copy, readwrite) NSNumber *maximumValue;

@property (nonatomic) BOOL isShowing;

@end

// FIXME animating between paths is broken, different number of control points. Easy solution: Always use full circles and set & animate `strokeEnd`
// TODO Legend, also animatable

@implementation SERCircularGraphView

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    self.strokeWidth      = 4.0;
    self.lineDistance     = 3.0;
    self.startAngleOffset = -M_PI;
    self.padding          = self.strokeWidth / 2.0;
    self.defaultColor     = [UIColor blackColor];
    self.overshoot        = YES;

    self.graphLayers = [NSMutableArray new];
    
    self.backgroundColor = [UIColor clearColor];
  }
  return self;
}

// deferred data mangling until it's time to display so we can set alll attributes in any order
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  // TODO is this OK to call in layoutSubviews? Where else could we call it directly before displaying? seems to work fine for now
  [self build];
}

- (void)build
{
  DLog(@".");
  
  double minimumValue = [self.minimumValue doubleValue];
  double maximumValue = [self.maximumValue doubleValue];
  for(NSNumber *dataPoint in self.data)
  {
    BOOL isResponding = [dataPoint respondsToSelector:@selector(doubleValue)];
    NSAssert(isResponding, @"NSNumber instances expected in dataset");
    
    if (!isResponding)
    {
      // fail gracefully
      continue;
    }
    
    double value = [dataPoint doubleValue];
    
    // TODO not sure about these auto adjustments of min and max, might be nice to have one line go in the opposite direction?
    NSAssert(minimumValue <= value, @"given minimumValue not minimum");
    NSAssert(maximumValue >= value, @"given maximumValue not maximum");
    
    if (value < minimumValue)
      minimumValue = value;
    if (value > maximumValue)
      maximumValue = value;
  }
  
  CGFloat screenScale = [UIScreen mainScreen].scale;
  double maximumRadius = fmin(self.frame.size.width, self.frame.size.height) / 2 - self.padding;
  
  double range = maximumValue - minimumValue;
  CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
  
  for(NSUInteger i = 0; i < [self.data count]; ++i)
  {
    double value = [self.data[i] doubleValue];
    
    if (self.overshoot)
      value *= kOvershootFactor;

    double relativeValue = value = (value - minimumValue) / range;
    
    CGFloat radius = maximumRadius - self.strokeWidth / 2 - i * (self.strokeWidth + self.lineDistance);
    
    BOOL sizeOK = radius >= self.strokeWidth / 2;
    NSAssert(sizeOK, @"graph too small for number of data points and strokeWidth/lineDistance/... configuration");
    
    if (!sizeOK)
    {
      // fail gracefully
      break;
    }
    
    radius = round(radius * screenScale) / screenScale;
    
    // always create new, existing ones are not mutable
    UIBezierPath *bezierPath = [UIBezierPath
      bezierPathWithArcCenter:center
      radius:radius
      startAngle:self.startAngleOffset
      endAngle:2 * M_PI * relativeValue + self.startAngleOffset
      clockwise:YES];
    
    CAShapeLayer *layer = nil;
    if ([self.graphLayers count] > i)
    {
      layer = self.graphLayers[i];
    }
    else
    {
      layer = [CAShapeLayer new];
      [self.graphLayers addObject:layer];
    }
    
    UIColor *color = self.defaultColor;
    if ([self.colors count] > i)
      color = self.colors[i];

    layer.fillColor   = nil;
    layer.strokeColor = color.CGColor;
    layer.lineWidth   = self.strokeWidth;
    
    if (!layer.path)
    {
      layer.path = bezierPath.CGPath;
    }
    else if (self.isShowing)
    {
      CAAnimation *animation = nil;
      if (layer.opacity == 0.0)
      {
        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        opacityAnimation.fromValue = @0.0;
        opacityAnimation.toValue   = @1.0;
        opacityAnimation.duration  = kChangeAnimationDuration;
        
        animation = opacityAnimation;
      }
      else
      {
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
        pathAnimation.fromValue = (id)layer.path;
        pathAnimation.toValue   = (id)bezierPath.CGPath;
        pathAnimation.duration  = kChangeAnimationDuration;
        pathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        animation = pathAnimation;
      }
      
      layer.path = bezierPath.CGPath;
      [layer addAnimation:animation forKey:@"path"];
    }

    layer.opacity = self.isShowing ? 1.0 : 0.0;

    if (!layer.superlayer)
      [self.layer addSublayer:layer];
  }
  
  if ([self.graphLayers count] > [self.data count])
  {
    // NOTE fading out unused layers, but not removing them. overhead should be neglegible
    
    for (NSUInteger i = [self.data count]; i < [self.graphLayers count]; ++i)
    {
      CALayer *layer = self.graphLayers[i];
      
      CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
      opacityAnimation.fromValue = @(layer.opacity);
      opacityAnimation.toValue   = @0.0;
      opacityAnimation.duration  = kChangeAnimationDuration;
      
      layer.opacity = 0.0;
      [layer addAnimation:opacityAnimation forKey:@"opacity"];
    }
  }
}

- (void)setData:(NSArray *)data minimumValue:(NSNumber *)minimumValue maximumValue:(NSNumber *)maximumValue;
{
  self.data = data;
  self.minimumValue = minimumValue;
  self.maximumValue = maximumValue;
  
  [self setNeedsLayout];
  
  // TODO not sure about animating automatically
  if (!self.isShowing)
    [self animateIn];
}

- (void)animateIn
{
  self.isShowing = YES;
  
  [CATransaction begin];
  for (CAShapeLayer *layer in self.graphLayers)
  {
    CGFloat endValue = 1.0;
    if (self.overshoot)
      endValue = 1.0 / kOvershootFactor;

    layer.strokeEnd = endValue;
    
    CAAnimation *animation = nil;
    if (self.overshoot)
    {
      CAKeyframeAnimation *keyframeAnimation = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
      keyframeAnimation.values   = @[@0.0, @1.0, @(endValue)];
      keyframeAnimation.keyTimes   = @[@0.0, @0.8, @1.0];
      keyframeAnimation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
      ];
      
      animation = keyframeAnimation;
    }
    else
    {
      CABasicAnimation *basicAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
      basicAnimation.fromValue = @0.0;
      basicAnimation.toValue   = @1.0;
      
      animation = basicAnimation;
    }

    animation.duration = kInOutAnimationDuration;
    [layer addAnimation:animation forKey:@"strokeEnd"];
    
    layer.opacity = 1.0;
  }
  [CATransaction commit];
}

- (void)animateOut
{
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    [self.graphLayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [self.graphLayers removeAllObjects];
  }];
  
  for (CAShapeLayer *layer in self.graphLayers)
  {
    CGFloat endValue = 0.0;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    animation.fromValue = @(layer.strokeEnd);
    animation.toValue   = @(endValue);
    animation.duration  = kInOutAnimationDuration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    [layer addAnimation:animation forKey:@"strokeEnd"];
    layer.strokeEnd = endValue;
  }
  [CATransaction commit];
  
  self.isShowing = NO;
}

@end
