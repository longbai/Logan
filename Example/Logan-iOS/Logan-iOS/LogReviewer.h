//
//  LogReviewer.h
//
//  Created by long on 2020/3/17.

#ifndef LogReviewer_h
#define LogReviewer_h

#import <Foundation/Foundation.h>

#define SDK_VERSION "0.0.1"

extern void logRvDumpLog(BOOL b);

typedef void (^LogRvUploadResultBlock)(NSError *_Nullable error);

/**
 LogReviewer初始化
 
 @param appKey 加密key
 @param max_file_size  日志文件最大大小，超过该大小后日志将不再被写入，单位：byte。
 */
extern void logRvInit(NSString* _Nonnull host, NSString* _Nonnull key, uint64_t max_file_size);

/**
 设置本地保存最大文件天数

 @param max_reserved_date 超过该文件天数的文件会被删除，默认7天
 */
extern void logRvSetMaxReservedDays(int max_reserved_days);

/**
设置https 上传

@param flag false 表示用http 上传，默认为https
*/
extern void logRvEnableHttps(BOOL flag);

/**
 记录一条日志
 
 @param type 日志类型
 @param log  日志字符串
 
 @brief
 用例：
 logrv(1, @"this is a test");
 */
extern void logRv(NSUInteger type, NSString *_Nonnull log);

/**
 返回本地所有文件名及大小(单位byte)
 
 @return @{@"2018-11-21":@"110"}
 */
extern NSDictionary *_Nullable logRvAllFilesInfo(void);

/**
 清除本地所有日志
 */
extern void logRvClearAllLogs(void);

/**
 *    可选参数集合，此类初始化后sdk上传使用时 不会对此进行改变；如果参数没有变化以及没有使用依赖，可以重复使用。
 */
@interface LogRvOption : NSObject

/**
 *    userID 来源，比如wechat, weibo
 */
@property (copy, nonatomic, readonly) NSString * _Nullable provider;

/**
 *    app 下载渠道
 */
@property (copy, nonatomic, readonly) NSString * _Nullable channel;

/**
 *    额外的信息，如果有多个自定义字段，需要处理成一个字符串，之后自行解析
 */
@property (copy, nonatomic, readonly) NSString * _Nullable extra;
/**
 *    可选参数的初始化方法
 *
 *    @param extra     自定义信息
 *    @param provider     用户账号来源
 *    @param channel       下载渠道
 *
 *    @return 可选参数类实例
 */
- (instancetype _Nonnull )initWithExtra:(NSString *_Nullable)extra
                                provider:(NSString *_Nullable)provider
                                 channel:(NSString *_Nullable)channel;
@end

/**
 上传指定日期的日志
 
 @param url 接受日志的服务器地址
 @param date 日志日期，
 @param deviceId 当前设备唯一标识
 @param userId 当前用户的唯一标识,用来区分日志来源用户
 @param resultBlock 服务器返回结果
 */
extern void logRvUpload(NSDate * _Nonnull date, NSString *_Nullable userId,NSString *_Nullable deviceId, LogRvOption* _Nullable option, LogRvUploadResultBlock _Nullable resultBlock);

#endif /* LogReviewer_h */
