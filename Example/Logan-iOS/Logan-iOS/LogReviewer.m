//
//  LogReviewer.m
//  Logan-iOS
//
//  Created by 白龙 on 2020/3/17.
//  Copyright © 2020 jiangteng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/sysctl.h>
#import "Logan.h"
#import "LogReviewer.h"

void logRvDumpLog(BOOL b){
    loganUseASL(b);
}

NSString* logRvDateFormat(NSDate* date) {
    NSString *key = @"LOGRV_DATE";
    NSMutableDictionary *dictionary = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *dateFormatter = [dictionary objectForKey:key];
    if (!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dictionary setObject:dateFormatter forKey:key];
        [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        [dictionary setObject:dateFormatter forKey:key];
    }
    return [dateFormatter stringFromDate:date];
}

NSString* deviceModel(void) {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *answer = (char *)malloc(size);
  if (answer == NULL)
    return @"";
  sysctlbyname("hw.machine", answer, &size, NULL, 0);
  NSString *platform =
      [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
  free(answer);
  return platform;
}

static NSString *_host;
static bool _useHttps = true;
static NSString* _appId;
static NSString* _deviceType;

void logRvInit(NSString* _Nonnull host, NSString* _Nonnull key, uint64_t max_file_size){
    _host = host;
    NSString* aes = [key substringFromIndex:8];
    NSString* iv = [key substringToIndex:16];
    _appId = [key substringToIndex:8];
    _deviceType = deviceModel();
    loganInit([aes dataUsingEncoding:NSASCIIStringEncoding], [iv dataUsingEncoding:NSASCIIStringEncoding], max_file_size);
}

void logRvSetMaxReservedDays(int max_reserved_days) {
    loganSetMaxReversedDate(max_reserved_days);
}

void logRvEnableHttps(bool flag) {
    _useHttps = flag;
}

void logRv(NSUInteger type, NSString *_Nonnull log) {
    logan(type, log);
}

void logRvClearAllLogs(void) {
    loganClearAllLogs();
}

NSString* buildDeviceInfo(NSString * _Nonnull date, NSString *_Nullable userId,NSString *_Nullable deviceId, LogRvOption* options){
    NSMutableDictionary *dict = [NSMutableDictionary new];

    if(userId.length >0){
       [dict setValue:userId forKey:@"user"];
    }
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    if (bundleVersion.length > 0) {
       [dict setValue:bundleVersion forKey:@"bundleVersion"];
    }

    if(deviceId.length >0){
       [dict setValue:deviceId forKey:@"deviceId"];
    }
    [dict setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"appVersion"];
    [dict setValue:@"iOS" forKey:@"platform"];
    [dict setValue:date forKey:@"fileDate"];
    if (options) {
        if (options.channel) {
            [dict setValue:options.channel forKey:@"channel"];
        }
        if (options.provider) {
            [dict setValue:options.provider forKey:@"provider"];
        }
        if (options.extra) {
            [dict setValue:options.extra forKey:@"extra"];
        }
    }
    [dict setValue:@SDK_VERSION forKey:@"sdkVersion"];
    [dict setValue:[[UIDevice currentDevice] systemVersion] forKey:@"osVersion"];
    [dict setValue:@"Apple" forKey:@"manufacturer"];
    [dict setValue:_deviceType forKey:@"deviceType"];
    [dict setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] forKey:@"appName"];
    [dict setValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"] forKey:@"packageId"];
    NSString* str = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:nil] encoding:NSUTF8StringEncoding];
    NSData* d = [str dataUsingEncoding:NSUTF8StringEncoding];
    d = [d base64EncodedDataWithOptions:0];
    return [[NSString alloc] initWithData:d encoding:NSASCIIStringEncoding];
}

void logRvUpload(NSDate * _Nonnull d, NSString *_Nullable userId,NSString *_Nullable deviceId, LogRvOption* options, LogRvUploadResultBlock _Nullable resultBlock) {
    NSString* date = logRvDateFormat(d);
    loganUploadFilePath(date, ^(NSString *_Nullable filePath) {
        if (filePath == nil) {
            if(resultBlock){
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSError * error = [NSError errorWithDomain:@"qiniu.logrv.error" code:-100 userInfo:@{@"info" : [NSString stringWithFormat:@"can't find file of %@",date]}];
                    resultBlock(error);
                });
            }
            return;
        }
        NSString* scheme = @"http";
        if (_useHttps) {
            scheme = @"https";
        }
        NSString *urlStr = [NSString stringWithFormat:@"%@://%@/logrv/v1/native/%@/tasks", scheme, _host, _appId];
        NSURL *url = [NSURL URLWithString:urlStr];
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:60];
        [req setHTTPMethod:@"POST"];
        [req addValue:@"binary/octet-stream" forHTTPHeaderField:@"Content-Type"];
        NSString* info = buildDeviceInfo(date, userId, deviceId, options);
        [req addValue:info forHTTPHeaderField:@"X-REQINFO"];
        
        NSURL *fileUrl = [NSURL fileURLWithPath:filePath];
        NSURLSessionUploadTask *task = [[NSURLSession sharedSession] uploadTaskWithRequest:req fromFile:fileUrl completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
            if(resultBlock){
                dispatch_async(dispatch_get_main_queue(), ^{
                    resultBlock(error);
                });
            }
        }];
        [task resume];
    });
}

NSDictionary *_Nullable logRvAllFilesInfo(void){
    return loganAllFilesInfo();
}


@implementation LogRvOption

- (instancetype _Nonnull )initWithExtra:(NSString *_Nullable)extra
                               provider:(NSString *_Nullable)provider
                                channel:(NSString *_Nullable)channel {
    if (self = [super init]) {
        _extra = extra;
        _provider = provider;
        _channel = channel;
    }

    return self;
}

@end
