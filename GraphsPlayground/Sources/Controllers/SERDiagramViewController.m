//
//  SERDiagramViewController.m
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import "SERDiagramViewController.h"
#import "UIColor+SER.h"
#import "SERCircularGraphView.h"


@interface SERDiagramViewController ()

@property (nonatomic, strong) SERCircularGraphView *circularGraphView;
@property (nonatomic, strong) UIButton *button1;
@property (nonatomic, strong) UIButton *button2;
@property (nonatomic, strong) UIButton *button3;

@end

@implementation SERDiagramViewController

- (void)loadView
{
  self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)];
  self.view.backgroundColor = [UIColor colorFromHexString:@"#F2E4DA"];
  
  CGFloat width  = 320;
  CGFloat height = 200;
  self.circularGraphView = [[SERCircularGraphView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.view.frame) - width / 2, 100, width, height)];

  [self.circularGraphView setData:[self data1] minimumValue:@0 maximumValue:@100];
  self.circularGraphView.colors = [self colors];
  self.circularGraphView.strokeWidth = 8;
  self.circularGraphView.lineDistance = 5;

  self.circularGraphView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
  
  [self.view addSubview:self.circularGraphView];
  
  self.button1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.button1 setTitle:@"data set 1" forState:UIControlStateNormal];
  [self.button1 addTarget:self action:@selector(button1Pressed:) forControlEvents:UIControlEventTouchUpInside];

  self.button2 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.button2 setTitle:@"data set 2" forState:UIControlStateNormal];
  [self.button2 addTarget:self action:@selector(button2Pressed:) forControlEvents:UIControlEventTouchUpInside];

  self.button3 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [self.button3 setTitle:@"data set 3" forState:UIControlStateNormal];
  [self.button3 addTarget:self action:@selector(button3Pressed:) forControlEvents:UIControlEventTouchUpInside];
  
  self.button1.frame = CGRectMake( 30, 370, 80, 44);
  self.button2.frame = CGRectMake(120, 370, 80, 44);
  self.button3.frame = CGRectMake(210, 370, 80, 44);
  
  self.button1.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
  self.button2.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
  self.button3.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
  
  [self.view addSubview:self.button1];
  [self.view addSubview:self.button2];
  [self.view addSubview:self.button3];
  
  self.button1.selected = YES;

  UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
  [clearButton setTitle:@"clear" forState:UIControlStateNormal];
  [clearButton addTarget:self action:@selector(clearButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
  clearButton.frame = CGRectMake(0, 420, 320, 44);
  clearButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
  
  [self.view addSubview:clearButton];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.title = @"Animated Graph";
  self.view.tintColor = [UIColor colorFromHexString:@"#411D00"];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.circularGraphView animateIn];
}

- (NSArray *)data1
{
  return @[
    @99,
    @75,
    @50,
    @32,
    @20,
    @12,
  ];
}

- (NSArray *)data2
{
  return @[
    @3,
    @22,
    @37,
    @40,
    @65,
    @66,
    @80,
  ];
}

- (NSArray *)data3
{
  return @[
    @10,
    @20,
    @30,
  ];
}

- (NSArray *)colors
{
  return @[
    [UIColor colorFromHexString:@"#FF6F00"],
    [UIColor colorFromHexString:@"#FFAE00"],
    [UIColor colorFromHexString:@"#F10026"],
    [UIColor colorFromHexString:@"#009D91"],
    [UIColor colorFromHexString:@"#3BDA00"],
    [UIColor colorFromHexString:@"#133AAC"],
  ];
}

#pragma mark Actions

- (void)button1Pressed:(UIButton *)sender
{
  [self.circularGraphView setData:[self data1] minimumValue:@0 maximumValue:@100];
  [@[self.button1, self.button2, self.button3] setValue:@NO forKey:@"selected"];
  sender.selected = YES;
}

- (void)button2Pressed:(UIButton *)sender
{
  [self.circularGraphView setData:[self data2] minimumValue:@0 maximumValue:@100];
  [@[self.button1, self.button2, self.button3] setValue:@NO forKey:@"selected"];
  sender.selected = YES;
}

- (void)button3Pressed:(UIButton *)sender
{
  [self.circularGraphView setData:[self data3] minimumValue:@0 maximumValue:@100];
  [@[self.button1, self.button2, self.button3] setValue:@NO forKey:@"selected"];
  sender.selected = YES;
}

- (void)clearButtonPressed:(UIButton *)sender
{
  [self.circularGraphView setData:nil minimumValue:0 maximumValue:0];
  [@[self.button1, self.button2, self.button3] setValue:@NO forKey:@"selected"];
}


@end
