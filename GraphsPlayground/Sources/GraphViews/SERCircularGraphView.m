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
@property (nonatomic, strong) CAShapeLayer *baseLineLayer;
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

@property (nonatomic) CGFloat legendLineWidth;

@end

// TODO make it work for negative values as well, normalize between -1.0 .. 1.0
// TODO WIP Legend, also animatable
// TODO the label overlapping resolution code can make the graph draw outside its view bounds

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
    self.overshoot        = YES;

    self.graphLayer  = [CALayer new];
    self.legendLayer = [CALayer new];
    [self.layer addSublayer:self.graphLayer];
    [self.layer addSublayer:self.legendLayer];

    
    self.graphDataLayers  = [NSMutableArray new];
    self.dataPoints       = [NSMutableArray new];
    self.legendLineLayers = [NSMutableArray new];
    self.legendTextLayers = [NSMutableArray new];
    
    // TODO setting this to a solid color might improve performance, test this later
    self.backgroundColor = [UIColor clearColor];
    
    self.config = @{
      kSERDefaultColor:   [UIColor grayColor],
      kSERLegendColor:    [UIColor lightGrayColor],
      kSERLegendFontName: @"HelveticaNeue",
      kSERLegendFontSize: @9.0,
    };

    self.legendLineWidth = 1;
  }
  return self;
}

// deferred data mangling until it's time to display so we can set all attributes in any order
- (void)layoutSubviews
{
  [super layoutSubviews];
  
  // TODO is this OK to call in layoutSubviews? Where else could we call it directly before displaying? seems to work fine for now

  // this depends on size of view, could be abstracted further out but that would not help
  self.dataPoints = [self dataPointsFromValues:self.values min:self.minimumValue max:self.maximumValue];

  [self buildGraph];
  [self buildLegend];
}

- (NSArray *)dataPointsFromValues:(NSArray *)values min:(NSNumber *)min max:(NSNumber *)max
{
  NSMutableArray *dataPoints = [NSMutableArray new];
  
  CGFloat maximumRadius = [self maximumRadius] - self.strokeWidth / 2.0;
  for(NSUInteger index = 0; index < [values count]; ++index)
  {
    // calculate radius to see if it fits
    CGFloat radius = [self radiusForIndex:index max:maximumRadius];
    
    if (radius < self.strokeWidth / 2)
    {
      // fail gracefully
      DLog(@"graph too small for number of data points and strokeWidth/lineDistance/... configuration");
      break;
    }
    
    double minValue = [min doubleValue];
    double maxValue = [max doubleValue];
    double dataPoint = ([self.values[index] doubleValue] - minValue) / (maxValue - minValue);

    [dataPoints addObject:@(dataPoint)];
  }
  
  return dataPoints;
}

- (void)buildGraph
{
  CGFloat screenScale = [UIScreen mainScreen].scale;
  CGFloat maximumRadius = [self maximumRadius] - self.strokeWidth / 2.0;

  for(NSUInteger i = 0; i < [self.dataPoints count]; ++i)
  {
    // round to pixel boundaries
    CGFloat radius = ([self radiusForIndex:i max:maximumRadius] * screenScale) / screenScale;

    CAShapeLayer *layer = [self layerForIndex:i withRadius:radius];
    layer.strokeEnd = [self.dataPoints[i] doubleValue];
  }
  
  if ([self.graphDataLayers count] > [self.dataPoints count])
  {
    // fade out unused layers
    for (NSUInteger i = [self.dataPoints count]; i < [self.graphDataLayers count]; ++i)
    {
      CAShapeLayer *layer = self.graphDataLayers[i];
      layer.strokeEnd = 0.0;
    }
  }
}

- (CGFloat)radiusForIndex:(NSUInteger)index max:(CGFloat)max
{
  return max - self.strokeWidth / 2 - index * (self.strokeWidth + self.lineDistance);
}

- (void)buildLegend
{
  [self buildLegendBaseLine];
  [self buildLegendLinesAndLabels];
}

- (void)buildLegendBaseLine
{
  if (!self.baseLineLayer)
  {
    CGFloat radius = [self maximumRadius];
    CGPoint center = [self graphCenter];
    CGPoint maxPoint = [self pointByRotatingVector:CGSizeMake(radius, 0) aroundPoint:center angle:self.startAngleOffset];
    
    self.baseLineLayer = [CAShapeLayer new];
    self.baseLineLayer.fillColor   = nil;
    self.baseLineLayer.strokeColor = [self.config[kSERLegendColor] CGColor];
    self.baseLineLayer.lineWidth   = self.legendLineWidth;
    
    CGMutablePathRef zeroPath = CGPathCreateMutable();
    CGPathMoveToPoint(zeroPath, NULL, center.x, center.y);
    CGPathAddLineToPoint(zeroPath, NULL, maxPoint.x, maxPoint.y);
    
    self.baseLineLayer.path = zeroPath;
    CGPathRelease(zeroPath);

    [self.legendLayer addSublayer:self.baseLineLayer];
  }
  
  self.baseLineLayer.hidden = [self.dataPoints count] == 0;
}

