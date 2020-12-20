//
//  TSLAppDelegate.h
//  ReadWrite
//
//  Created by Brian Painter on 05/07/2013.
//  Copyright (c) 2013 Technology Solutions (UK) Ltd. All rights reserved.
//

#import <TSLAsciiCommands/TSLAsciiCommands.h>
#import <UIKit/UIKit.h>

@interface TSLAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

/// The commander to use for communicating with the reader accessory
@property (nonatomic, readonly) TSLAsciiCommander *commander;

@end
