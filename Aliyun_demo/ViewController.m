//
//  ViewController.m
//  Aliyun_demo
//
//  Created by 张昭 on 2018/4/25.
//  Copyright © 2018 heyfox. All rights reserved.
//

#import "ViewController.h"
#import "QXAliyunOSS.h"

@interface ViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (strong, nonatomic) IBOutlet UILabel *mProgressLabel;
@property (strong, nonatomic) IBOutlet UIImageView *mImageView;
@property (nonatomic, strong) QXAliyunOSS *aliyun;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *aliyunDomain = @"";
    NSString *aliyunBucketName = @"";
    NSString *aliyunEndPoint = @"";
    NSString *aliyunAccessKeyID = @"";
    NSString *aliyunAccessKeySecret = @"";
    NSString *aliyunAccessToken = @"";
    
    self.aliyun = [[QXAliyunOSS alloc] initWithDomain:aliyunDomain withEndPoint:aliyunEndPoint withBucket:aliyunBucketName withAccessID:aliyunAccessKeyID withAccessSecret:aliyunAccessKeySecret withToken:aliyunAccessToken];

}


- (IBAction)cancelUploadClicked:(UIButton *)sender {
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"dongwu" ofType:@"mp4"];
}

- (IBAction)chooseImageClicked:(UIButton *)sender {
    [self gotoImageLibrary];
}

- (IBAction)resumeClicked:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"dongwu" ofType:@"mp4"];
//    NSString *path = [self getImagePath:self.mImageView.image];
    [self.aliyun aliyunResumableUploadStartWithFilePath:path progressHandler:^(float progress) {
        weakSelf.mProgressLabel.text = [NSString stringWithFormat:@"%0.2f", progress];
    } completeHandler:^(BOOL finish, NSError *error, NSString *url) {
        weakSelf.mProgressLabel.text = url;
        NSLog(@"%@", finish ? @"完成了": @"未完成");
        NSLog(@"%@", error.localizedDescription);
        NSLog(@"%@", url);
    }];
}

- (IBAction)uploadClicked:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Turkey" ofType:@"mp4"];
//    NSString *path = [self getImagePath:self.mImageView.image];
    [self.aliyun aliyunStartWithFilePath:path progressHandler:^(float progress) {
        weakSelf.mProgressLabel.text = [NSString stringWithFormat:@"%0.2f", progress];
    } completeHandler:^(BOOL finish, NSError *error, NSString *url) {
        weakSelf.mProgressLabel.text = url;
        NSLog(@"%@", finish ? @"完成了": @"未完成");
        NSLog(@"%@", error.localizedDescription);
        NSLog(@"%@", url);
    }];
}

- (void)gotoImageLibrary {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:picker animated:YES completion:nil];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"访问图片库错误" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        [alert addAction:action];
        [self presentViewController:alert animated:true completion:nil];
    }
}

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSLog(@"%@", info);
    if ([[info objectForKey:UIImagePickerControllerMediaType] isEqualToString:@"public.image"]) {
        if ([info objectForKey:UIImagePickerControllerOriginalImage]) {
            self.mImageView.image = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
    }
    [picker dismissViewControllerAnimated:YES completion:^{
    }];
}


- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)getImagePath:(UIImage *)Image {
    NSString *filePath = nil;
    NSData *data = nil;
    if (UIImagePNGRepresentation(Image) == nil) {
        data = UIImageJPEGRepresentation(Image, 1.0);
    } else {
        data = UIImagePNGRepresentation(Image);
    }
    
    NSString *DocumentsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    [fileManager createDirectoryAtPath:DocumentsPath withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *ImagePath = [[NSString alloc] initWithFormat:@"/theFirstImage.png"];
    [fileManager createFileAtPath:[DocumentsPath stringByAppendingString:ImagePath] contents:data attributes:nil];
    
    filePath = [[NSString alloc] initWithFormat:@"%@%@", DocumentsPath, ImagePath];
    return filePath;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
