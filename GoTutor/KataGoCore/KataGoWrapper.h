#ifndef KataGoWrapper_h
#define KataGoWrapper_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KataGoWrapper : NSObject

// 【新增】全局唯一的引擎实例
+ (instancetype)shared;

- (NSString *)setEngineWithModel:(NSString *)modelPath config:(NSString *)configPath;
- (void)sendQuery:(NSString *)jsonQuery;

@end

NS_ASSUME_NONNULL_END

#endif /* KataGoWrapper_h */
