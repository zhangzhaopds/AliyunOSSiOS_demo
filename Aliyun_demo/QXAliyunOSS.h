//
//  QXAliyunOSS.h
//  Aliyun_demo
//
//  Created by 张昭 on 2018/4/25.
//  Copyright © 2018 heyfox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/OSSService.h>

@interface QXAliyunOSS : NSObject

- (instancetype)initWithDomain:(NSString *)domain withEndPoint:(NSString *)endPoint withBucket:(NSString *)bucketName withAccessID:(NSString *)key withAccessSecret:(NSString *)secret withToken:(NSString *)token;

/** 普通上传 */
- (void)aliyunStartWithFilePath:(NSString *)filePath progressHandler:(void (^)(float))progressHandler completeHandler:(void (^)(BOOL, NSError *,NSString*))completeHandler;

/** 断点上传 */
- (void)aliyunResumableUploadStartWithFilePath:(NSString *)filePath progressHandler:(void (^)(float))progressHandler completeHandler:(void (^)(BOOL, NSError *,NSString*))completeHandler;

@end