- (void)buildLegendLinesAndLabels
{
  CGFloat screenScale = [UIScreen mainScreen].scale;

  for (NSUInteger index = 0; index < [self.dataPoints count]; ++index)
  {
    NSString *text = [self.values[index] stringValue];
    
    CAShapeLayer *legendLineLayer = [self legendLineLayerForIndex:index];
    CATextLayer *legendTextLayer  = [self legendTextLayerForIndex:index];

    CGSize textSize = [self textSizeForText:text];
    textSize.width += 2.0 / screenScale;
    
    NSArray *frames = [[self.legendTextLayers subarrayWithRange:NSMakeRange(0, index)] valueForKey:@"frame"];
    
    CGPoint textAnchorPoint;
    BOOL isReverse = NO;
    CGPathRef path = [self createLegendLinePathForIndex:index textSize:textSize frames:frames textAnchorPoint:&textAnchorPoint isReverse:&isReverse];
    
    // this works smoothly to fade out, set new values and fade in
    [CATransaction begin];
    legendLineLayer.hidden = YES;
    legendLineLayer.path = path;
    legendLineLayer.hidden = NO;

    legendTextLayer.hidden = YES;
    legendTextLayer.string = text;
    legendTextLayer.frame = [self legendTextFrame:textAnchorPoint textSize:textSize isReverse:isReverse];
    legendTextLayer.hidden = NO;
    [CATransaction commit];

    CGPathRelease(path);
  }
  
  // hide and reset unused layers
  if ([self.legendLineLayers count] > [self.dataPoints count])
  {
    for (NSUInteger i = [self.dataPoints count]; i < [self.graphDataLayers count]; ++i)
    {
      CAShapeLayer *layer = self.legendLineLayers[i];
      layer.hidden = YES;
      layer.path = NULL;
    }
  }

  if ([self.legendTextLayers count] > [self.dataPoints count])
  {
    for (NSUInteger i = [self.dataPoints count]; i < [self.graphDataLayers count]; ++i)
    {
      CATextLayer *layer = self.legendTextLayers[i];
      layer.hidden = YES;
      layer.string = @"";
    }
  }
}

- (CGRect)legendTextFrame:(CGPoint)textAnchorPoint textSize:(CGSize)textSize isReverse:(BOOL)isReverse
{
  return CGRectMake(textAnchorPoint.x, textAnchorPoint.y - textSize.height, (isReverse ? -1.0 : 1.0) * textSize.width, textSize.height);
}

- (CGPathRef)createLegendLinePathForIndex:(NSUInteger)index textSize:(CGSize)textSize frames:(NSArray *)frames textAnchorPoint:(CGPoint *)textAnchorPoint isReverse:(BOOL *)isReverse
{
  CGPoint center    = [self graphCenter];
  CGFloat maxRadius = [self maximumRadius];

  double value = [self.dataPoints[index] doubleValue];
  CGFloat radius = [self radiusForIndex:index max:maxRadius];
  CGFloat angle = 2 * M_PI * value + self.startAngleOffset;
  
  // calculate shortest line for legend. this might be a bit too simple, it might still overlap with the graph in certain situations
  NSUInteger indexOfLargestOuterValue = index;
  double epsilon = 0.05;
  for (NSUInteger i = 0; i < index; ++i)
  {
    double outerValue = [self.dataPoints[i] doubleValue];
    if (outerValue + epsilon > value)
    {
      indexOfLargestOuterValue = i;
      break;
    }
  }
  
  CGFloat absoluteAngle = 2 * M_PI * value;
  // direction: to the left or right, depending on the side of the graph. (Sector 1 and 4 -> to the left)
  if (absoluteAngle <= M_PI_2 || absoluteAngle > 3 * M_PI_2)
  {
    *isReverse = YES;
  }

  CGFloat additionalRadius = 0;
  if (absoluteAngle >= 5 * M_PI_4 && absoluteAngle < 7 * M_PI_4)
    additionalRadius += textSize.height;

  CGPoint p0 = [self pointByRotatingVector:CGSizeMake(radius - self.strokeWidth, 0) aroundPoint:center angle:angle];
  CGPoint p1; // to be determined
  
  // label frames should not overlap
  NSUInteger iterations = 6;
  BOOL resolved = NO;
  while (!resolved && iterations > 0)
  {
    CGFloat outerRadius = [self radiusForIndex:indexOfLargestOuterValue max:maxRadius] + self.strokeWidth / 2; // was maxRadius
    // in case the legend is in the bottom quarter of the graph we need more space, otherwise we risk drawing the text into the graph
    
    p1 = [self pointByRotatingVector:CGSizeMake(outerRadius + additionalRadius, 0) aroundPoint:center angle:angle];

    CGRect textFrameCandidate = [self legendTextFrame:p1 textSize:textSize isReverse:*isReverse];
    
    resolved = YES;
    for (NSValue *frameValue in frames)
    {
      if (CGRectIntersectsRect(textFrameCandidate, [frameValue CGRectValue]))
      {
        resolved = NO;
        additionalRadius += textSize.height / 2; // Test this for a good value
        break;
      }
    }
    
    --iterations;
  }
  
  CGMutablePathRef path = CGPathCreateMutable();
  CGPathMoveToPoint(path, NULL, p0.x, p0.y);
  CGPathAddLineToPoint(path, NULL, p1.x, p1.y);
  
  // direction: to the left or right, depending on the side of the graph. (Sector 1 and 4 -> to the left)
  CGFloat textWidth = textSize.width;
  if (*isReverse)
  {
    textWidth *= -1;
  }
  
  CGPathAddLineToPoint(path, NULL, p1.x + textWidth, p1.y);
  
  *textAnchorPoint = p1;
  return path;
}

