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

#import "MUKObjectCache.h"
#import "MUKObjectCache_Storage.h"
#import "MUKObjectCache_Memory.h"

#import <UIKit/UIKit.h>
#import <MUKToolkit/MUKToolkit.h>

@implementation MUKObjectCache {
    dispatch_queue_t fileCacheQueue_;
}
@synthesize purgesMemoryCacheWhenReceivesMemoryWarning = purgesMemoryCacheWhenReceivesMemoryWarning_;
@synthesize fileCacheURLHandler = fileCacheURLHandler_;
@synthesize fileCachedDataTransformer = fileCachedDataTransformer_;
@synthesize fileCachedObjectTransformer = fileCachedObjectTransformer_;

@synthesize cacheDictionary_ = cacheDictionary__;


- (id)init {
    self = [super init];
    if (self) {
        fileCacheQueue_ = dispatch_queue_create("it.melive.mukit.mukobjectcache.filecache", NULL);
        
        purgesMemoryCacheWhenReceivesMemoryWarning_ = YES;
        [self registerToMemoryWarningNotifications_];
    }
    return self;
}

- (void)dealloc {
    if (fileCacheQueue_) {
        dispatch_release(fileCacheQueue_);
        fileCacheQueue_ = NULL;
    }
    
    [self unregisterFromMemoryWarningNotifications_];
}

#pragma mark - Methods

- (void)loadCachedObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(id, MUKObjectCacheLocation))completionHandler
{
    if (key == nil || locations == MUKObjectCacheLocationNone) {
        completionHandler(nil, MUKObjectCacheLocationNone);
        return;
    }
    
    MUKObjectCacheLocation lastFailedLocation = MUKObjectCacheLocationNone;
    
    // First try loading from in-memory cache
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationMemory]) {
        id object = [self.cacheDictionary_ objectForKey:key];
        if (object) {
            // Call completion handler synchronously
            completionHandler(object, MUKObjectCacheLocationMemory);
            return;
        }
        else {
            lastFailedLocation = MUKObjectCacheLocationMemory;
        }
    }
    
    // Then try loading from file
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationFile]) {
        NSURL *fileCacheURL = [self fileCacheURLForKey:key];
        if (fileCacheURL) {
            // Load in a detached queue
            dispatch_async(fileCacheQueue_, ^{
                NSData *data = [[NSData alloc] initWithContentsOfURL:fileCacheURL];
                id object = [self objectForFileCachedData:data key:key];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    // Notify on main queue
                    completionHandler(object, MUKObjectCacheLocationFile);
                });
            });
            
            return;
        }
        else {
            lastFailedLocation = MUKObjectCacheLocationFile;  
        } // if fileCacheURL
    }
    
    // Not found
    completionHandler(nil, lastFailedLocation);
}

- (void)saveObject:(id)object forKey:(id<NSCopying>)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL, NSError *, MUKObjectCacheLocation))completionHandler
{
    if (object == nil || key == nil || locations == MUKObjectCacheLocationNone) {
        completionHandler(NO, nil, MUKObjectCacheLocationNone);
        return;
    }
    
    // Save into in-memory cache
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationMemory]) {
        [self.cacheDictionary_ setObject:object forKey:key];
        completionHandler(YES, nil, MUKObjectCacheLocationMemory);
    }
    
    // Save into a file
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationFile]) {
        NSURL *fileCacheURL = [self fileCacheURLForKey:key];
        if (fileCacheURL) {
            // Save in a detached queue
            dispatch_async(fileCacheQueue_, ^{
                // Create container
                NSURL *containerURL = [fileCacheURL URLByDeletingLastPathComponent];
                
                NSError *error = nil;
                NSFileManager *fm = [[NSFileManager alloc] init];
                BOOL success = [fm createDirectoryAtPath:[containerURL path] withIntermediateDirectories:YES attributes:nil error:&error];
                
                if (success) {
                    NSData *data = [self dataForFileCachedObject:object key:key];
                    error = nil;
                    success = [data writeToURL:fileCacheURL options:NSDataWritingAtomic error:&error];
                }
                
                // Notify in main queue
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(success, (success ? nil : error), MUKObjectCacheLocationFile);
                });
            });
        }
        else {
            completionHandler(NO, nil, MUKObjectCacheLocationFile);
        }
    }
}

