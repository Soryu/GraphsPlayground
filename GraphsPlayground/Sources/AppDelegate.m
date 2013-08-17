//
//  AppDelegate.m
//  digramtest
//
//  Created by Stanley Rost on 17.08.13.
//  Copyright (c) 2013 Stanley Rost. All rights reserved.
//

#import "AppDelegate.h"
#import "SERDiagramViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  
  SERDiagramViewController *diagramVC = [SERDiagramViewController new];
  UINavigationController *navVC = [[UINavigationController alloc] initWithRootViewController:diagramVC];
  self.window.rootViewController = navVC;
  
  self.window.backgroundColor = [UIColor whiteColor];
  [self.window makeKeyAndVisible];
  return YES;
}

@end
