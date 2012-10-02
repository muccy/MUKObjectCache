// Copyright (c) 2012, Marco Muccinelli
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// * Neither the name of the <organization> nor the
// names of its contributors may be used to endorse or promote products
// derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "MUKObjectCacheTests.h"
#import "MUKObjectCache.h"
#import <MUKToolkit/MUKToolkit.h>
#import <UIKit/UIKit.h>

@interface MUKObjectCacheTests ()
@property (nonatomic, strong) MUKObjectCache *cache;
@end

@implementation MUKObjectCacheTests
@synthesize cache;

- (void)setUp {
    [super setUp];
    
    // Set-up code here.
    self.cache = [[MUKObjectCache alloc] init];
}

- (void)tearDown {
    // Tear-down code here.
    self.cache = nil;
    
    [super tearDown];
}

- (void)testMemoryCache {
    NSDictionary *testDict = @{@"key0": @"value0", @"key1": @"value1"};
    MUKObjectCacheLocation theLocation = MUKObjectCacheLocationMemory;
    
    __block BOOL handlerCalled = NO;
    NSString *key = @"key0";
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
    {
        handlerCalled = YES;
        STAssertNil(object, @"Object not cached");
        STAssertEquals(location, theLocation, @"Object not cached");
    }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache saveObject:testDict[key] forKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
    {
        handlerCalled = YES;
        STAssertTrue(success, @"Object always saved in memory");
        STAssertNil(error, nil);
        STAssertEquals(location, theLocation, nil);
    }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertEqualObjects(testDict[key], object, @"Object found");
         STAssertEquals(location, theLocation, nil);
     }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key1";
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertNil(object, @"Object not found");
         STAssertEquals(location, theLocation, @"Object not found");
     }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
    {
        handlerCalled = YES;
        STAssertFalse(exists, @"Object doesn't exist");
        STAssertEquals(location, theLocation, nil);
    }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key0";
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(exists, @"Object exists");
         STAssertEquals(location, theLocation, nil);
     }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key1";
    [self.cache removeObjectForKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
    {
        handlerCalled = YES;
        STAssertTrue(success, @"Removal from memory is always successful");
        STAssertNil(error, nil);
        STAssertEquals(location, theLocation, nil);
    }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key0";
    [self.cache removeObjectForKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(success, @"Removal from memory is always successful");
         STAssertNil(error, nil);
         STAssertEquals(location, theLocation, nil);
     }];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertFalse(exists, @"Object doesn't exist anymore");
         STAssertEquals(location, theLocation, nil);
     }];
    STAssertTrue(handlerCalled, nil);
}

- (void)testFileCache {
    NSDictionary *testDict = @{@"key0": @"value0", @"key1": @"value1"};
    MUKObjectCacheLocation theLocation = MUKObjectCacheLocationFile;
    NSURL *containerURL = [[MUK URLForCachesDirectory] URLByAppendingPathComponent:@"Test"];
    
    self.cache.fileCacheURLHandler = ^(id key) {
        return [MUKObjectCache standardFileCacheURLForStringKey:key containerURL:containerURL];
    };
    
    self.cache.fileCachedDataTransformer = ^(id key, NSData *data) {
        NSString *string;
        
        if ([data length] == 0) {
            string = nil;
        }
        else {
            string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        
        return string;
    };
    
    self.cache.fileCachedObjectTransformer = ^(id key, id object) {
        NSData *data;
        
        if ([object isKindOfClass:[NSString class]]) {
            data = [object dataUsingEncoding:NSUTF8StringEncoding];
        }
        else {
            data = nil;
        }
        
        return data;
    };
    
    __block BOOL handlerCalled = NO;
    NSString *key = @"key0";
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertNil(object, @"Object not cached");
         STAssertEquals(location, theLocation, @"Object not cached");
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache saveObject:testDict[key] forKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(success, @"Object should be saved to file");
         STAssertNil(error, nil);
         NSFileManager *fm = [[NSFileManager alloc] init];
         STAssertTrue([fm fileExistsAtPath:[[self.cache fileCacheURLForKey:key] path]], @"File created");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache saveObject:testDict[key] forKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(success, @"File overwritten");
         STAssertNil(error, nil);
         NSFileManager *fm = [[NSFileManager alloc] init];
         STAssertTrue([fm fileExistsAtPath:[[self.cache fileCacheURLForKey:key] path]], @"File overwritten");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertEqualObjects(testDict[key], object, @"Object found");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key1";
    [self.cache loadObjectForKey:key locations:theLocation completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertNil(object, @"Object not found");
         STAssertEquals(location, theLocation, @"Object not found");
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertFalse(exists, @"Object doesn't exist");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key0";
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(exists, @"Object exists");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key1";
    [self.cache removeObjectForKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(success, nil);
         STAssertNil(error, @"Error should be nil:\n%@", error);
         
         NSFileManager *fm = [[NSFileManager alloc] init];
         STAssertFalse([fm fileExistsAtPath:[[self.cache fileCacheURLForKey:key] path]], @"File does not exist");
         
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    key = @"key0";
    [self.cache removeObjectForKey:key locations:theLocation completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertTrue(success, nil);
         STAssertNil(error, @"Error should be nil:\n%@", error);
         
         NSFileManager *fm = [[NSFileManager alloc] init];
         STAssertFalse([fm fileExistsAtPath:[[self.cache fileCacheURLForKey:key] path]], @"File removed");
         
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    handlerCalled = NO;
    [self.cache existsObjectForKey:key locations:theLocation completionHandler:^(BOOL exists, MUKObjectCacheLocation location) 
     {
         handlerCalled = YES;
         STAssertFalse(exists, @"Object doesn't exist anymore");
         STAssertEquals(location, theLocation, nil);
     }];
    [MUK waitForCompletion:&handlerCalled timeout:1.0 runLoop:nil];
    STAssertTrue(handlerCalled, nil);
    
    // Clean
    NSFileManager *fm = [[NSFileManager alloc] init];
    [fm removeItemAtURL:containerURL error:nil];
}

- (void)testCleanMemoryCache {
    NSString *key = @"key", *value = @"value";
    
    __block BOOL valueCached = NO;
    [self.cache saveObject:value forKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
    {
        valueCached = YES;
    }];
    STAssertTrue(valueCached, nil);
    
    __block BOOL valueFound = NO;
    [self.cache loadObjectForKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(id object, MUKObjectCacheLocation location) 
    {
        valueFound = [object isEqual:value];
    }];
    STAssertTrue(valueFound, nil);
    
    [self.cache cleanMemoryCache];
    valueFound = NO;
    [self.cache loadObjectForKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         valueFound = [object isEqual:value];
     }];
    STAssertFalse(valueFound, nil);
}

- (void)testMemoryWarning {
    NSString *key = @"key", *value = @"value";
    
    __block BOOL valueCached = NO;
    [self.cache saveObject:value forKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(BOOL success, NSError *error, MUKObjectCacheLocation location) 
     {
         valueCached = YES;
     }];
    STAssertTrue(valueCached, nil);
    
    __block BOOL valueFound = NO;
    [self.cache loadObjectForKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         valueFound = [object isEqual:value];
     }];
    STAssertTrue(valueFound, nil);
    
    self.cache.purgesMemoryCacheWhenReceivesMemoryWarning = YES;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:[UIApplication sharedApplication]];

    valueFound = NO;
    [self.cache loadObjectForKey:key locations:MUKObjectCacheLocationMemory completionHandler:^(id object, MUKObjectCacheLocation location) 
     {
         valueFound = [object isEqual:value];
     }];
    STAssertFalse(valueFound, nil);
}

@end
