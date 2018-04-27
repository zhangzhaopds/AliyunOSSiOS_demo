//
//  QXAliyunOSS.m
//  Aliyun_demo
//
//  Created by 张昭 on 2018/4/25.
//  Copyright © 2018 heyfox. All rights reserved.
//

#import "QXAliyunOSS.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import <CoreLocation/CoreLocation.h>
#import <CommonCrypto/CommonDigest.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#import "sys/utsname.h"

@interface QXAliyunOSS ()

@property (nonatomic, copy) NSString *aliyunDomain;
@property (nonatomic, copy) NSString *aliyunEndPoint;
@property (nonatomic, copy) NSString *aliyunBucketName;
@property (nonatomic, copy) NSString *aliyunAccessKeyID;
@property (nonatomic, copy) NSString *aliyunAccessKeySecret;
@property (nonatomic, copy) NSString *aliyunAccessToken;

@end

@implementation QXAliyunOSS

- (instancetype)initWithDomain:(NSString *)domain withEndPoint:(NSString *)endPoint withBucket:(NSString *)bucketName withAccessID:(NSString *)key withAccessSecret:(NSString *)secret withToken:(NSString *)token {
    self = [super init];
    if (self) {
        _aliyunDomain = domain;
        _aliyunEndPoint = endPoint;
        _aliyunBucketName = bucketName;
        _aliyunAccessKeyID = key;
        _aliyunAccessKeySecret = secret;
        _aliyunAccessToken = token;
    }
    return self;
}

-(NSString *)getMIMETypeAtFilePath:(NSString *)path
{
    if (![[[NSFileManager alloc] init] fileExistsAtPath:path]) {
        return nil;
    }
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

/** 断点上传 */
- (void)aliyunResumableUploadStartWithFilePath:(NSString *)filePath progressHandler:(void (^)(float))progressHandler completeHandler:(void (^)(BOOL, NSError *,NSString*))completeHandler {
    
    if (filePath == nil || filePath.length == 0) {
        if (completeHandler) {
            NSLog(@"阿里云-上传失败- 文件路径为空");
            completeHandler(NO, nil, nil);
        }
        return;
    }
    if (![NSData dataWithContentsOfFile:filePath].length) {
        if (completeHandler) {
            NSLog(@"阿里云-上传失败- data size is 0");
            completeHandler(NO, nil, nil);
        }
        return;
    }

    NSString *domain = _aliyunDomain;
    NSString *aliyunBucketName = _aliyunBucketName;
    
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSString *objectKey = [self getFileMD5WithPath:filePath];
    if ([filePath pathExtension].length > 0) {
        objectKey = [NSString stringWithFormat:@"%@.%@", objectKey, [filePath pathExtension]];
    }
    NSLog(@"阿里云-objectKey: %@", objectKey);
    
    NSString *mimeType = [self getMIMETypeAtFilePath:filePath];

    __block NSString *recordKey;
    __block OSSResumableUploadRequest *resumableUpload = [OSSResumableUploadRequest new];
    
    /** Token模式 */
    id<OSSCredentialProvider> credential = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:_aliyunAccessKeyID secretKeyId:_aliyunAccessKeySecret securityToken:_aliyunAccessToken];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:_aliyunEndPoint credentialProvider:credential];
    
    [[[[[[OSSTask taskWithResult:nil] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        NSDate *lastModified;
        NSError *error;
        [fileURL getResourceValue:&lastModified forKey:NSURLContentModificationDateKey error:&error];
        if (error) {
            NSLog(@"阿里云-任务出错-1： %@", task.error);
            return [OSSTask taskWithResult:error];
        }
        recordKey = [NSString stringWithFormat:@"%@_%@_%@_%@", aliyunBucketName, objectKey, [OSSUtil getRelativePath:[fileURL absoluteString]], lastModified];
        NSLog(@"阿里云-recordKey: %@", recordKey);
        return [OSSTask taskWithResult:[[NSUserDefaults standardUserDefaults] objectForKey:recordKey]];
    }] continueWithSuccessBlock:^id _Nullable(OSSTask * _Nonnull task) {
        if (!task.result) {
            OSSInitMultipartUploadRequest *initMultipart = [OSSInitMultipartUploadRequest new];
            initMultipart.bucketName = aliyunBucketName;
            initMultipart.objectKey = objectKey;
            NSLog(@"阿里云-新建任务");
            return [client multipartUploadInit:initMultipart];
        }
        NSLog(@"阿里云-断点续传： %@", task.result);
        return task;
    }] continueWithSuccessBlock:^id _Nullable(OSSTask * _Nonnull task) {
        NSString * uploadId = nil;
        if (task.error) {
            NSLog(@"阿里云-任务出错-2： %@", task.error);
            return task;
        }
        if ([task.result isKindOfClass:[OSSInitMultipartUploadResult class]]) {
            uploadId = ((OSSInitMultipartUploadResult *)task.result).uploadId;
        } else {
            uploadId = task.result;
        }
        if (!uploadId) {
            NSLog(@"阿里云-任务出错-3： 无uploadID");
            return [OSSTask taskWithError:[NSError errorWithDomain:OSSClientErrorDomain code:OSSClientErrorCodeNilUploadid userInfo:@{OSSErrorMessageTOKEN: @"Can't get an upload id"}]];
        }
        
        NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
        [userDefault setObject:uploadId forKey:recordKey];
        [userDefault synchronize];
        NSLog(@"阿里云-UploadId: %@", uploadId);
        return [OSSTask taskWithResult:uploadId];
    }] continueWithSuccessBlock:^id _Nullable(OSSTask * _Nonnull task) {
        
        resumableUpload.bucketName = aliyunBucketName;
        resumableUpload.objectKey = objectKey;
        resumableUpload.uploadId = task.result;
        resumableUpload.uploadingFileURL = fileURL;
        resumableUpload.completeMetaHeader = @{@"x-oss-object-acl": @"public-read"};
        resumableUpload.contentType = mimeType;
        
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        resumableUpload.recordDirectoryPath = cachesDir;
        
        resumableUpload.uploadProgress = ^(int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
            float number = (float)totalBytesSent/(float)totalBytesExpectedToSend;
            NSLog(@"阿里云-UploadId: %@, %0.2f", task.result, number);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (progressHandler) {
                    progressHandler((float)totalBytesSent / (float)totalBytesExpectedToSend);
                }
            });
        };
        NSLog(@"阿里云-续传： %@", task.result);
        return [client resumableUpload:resumableUpload];
    }] continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {
        if (task.error) {
            NSLog(@"阿里云-上传失败： %@", task.error);
            if ([task.error.domain isEqualToString:OSSClientErrorDomain] && task.error.code == OSSClientErrorCodeCannotResumeUpload) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:recordKey];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completeHandler) {
                    completeHandler(NO, task.error, nil);
                }
            });
        } else {
            NSString *media = [NSString stringWithFormat:@"%@/%@", domain, resumableUpload.objectKey];
            NSLog(@"阿里云-上传成功: %@", media);
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:recordKey];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completeHandler) {
                    completeHandler(YES, nil, media);
                }
            });
        }
        resumableUpload = nil;
        return nil;
    }];
}

