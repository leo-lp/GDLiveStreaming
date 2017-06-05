//
//  GDLViewController.m
//  GDLiveStreaming
//
//  Created by Larry Tin on 05/06/2016.
//  Copyright (c) 2016 Larry Tin. All rights reserved.
//

#import <GPUImage/GPUImageView.h>
#import <GPUImage/GPUImageFilter.h>
#import <AVFoundation/AVFoundation.h>
#import <GPUImage/GPUImageVideoCamera.h>
#import <GPUImage/GPUImageRawDataOutput.h>
#import "GDLViewController.h"
#import "GDLRawDataOutput.h"
#import "GPUImageMovieWriter.h"
#import "GPUImageLanczosResamplingFilter.h"
#import "GPUImageBeautifyFilter.h"
#import "GDLFilterUtil.h"
#import <AssetsLibrary/ALAssetsLibrary.h>

@interface GDLViewController ()

@end

@implementation GDLViewController {
  GPUImageVideoCamera *_videoCamera;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.

  _videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionFront];
  _videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
  _videoCamera.frameRate = 20;

  CGSize viewSize = self.view.frame.size;
  GPUImageView *filteredVideoView = [[GPUImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, viewSize.width, viewSize.height)];
  [self.view addSubview:filteredVideoView];
  [_videoCamera addTarget:filteredVideoView];

  CGSize captureSize = CGSizeMake(16 * 45, 1280);
  CGSize rtmpSize = CGSizeMake(16 * 23, 640);
  GPUImageFilter *filter = [[GPUImageLanczosResamplingFilter alloc] init];
  [filter forceProcessingAtSize:rtmpSize];
  GDLRawDataOutput *rtmpOutput = [[GDLRawDataOutput alloc] initWithVideoCamera:_videoCamera withImageSize:rtmpSize];
  [_videoCamera addTarget:filter];
  [filter addTarget:rtmpOutput];

  // 同时备份视频到本地文件
  NSString *pathToMovie = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Movie.m4v"];
  unlink([pathToMovie UTF8String]); // If a file already exists, AVAssetWriter won't let you record new frames, so delete the old movie
  NSURL *movieURL = [NSURL fileURLWithPath:pathToMovie];
  GPUImageMovieWriter *movieWriter = [[GPUImageMovieWriter alloc] initWithMovieURL:movieURL size:captureSize];
  movieWriter.encodingLiveVideo = YES;
  [_videoCamera addTarget:movieWriter];

  // 是否开启美颜
  BOOL useSkinSmoothing = NO;
  if (useSkinSmoothing) {
    GPUImageBeautifyFilter *beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    [GDLFilterUtil insertFilter:beautifyFilter before:filteredVideoView toChain:_videoCamera];
  }

  [_videoCamera startCameraCapture];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
      _videoCamera.audioEncodingTarget = movieWriter;
      [movieWriter startRecording];
      [rtmpOutput startUploadStreamWithURL:@"rtmp://a.rtmp.youtube.com/live2" andStreamKey:@"323c-p07x-2g2e-c57k"];

      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
          [_videoCamera removeTarget:movieWriter];
          _videoCamera.audioEncodingTarget = nil;
          [movieWriter finishRecording];
          NSLog(@"Movie completed");

          ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
          if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:movieURL]) {
            [library writeVideoAtPathToSavedPhotosAlbum:movieURL completionBlock:^(NSURL *assetURL, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error) {
                      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Video Saving Failed"
                                                                     delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                      [alert show];
                    } else {
                      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Video Saved" message:@"Saved To Photo Album"
                                                                     delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
                      [alert show];
                    }
                });
            }];
          }
      });
  });
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
