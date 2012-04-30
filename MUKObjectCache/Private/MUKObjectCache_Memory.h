//
//  MUKObjectCache_Memory.h
//  MUKObjectCache
//
//  Created by Marco Muccinelli on 30/04/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MUKObjectCache.h"

@interface MUKObjectCache ()
/*
 Register/unregister from default notification center
 */
- (void)registerToMemoryWarningNotifications_;
- (void)unregisterFromMemoryWarningNotifications_;
/*
 Callback
 */
- (void)memoryWarningNotification_:(NSNotification *)notification;
@end