/** 普通上传 */
- (void)aliyunStartWithFilePath:(NSString *)filePath progressHandler:(void (^)(float))progressHandler completeHandler:(void (^)(BOOL, NSError *,NSString*))completeHandler {
    
    if (filePath == nil || filePath.length == 0) {
        if (completeHandler) {
            NSLog(@"阿里云-上传失败- 文件路径为空");
            completeHandler(NO, nil, nil);
        }
        return;
    }
    if (![NSData dataWithContentsOfFile:filePath].length) {
        if (completeHandler) {
            NSLog(@"阿里云-上传失败- data size is 0");
            completeHandler(NO, nil, nil);
        }
        return;
    }
    
    NSString *domain = _aliyunDomain;
    NSString *aliyunBucketName = _aliyunBucketName;
    NSString *aliyunUploadKey = [self getFileMD5WithPath:filePath];
    
    if ([filePath pathExtension].length > 0) {
        aliyunUploadKey = [NSString stringWithFormat:@"%@.%@", aliyunUploadKey, [filePath pathExtension]];
    }
    
    /** Token模式 */
    id<OSSCredentialProvider> credential = [[OSSStsTokenCredentialProvider alloc] initWithAccessKeyId:_aliyunAccessKeyID secretKeyId:_aliyunAccessKeySecret securityToken:_aliyunAccessToken];
    OSSClient *client = [[OSSClient alloc] initWithEndpoint:_aliyunEndPoint credentialProvider:credential];
    
    __block OSSPutObjectRequest *ossPutRequest = [OSSPutObjectRequest new];
    ossPutRequest.bucketName = aliyunBucketName;
    ossPutRequest.objectKey = aliyunUploadKey;
    ossPutRequest.objectMeta = @{@"x-oss-object-acl": @"public-read"};
    ossPutRequest.uploadingFileURL = [NSURL fileURLWithPath:filePath];
    ossPutRequest.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"阿里云-上传进度: %lld, %lld, %0.2f", totalByteSent, totalBytesExpectedToSend, (float)totalByteSent / (float)totalBytesExpectedToSend);
            if (progressHandler) {
                progressHandler((float)totalByteSent / (float)totalBytesExpectedToSend);
            }
        });
    };

    OSSTask *task = [client putObject:ossPutRequest];
    [task continueWithBlock:^id _Nullable(OSSTask * _Nonnull task) {

        if (!task.error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *media = [NSString stringWithFormat:@"%@/%@", domain, aliyunUploadKey];
                NSLog(@"阿里云-上传成功: %@", media);
                if (completeHandler) {
                    completeHandler(YES, nil, media);
                }
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"阿里云-上传失败: %@", task.error);
                if (completeHandler) {
                    completeHandler(NO, task.error, nil);
                }
            });
        }
        ossPutRequest = nil;
        return nil;
    }];
}


#define FileHashDefaultChunkSizeForReadingData 1024*8

- (NSString *)getFileMD5WithPath:(NSString *)path{
    
    return (__bridge_transfer NSString *)FileMD5HashCreateWithPath((__bridge CFStringRef)path, FileHashDefaultChunkSizeForReadingData);
}

CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath,size_t chunkSizeForReadingData) {
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,(UInt8 *)buffer,(CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,(const char *)hash,kCFStringEncodingUTF8);
    
done:
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}

@end
