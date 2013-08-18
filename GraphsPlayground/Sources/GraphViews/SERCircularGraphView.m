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
@property (nonatomic, strong) CAShapeLayer *zeroLayer;
@property (nonatomic, strong) NSMutableArray *legendLineLayers;
@property (nonatomic, strong) NSMutableArray *legendTextLayers;

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
@property (nonatomic, strong) UIColor *legendColor;
@property (nonatomic) CGFloat legendLineWidth;

@end


// FIXME change double to CGFloat throughout
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

    
    self.graphDataLayers  = [NSMutableArray new];
    self.dataPoints       = [NSMutableArray new];
    self.legendLineLayers = [NSMutableArray new];
    self.legendTextLayers = [NSMutableArray new];
    
    self.backgroundColor = [UIColor clearColor];
    
    self.legendColor = [UIColor lightGrayColor];
    self.legendLineWidth = 1;
  }
  return self;
}

// deferred data mangling until it's time to display so we can set all attributes in any order
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  // TODO is this OK to call in layoutSubviews? Where else could we call it directly before displaying? seems to work fine for now
  [self buildGraph];
  [self buildLegend];
}

- (void)buildGraph
{
  CGFloat screenScale = [UIScreen mainScreen].scale;
  double maximumRadius = [self maximumRadius] - self.strokeWidth / 2.0;

  NSArray *oldDataPoints = [self.dataPoints copy];
  NSMutableArray *dataPoints = [NSMutableArray new];

  for(NSUInteger i = 0; i < [self.values count]; ++i)
  {
    CGFloat radius = [self radiusForIndex:i max:maximumRadius];
    
    if (radius < self.strokeWidth / 2)
    {
      // fail gracefully
      DLog(@"graph too small for number of data points and strokeWidth/lineDistance/... configuration");
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

- (double)radiusForIndex:(NSUInteger)index max:(double)max
{
  return max - self.strokeWidth / 2 - index * (self.strokeWidth + self.lineDistance);
}

- (void)buildLegend
{
  [self buildLegendZero];
  [self buildLegend2];
}

- (void)buildLegendZero
{
  if (!self.zeroLayer)
  {
    CGFloat radius = [self maximumRadius];
    CGPoint center = [self graphCenter];
    CGPoint maxPoint = [self pointByRotatingVector:CGSizeMake(radius, 0) aroundPoint:center angle:self.startAngleOffset];
    
    self.zeroLayer = [CAShapeLayer new];
    self.zeroLayer.fillColor   = nil;
    self.zeroLayer.strokeColor = self.legendColor.CGColor;
    self.zeroLayer.lineWidth   = self.legendLineWidth;
    
    CGMutablePathRef zeroPath = CGPathCreateMutable();
    CGPathMoveToPoint(zeroPath, NULL, center.x, center.y);
    CGPathAddLineToPoint(zeroPath, NULL, maxPoint.x, maxPoint.y);
    
    self.zeroLayer.path = zeroPath;
    CGPathRelease(zeroPath);

    [self.legendLayer addSublayer:self.zeroLayer];
  }
  
  // always animate
  CGFloat fromValue = self.zeroLayer.opacity;
  CGFloat toValue   = [self.values count] > 0 ? 1.0 : 0.0;
  
  self.zeroLayer.opacity = toValue;
  
  CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
  animation.fromValue = @(fromValue);
  animation.toValue   = @(toValue);
  animation.duration  = kChangeAnimationDuration;
  
  [self.zeroLayer addAnimation:animation forKey:@"opacity"];
}

- (void)buildLegend2
{
  if ([self.dataPoints count] == 0)
    return;

  CGPoint center = [self graphCenter];
  double maxRadius = [self maximumRadius];
  
  for (NSUInteger index = 0; index < [self.dataPoints count]; ++index)
  {
    CAShapeLayer *legendLineLayer = nil;
    if ([self.legendLineLayers count] > index)
    {
      legendLineLayer = self.legendLineLayers[index];
    }
    else
    {
      legendLineLayer = [CAShapeLayer new];
      legendLineLayer.fillColor   = nil;
      legendLineLayer.strokeColor = self.legendColor.CGColor;
      legendLineLayer.lineWidth   = self.legendLineWidth;

      [self.legendLineLayers addObject:legendLineLayer];
      [self.legendLayer addSublayer:legendLineLayer];
    }
    legendLineLayer.hidden = NO;

    CATextLayer *legendTextLayer = nil;
    if ([self.legendTextLayers count] > index)
    {
      legendTextLayer = self.legendTextLayers[index];
    }
    else
    {
      legendTextLayer = [CATextLayer new];
      legendTextLayer.foregroundColor = self.legendColor.CGColor;
      CGFontRef font = CGFontCreateWithFontName((CFStringRef)@"HelveticaNeue"); // TODO font
      legendTextLayer.font = font;
      legendTextLayer.fontSize = 9.0;
      CGFontRelease(font);
      legendTextLayer.contentsScale = [UIScreen mainScreen].scale;
      
      [self.legendTextLayers addObject:legendTextLayer];
      [self.legendLayer addSublayer:legendTextLayer];
    }
    legendTextLayer.hidden = NO;
    legendTextLayer.string = [self.values[index] stringValue];
    
    double a = [self.dataPoints[index] doubleValue];
    CGFloat radius = [self radiusForIndex:index max:maxRadius];
    double angle = 2 * M_PI * a + self.startAngleOffset;
    
    CGFloat textHeight = 12; // TODO text height
    CGFloat absoluteAngle = 2 * M_PI * a;
    CGFloat additionalRadius = 0;
    
    // FIXME text layers have implicit frame animations
    
    // FIXME overlapping legend labels when data points too close
    
    // TODO shortest length of legend lines, instead of always maximum length. if there is no part of the graph in the way (all dataPoints with smaller index have smaller values) then make the legend line short. BEWARE: it might still overlap when drawn to the left in 1st quadrant or to the right in 3rd quadrant.

    // in case the legend is in the bottom quarter of the graph we need more space, otherwise we risk drawing the text into the graph
    if (absoluteAngle >= 5 * M_PI_4 && absoluteAngle < 7 * M_PI_4)
      additionalRadius += textHeight;
    
    CGPoint p0 = [self pointByRotatingVector:CGSizeMake(radius - self.strokeWidth, 0) aroundPoint:center angle:angle];
    CGPoint p1 = [self pointByRotatingVector:CGSizeMake(maxRadius + additionalRadius, 0) aroundPoint:center angle:angle];
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, p0.x, p0.y);
    CGPathAddLineToPoint(path, NULL, p1.x, p1.y);
    
    CGFloat offset = 15; // TODO length of legend lines
    if (absoluteAngle <= M_PI_2 || absoluteAngle > 3 * M_PI_2)
      offset *= -1;
    
    CGPathAddLineToPoint(path, NULL, p1.x + offset, p1.y);

    legendTextLayer.frame = CGRectMake(p1.x, p1.y - textHeight, offset, textHeight);

    legendLineLayer.path = path;
    CGPathRelease(path);
  }
  
  if ([self.legendLineLayers count] > [self.dataPoints count])
  {
    for (NSUInteger i = [self.dataPoints count]; i < [self.graphDataLayers count]; ++i)
    {
      CALayer *layer = self.legendLineLayers[i];
      layer.hidden = YES;
    }
  }

  if ([self.legendTextLayers count] > [self.dataPoints count])
  {
    for (NSUInteger i = [self.dataPoints count]; i < [self.graphDataLayers count]; ++i)
    {
      CALayer *layer = self.legendTextLayers[i];
      layer.hidden = YES;
    }
  }
}

- (CGPoint)pointByRotatingVector:(CGSize)vector aroundPoint:(CGPoint)center angle:(double)theta
{
  CGFloat x = vector.width * cos(theta) - vector.height * sin(theta);
  CGFloat y = vector.width * sin(theta) + vector.height * cos(theta);
  
  return CGPointMake(center.x + x, center.y + y);
}

- (double)maximumRadius
{
  return fmin(self.frame.size.width, self.frame.size.height) / 2 - self.padding;
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
  CGPoint center = [self graphCenter];
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

- (CGPoint)graphCenter
{
  return CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
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
  
  BOOL shouldShowLegend = YES;
  if (shouldShowLegend)
  {
    CGFloat fromValue = 0.0;
    CGFloat toValue   = 1.0;
    
    self.zeroLayer.opacity = toValue;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue   = @(toValue);
    animation.duration  = kInOutAnimationDuration; //  / 4.0;
    
    [self.zeroLayer addAnimation:animation forKey:@"animateIn"];
  }
  
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
