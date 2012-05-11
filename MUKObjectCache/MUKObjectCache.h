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

#import <Foundation/Foundation.h>

typedef enum {
    MUKObjectCacheLocationNone      =   0,
    
    MUKObjectCacheLocationMemory    =   1 << 0,
    MUKObjectCacheLocationFile      =   1 << 1,
    
    MUKObjectCacheLocationLocal     = (MUKObjectCacheLocationMemory|MUKObjectCacheLocationFile)
} MUKObjectCacheLocation;

/**
 This object caches other objects both to memory and to disk.
 
 ## Constants
 
 `MUKObjectCacheLocation` enumerates supported cache locations:
 
 * `MUKObjectCacheLocationNone` does not cache at all.
 * `MUKObjectCacheLocationMemory` caches objects in memory.
 * `MUKObjectCacheLocationFile` caches objects to file.
 * `MUKObjectCacheLocationLocal` caches objects both in memory and to file.
 */
@interface MUKObjectCache : NSObject
/** @name Properties */
/**
 Memory cache is purged when `UIApplicationDidReceiveMemoryWarningNotification`
 is received.
 
 Default is `YES`.
 */
@property (nonatomic) BOOL purgesMemoryCacheWhenReceivesMemoryWarning;

/** @name Handlers */
/**
 File URL to cache an object to file
 
 @see fileCacheURLForKey:
 */
@property (nonatomic, copy) NSURL* (^fileCacheURLHandler)(id key);
/**
 Transforms data to object.
 
 @warning This handler is not called on main queue.
 @see objectForFileCachedData:key:
 */
@property (nonatomic, copy) id (^fileCachedDataTransformer)(id key, NSData *data);
/**
 Transforms object to data.
 
 @warning This handler is not called on main queue.
 @see dataForFileCachedObject:key:
 */
@property (nonatomic, copy) NSData* (^fileCachedObjectTransformer)(id key, id object);

/** @name Methods */
/**
 Load cached object from requested locations.
 
 @param key Object unique key in cache.
 @param locations A bitmask of `MUKObjectCacheLocation` values. 
 `MUKObjectCacheLocationMemory` is tried first.
 @param completionHandler An handler which signals loading completion. It is 
 called once, on main queue. It is called synchronously if `location` is 
 `MUKObjectCacheLocationMemory`, but could be called asynchronously if `location`
 is `MUKObjectCacheLocationFile`.
 */
- (void)loadObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(id object, MUKObjectCacheLocation location))completionHandler;
/**
 Save object to requested cache locations.
 
 @param object Object to cache.
 @param key Object unique key in cache. This object will be copied.
 @param locations A bitmask of `MUKObjectCacheLocation` values. Object will be
 cached in every cache location requested here.
 @param completionHandler An handler which signals saving completion. It is 
 called once per requested location, on main queue. It is called synchronously if 
 `location` is `MUKObjectCacheLocationMemory`, but is called asynchronously if 
 `location` is `MUKObjectCacheLocationFile`.
 */
- (void)saveObject:(id)object forKey:(id<NSCopying>)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL success, NSError *error, MUKObjectCacheLocation location))completionHandler;
/**
 Check if given key has a cached object.
 
 @param key Object unique key in cache.
 @param locations A bitmask of `MUKObjectCacheLocation` values. Key will be
 checked in every cache location requested here.
 @param completionHandler An handler which signals check completion. It is 
 called once per requested location, on main queue. It is called synchronously if 
 `location` is `MUKObjectCacheLocationMemory`, but is called asynchronously if 
 `location` is `MUKObjectCacheLocationFile`.
 */
- (void)existsObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL exists, MUKObjectCacheLocation location))completionHandler;
/**
 Removes object from requested cache locations.
 
 @param key Object unique key in cache.
 @param locations A bitmask of `MUKObjectCacheLocation` values. Cached object
 will be removed in every cache location requested here.
 @param completionHandler An handler which signals removal completion. It is 
 called once per requested location, on main queue. It is called synchronously if 
 `location` is `MUKObjectCacheLocationMemory`, but is called asynchronously if 
 `location` is `MUKObjectCacheLocationFile`.
 */
- (void)removeObjectForKey:(id)key locations:(MUKObjectCacheLocation)locations completionHandler:(void (^)(BOOL success, NSError *error, MUKObjectCacheLocation location))completionHandler;
@end


@interface MUKObjectCache (FileCache)
/**
 File URL to cache object.
 
 Default implementation calls fileCacheURLHandler if it returns `nil` or it
 is not set, it uses standardFileCacheURLForStringKey:containerURL: with
 `Caches/MUKObjectCache` as container and `SHA1([key description])` as 
 `stringKey` (which is not ideal so, please, set fileCacheURLHandler properly).
 
 @param key Cached object key.
 @return File URL where cached object will be saved to.
 */
- (NSURL *)fileCacheURLForKey:(id)key;
/**
 Shortend to create a file URL from a key.
 
 It appends SHA1 of stringKey to containerURL.
 
 @param stringKey String representation of key.
 @param containerURL Directory which contains cached files.
 @return An example of file URL to cache objects to file.
 */
+ (NSURL *)standardFileCacheURLForStringKey:(NSString *)stringKey containerURL:(NSURL *)containerURL;
/**
 Transforms data to an object.
 
 Default implementation calls fileCachedDataTransformer: if it returns `nil` or
 it is not set, it tries to use `[NSKeyedUnarchiver unarchiveObjectWithData:]`.
 
 @param data Data to transform.
 @param key Object cache key.
 @return Object transformed from data.
 @warning This method is not called on main queue.
 */
- (id)objectForFileCachedData:(NSData *)data key:(id)key;
/**
 Transforms object to data.
 
 Default implementation calls fileCachedObjectTransformer: if it returns `nil` or
 it is not set, it tries to use `[NSKeyedArchiver archivedDataWithRootObject:]`
 
 @param object Object to transform.
 @param key Object cache key.
 @return Data created from data.
 @warning This method is not called on main queue.
 */
- (NSData *)dataForFileCachedObject:(id)object key:(id)key;
@end


@interface MUKObjectCache (MemoryCache)
/**
 Removes all memory cached objects.
 */
- (void)cleanMemoryCache;
@end