- (CAShapeLayer *)legendLineLayerForIndex:(NSUInteger)index
{
  CAShapeLayer *layer = nil;

  if ([self.legendLineLayers count] > index)
  {
    layer = self.legendLineLayers[index];
  }
  else
  {
    layer = [CAShapeLayer new];
    layer.fillColor   = nil;
    layer.strokeColor = [self.config[kSERLegendColor] CGColor];
    layer.lineWidth   = self.legendLineWidth;
    
    [self.legendLineLayers addObject:layer];
    [self.legendLayer addSublayer:layer];
  }
  
  return layer;
}

- (CATextLayer *)legendTextLayerForIndex:(NSUInteger)index
{
  CATextLayer *layer = nil;
  
  if ([self.legendTextLayers count] > index)
  {
    layer = self.legendTextLayers[index];
  }
  else
  {
    CGFloat screenScale = [UIScreen mainScreen].scale;
    
    NSString *fontName = self.config[kSERLegendFontName];
    CGFloat fontSize   = [self.config[kSERLegendFontSize] floatValue];
    UIColor *legendColor = self.config[kSERLegendColor];

    layer = [CATextLayer new];
    layer.font            = (__bridge CFTypeRef)fontName;
    layer.fontSize        = fontSize;
    layer.contentsScale   = screenScale;
    layer.foregroundColor = legendColor.CGColor;
    
    // remove implicit animations for frame and string: http://stackoverflow.com/questions/2244147/disabling-implicit-animations-in-calayer-setneedsdisplayinrect
    layer.actions = @{
      @"position": [NSNull null],
      @"contents": [NSNull null],
    };
    
    [self.legendTextLayers addObject:layer];
    [self.legendLayer addSublayer:layer];
  }
  return layer;
}

- (CGPoint)pointByRotatingVector:(CGSize)vector aroundPoint:(CGPoint)center angle:(CGFloat)theta
{
  CGFloat x = vector.width * cos(theta) - vector.height * sin(theta);
  CGFloat y = vector.width * sin(theta) + vector.height * cos(theta);
  
  return CGPointMake(center.x + x, center.y + y);
}

- (CGSize)textSizeForText:(NSString *)originalText
{
  NSString *text = originalText ?: @"Mylf0123456789";
  
  NSString *fontName = self.config[kSERLegendFontName];
  CGFloat fontSize   = [self.config[kSERLegendFontSize] floatValue];

  UIFont *font = [UIFont fontWithName:fontName size:fontSize];
  CGSize size = [text sizeWithAttributes:@{
    NSFontAttributeName: font
  }];
  
  if (!originalText)
    size.width = 0.0;
  
  return size;
}

- (CGFloat)maximumRadius
{
  CGFloat heightOfLegend = [self textSizeForText:nil].height;
  return fmin(self.frame.size.width, self.frame.size.height) / 2 - self.padding - heightOfLegend;
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
  UIColor *color = self.config[kSERDefaultColor];
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
  // preparations: hide legend except base line

  [CATransaction begin];
  [CATransaction setDisableActions: YES];
  
  for (CALayer *layer in self.legendLineLayers)
  {
    layer.hidden = YES;
  }

  for (CALayer *layer in self.legendTextLayers)
  {
    layer.hidden = YES;
  }

  [CATransaction commit];

  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    [self animateInLegend];
  }];
  
  // animate base line
  {
    CGFloat fromValue = 0.0;
    CGFloat toValue   = 1.0;
    
    self.baseLineLayer.opacity = toValue;

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(fromValue);
    animation.toValue   = @(toValue);
    animation.duration  = kInOutAnimationDuration; //  / 4.0;
    
    [self.baseLineLayer addAnimation:animation forKey:@"animateIn"];
  }
  
  // animate data
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

- (void)animateInLegend
{
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    for (CATextLayer *layer in self.legendTextLayers)
      layer.hidden = NO;
  }];
  
  CGFloat delay = 0.05;
  for (NSUInteger i = 0; i < [self.legendLineLayers count]; ++i)
  {
    CAShapeLayer *layer = self.legendLineLayers[i];
    CGFloat fromValue = 0.0;
    CGFloat toValue   = 1.0;
    
    layer.hidden    = NO;
    layer.strokeEnd = toValue;
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    animation.fromValue = @(fromValue);
    animation.toValue   = @(toValue);
    animation.beginTime = i * delay; // TODO does not seem to work to stagger the animations
    
    [layer addAnimation:animation forKey:@"animateIn"];
  }
  
  [CATransaction commit];
}

@end
