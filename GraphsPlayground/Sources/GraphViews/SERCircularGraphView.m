//
//  SERCircularGraphView.m
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import "SERCircularGraphView.h"

const double kOvershootFactor         = 1.1;
const double kInOutAnimationDuration  = 1.0;
const double kChangeAnimationDuration = 0.25;


@interface SERCircularGraphView ()

/** container for legend layers **/
@property (nonatomic, strong) CALayer *legendLayer;

/** container for data layers **/
@property (nonatomic, strong) CALayer *graphLayer;
@property (nonatomic, strong) NSMutableArray *graphDataLayers;

/** normalized data **/
@property (nonatomic, strong) NSArray *dataPoints;

/** raw data **/
@property (nonatomic, copy, readwrite) NSArray *values;
@property (nonatomic, copy, readwrite) NSNumber *minimumValue;
@property (nonatomic, copy, readwrite) NSNumber *maximumValue;

@property (nonatomic, strong) UIColor *defaultColor;

@end


// TODO make it work for negative values as well, normalize between -1.0 .. 1.0
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
    self.padding          = 0.0;
    self.defaultColor     = [UIColor grayColor];
    self.overshoot        = YES;

    self.graphLayer  = [CALayer new];
    self.legendLayer = [CALayer new];
    [self.layer addSublayer:self.graphLayer];
    [self.layer addSublayer:self.legendLayer];

    
    self.graphDataLayers = [NSMutableArray new];
    self.dataPoints      = [NSMutableArray new];
    
    self.backgroundColor = [UIColor clearColor];
  }
  return self;
}

// deferred data mangling until it's time to display so we can set all attributes in any order
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  // TODO is this OK to call in layoutSubviews? Where else could we call it directly before displaying? seems to work fine for now
  [self build];
}

- (void)build
{
  CGFloat screenScale = [UIScreen mainScreen].scale;
  double maximumRadius = fmin(self.frame.size.width, self.frame.size.height) / 2 - self.padding - self.strokeWidth / 2.0;

  NSArray *oldDataPoints = [self.dataPoints copy];
  NSMutableArray *dataPoints = [NSMutableArray new];

  for(NSUInteger i = 0; i < [self.values count]; ++i)
  {
    CGFloat radius = maximumRadius - self.strokeWidth / 2 - i * (self.strokeWidth + self.lineDistance);
    BOOL sizeOK = radius >= self.strokeWidth / 2;
    NSAssert(sizeOK, @"graph too small for number of data points and strokeWidth/lineDistance/... configuration");
    
    if (!sizeOK)
    {
      // fail gracefully
      break;
    }
    
    // round to pixel boundaries
    radius = round(radius * screenScale) / screenScale;

    double dataPoint = [self dataPointForValueAtIndex:i];
    [dataPoints addObject:@(dataPoint)];

    CAShapeLayer *layer = [self layerForIndex:i withRadius:radius];
    layer.strokeEnd = dataPoint;
    
    if ([oldDataPoints count] > i)
    {
      [self animateLayer:layer fromValue:oldDataPoints[i] toValue:@(dataPoint)];
    }
  }
  
  self.dataPoints = dataPoints;
  
  if ([self.graphDataLayers count] > [self.values count])
  {
    // fade out unused layers
    for (NSUInteger i = [self.values count]; i < [self.graphDataLayers count]; ++i)
    {
      CAShapeLayer *layer = self.graphDataLayers[i];
      CGFloat fromValue = layer.strokeEnd;
      CGFloat toValue   = 0.0;

      layer.strokeEnd = toValue;

      CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
      animation.fromValue = @(fromValue);
      animation.toValue   = @(toValue);
      animation.duration  = kChangeAnimationDuration;
      
      [layer addAnimation:animation forKey:@"unused"];
    }
  }
}

// normalizes between 0.0 and 1.0
- (double)dataPointForValueAtIndex:(NSUInteger)index
{
  double min = [self.minimumValue doubleValue];
  double max = [self.maximumValue doubleValue];

  return ([self.values[index] doubleValue] - min) / (max - min);
}