- (void)existsCachedObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL, MUKObjectCacheLocation))completionHandler
{
    if (key == nil || locations == MUKObjectCacheLocationNone) {
        completionHandler(NO, MUKObjectCacheLocationNone);
        return;
    }
    
    // First try searching into in-memory cache
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationMemory]) {
        BOOL exists = [[self.cacheDictionary_ allKeys] containsObject:key];
        completionHandler(exists, MUKObjectCacheLocationMemory);
    }
    
    // Then try testing file
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationFile]) {
        NSURL *fileCacheURL = [self fileCacheURLForKey:key];
        if (fileCacheURL) {
            dispatch_async(fileCacheQueue_, ^{
                NSFileManager *fm = [[NSFileManager alloc] init];
                BOOL exists = [fm fileExistsAtPath:[fileCacheURL path]];
                
                // Notify on main queue
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(exists, MUKObjectCacheLocationFile);
                });
            });
        }
        else {
            completionHandler(NO, MUKObjectCacheLocationFile);
        }
    }
}

- (void)removeCachedObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL, NSError *, MUKObjectCacheLocation))completionHandler
{
    if (key == nil || locations == MUKObjectCacheLocationNone) {
        completionHandler(NO, nil, MUKObjectCacheLocationNone);
        return;
    }
    
    // Remove from in-memory cache
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationMemory]) {
        [self.cacheDictionary_ removeObjectForKey:key];
        completionHandler(YES, nil, MUKObjectCacheLocationMemory);
    }
    
    // Remove from filesystem
    if ([MUK bitmask:locations containsFlag:MUKObjectCacheLocationFile]) {
        NSURL *fileCacheURL = [self fileCacheURLForKey:key];
        if (fileCacheURL) {
            // Remove in a detached queue
            dispatch_async(fileCacheQueue_, ^{
                NSFileManager *fm = [[NSFileManager alloc] init];
                NSError *error = nil;
                BOOL success = [fm removeItemAtURL:fileCacheURL error:&error];
                
                // No such file? Ok, return success anyway
                if (!success && NSCocoaErrorDomain == error.domain && NSFileNoSuchFileError == error.code)
                {
                    success = YES;
                    error = nil;
                }
                
                // Notify on main queue
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionHandler(success, (success ? nil : error), MUKObjectCacheLocationFile);
                });
            });
        }
        else {
            completionHandler(NO, nil, MUKObjectCacheLocationFile);
        }
    }
}

#pragma mark - File Cache

- (NSURL *)fileCacheURLForKey:(id)key {
    NSURL *fileCacheURL = nil;
    
    if (self.fileCacheURLHandler) {
        fileCacheURL = self.fileCacheURLHandler(key);
    }
        
    if (fileCacheURL == nil) {
        @try {
            NSURL *containerURL = [MUK URLForCachesDirectory];
            containerURL = [containerURL URLByAppendingPathComponent:@"MUKObjectCache"];
            fileCacheURL = [[self class] standardFileCacheURLForStringKey:[(id)key description] containerURL:containerURL];
        }
        @catch (NSException *exception) {
            fileCacheURL = nil;
        }
    }
    
    return fileCacheURL;
}

+ (NSURL *)standardFileCacheURLForStringKey:(NSString *)stringKey containerURL:(NSURL *)containerURL
{
    NSURL *fileCacheURL = containerURL;
    
    NSData *keyData = [stringKey dataUsingEncoding:NSUTF8StringEncoding];    
    NSData *SHA1Data = [MUK data:keyData applyingTransform:MUKDataTransformSHA1];
    NSString *SHA1String = [MUK stringHexadecimalRepresentationOfData:SHA1Data];
    
    return [fileCacheURL URLByAppendingPathComponent:SHA1String];
}

- (id)objectForFileCachedData:(NSData *)data key:(id)key {
    id object = nil;
    
    if (self.fileCachedDataTransformer) {
        object = self.fileCachedDataTransformer(key, data);
    }
    
    if (object == nil && [data length] > 0) {
        @try {
            object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        }
        @catch (NSException *exception) {
            object = nil;
        }
    }
    
    return object;
}

- (NSData *)dataForFileCachedObject:(id)object key:(id)key {
    NSData *data = nil;
    
    if (self.fileCachedObjectTransformer) {
        data = self.fileCachedObjectTransformer(key, object);
    }
    
    if (data == nil && object != nil) {
        @try {
            data = [NSKeyedArchiver archivedDataWithRootObject:object];
        }
        @catch (NSException *exception) {
            data = nil;
        }
    }
    
    return data;
}

#pragma mark - Private: Storage

- (NSMutableDictionary *)cacheDictionary_ {
    if (cacheDictionary__ == nil) {
        cacheDictionary__ = [[NSMutableDictionary alloc] init];
    }
    
    return cacheDictionary__;
}

#pragma mark - Private: Memory

- (void)registerToMemoryWarningNotifications_ {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(memoryWarningNotification_:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)unregisterFromMemoryWarningNotifications_ {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (void)memoryWarningNotification_:(NSNotification *)notification {
    if (self.purgesMemoryCacheWhenReceivesMemoryWarning) {
        [self.cacheDictionary_ removeAllObjects];
        self.cacheDictionary_ = nil;
    }
}

@end
