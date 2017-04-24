//
//  single.h
//  01-单例
//
//  Created by fench on 15/8/6.
//  Copyright (c) 2015年 fench. All rights reserved.
//

// 单例声明
#define singleInterface(name) + (instancetype)share##name

// 单例实现
#if __has_feature(objc_arc)
// ARC下实现
#define singleImplementation(name) + (instancetype)share##name \
{ \
    return [[self alloc] init]; \
} \
static NSObject *_instance; \
+ (instancetype)allocWithZone:(struct _NSZone *)zone \
{ \
    static dispatch_once_t onceToken; \
    dispatch_once(&onceToken, ^{ \
        _instance = [super allocWithZone:zone]; \
    }); \
    return _instance; \
} \
- (id)copyWithZone:(NSZone *)zone \
{ \
    return _instance; \
} \
- (id)mutableCopyWithZone:(NSZone *)zone \
{ \
    return _instance; \
} 


#else
// 非ARC(MRC)下实现
#define singleImplementation(name) +(instancetype)share##name \
{ \
return [[self alloc] init]; \
} \
static Tools *_instance; \
+ (instancetype)allocWithZone:(struct _NSZone *)zone \
{ \
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ \
_instance = [super allocWithZone:zone]; \
}); \
return _instance; \
} \
- (id)copyWithZone:(NSZone *)zone \
{ \
return _instance; \
} \
- (id)mutableCopyWithZone:(NSZone *)zone \
{ \
return _instance; \
} \
- (oneway void)release \
{} \
- (instancetype)retain \
{ \
    return _instance; \
} \
- (NSUInteger)retainCount \
{ \
    return MAXFLOAT; \
}
#endif