- (void)checkValuesWithMinimum:(double *)minimumValue maximum:(double *)maximumValue
{
  for(NSNumber *valueObject in self.values)
  {
    BOOL isResponding = [valueObject respondsToSelector:@selector(doubleValue)];
    NSAssert(isResponding, @"NSNumber instances expected in dataset");
    
    if (!isResponding)
    {
      // fail gracefully
      continue;
    }
    
    double value = [valueObject doubleValue];
    
    // TODO not sure about these auto adjustments of min and max, might be nice to have one line go in the opposite direction?
    NSAssert(*minimumValue <= value, @"given minimumValue not minimum");
    NSAssert(*maximumValue >= value, @"given maximumValue not maximum");
    
    if (value < *minimumValue)
      *minimumValue = value;
    if (value > *maximumValue)
      *maximumValue = value;
  }
}

- (void)animateLayer:(CAShapeLayer *)layer fromValue:(NSNumber *)fromValue toValue:(NSNumber *)toValue
{
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
  animation.fromValue      = fromValue;
  animation.toValue        = toValue;
  animation.duration       = kChangeAnimationDuration;
  animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

  [layer addAnimation:animation forKey:@"changeAnimation"];
}

// TODO radius can change when view size changes, layers/paths need to be invalidated when that happens. This could be while rotating the device, so this should be fast.
- (CAShapeLayer *)layerForIndex:(NSUInteger)index withRadius:(CGFloat)radius
{
  // create layers and paths if needed or reuse existing ones
  if ([self.graphDataLayers count] > index)
    return self.graphDataLayers[index];

  CAShapeLayer *layer = [CAShapeLayer new];
  CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
  UIBezierPath *bezierPath = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:self.startAngleOffset endAngle:2 * M_PI + self.startAngleOffset clockwise:YES];
  layer.path = bezierPath.CGPath;
  
  // TODO configuration changes should be applicable live, override setters and change layer properties
  UIColor *color = self.defaultColor;
  if ([self.colors count] > index)
    color = self.colors[index];
  
  layer.fillColor   = nil;
  layer.strokeColor = color.CGColor;
  layer.lineWidth   = self.strokeWidth;
  
  [self.graphLayer addSublayer:layer];
  [self.graphDataLayers addObject:layer];

  return layer;
}

- (void)setData:(NSArray *)data minimumValue:(NSNumber *)minimumValue maximumValue:(NSNumber *)maximumValue;
{
  self.values = data;
  
  double min = [minimumValue doubleValue];
  double max = [maximumValue doubleValue];

  [self checkValuesWithMinimum:&min maximum:&max];

  self.minimumValue = @(min);
  self.maximumValue = @(max);
  
  [self setNeedsLayout];
}

- (void)animateIn
{
  [CATransaction begin];
  for (NSUInteger i = 0; i < [self.dataPoints count]; ++i)
  {
    double dataPoint = [self.dataPoints[i] doubleValue];
    
    NSAssert([self.graphDataLayers count] > i, @"no layer for data point index");
    CAShapeLayer *layer = self.graphDataLayers[i];
    
    CGFloat fromValue = 0.0;
    CGFloat toValue   = dataPoint;

    CGFloat maxValue  = toValue;
    if (self.overshoot)
      maxValue = fmin(1.0, toValue * kOvershootFactor);
    
    layer.strokeEnd = toValue;
    
    CAAnimation *animation = nil;
    if (self.overshoot)
    {
      CAKeyframeAnimation *keyframeAnimation = [CAKeyframeAnimation animationWithKeyPath:@"strokeEnd"];
      keyframeAnimation.values   = @[@(fromValue), @(maxValue), @(toValue)];
      keyframeAnimation.keyTimes = @[@0.0, @0.8, @1.0];
      keyframeAnimation.timingFunctions = @[
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut],
        [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
      ];
      
      animation = keyframeAnimation;
    }
    else
    {
      CABasicAnimation *basicAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
      basicAnimation.fromValue = @(fromValue);
      basicAnimation.toValue   = @(toValue);
      
      animation = basicAnimation;
    }

    animation.duration = kInOutAnimationDuration;
    [layer addAnimation:animation forKey:@"animateIn"];
  }
  [CATransaction commit];
}

@end
