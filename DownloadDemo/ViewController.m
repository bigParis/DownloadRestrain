//
//  ViewController.m
//  DownloadDemo
//
//  Created by yy on 2019/3/23.
//  Copyright © 2019年 BP. All rights reserved.
//

#import "ViewController.h"
#import "NSObject+NetworkStateOrRSSI.h"

static const int kDownloadTime = 1;
static const int kSleepTime = 5;

@interface ViewController ()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, weak) UIButton *startBtn;
@property (nonatomic, weak) UIButton *pauseBtn;
@property (nonatomic, weak) UIButton *resumeBtn;
@property (nonatomic, weak) UIButton *cancelBtn;
@property (nonatomic, weak) UILabel *inStreamSpeed;
@property (nonatomic, weak) UILabel *outStreamSpeed;
@property (nonatomic, strong) NSTimer *downloadTimer;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, assign) NSTimeInterval totalCost;
@property (nonatomic, strong) NSMutableDictionary *taskArray;
@property (nonatomic, strong) dispatch_queue_t downloadQueue;
@property (nonatomic, strong) NSObject *networkManager;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.networkManager = [[NSObject alloc] init];
    [self initViews];
    [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(monitorNetworkState) userInfo:nil repeats:YES];
}

- (void)monitorNetworkState
{
    [self.networkManager detectionBytes];
//    NSLog(@"下行流量:%u/KB", self.networkManager.nowIBytes);
//    NSLog(@"上行流量:%u/KB", self.networkManager.nowOBytes);
    
    self.inStreamSpeed.text = [NSString stringWithFormat:@"下行流量:%@/KB", @(self.networkManager.nowIBytes)];
    self.outStreamSpeed.text = [NSString stringWithFormat:@"上行流量:%@/KB", @(self.networkManager.nowOBytes)];
}

- (void)initViews
{
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [startBtn setBackgroundColor:[UIColor redColor]];
    [startBtn setTitle:@"start" forState:UIControlStateNormal];
    [startBtn addTarget:self action:@selector(onStartBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.startBtn = startBtn;
    [self.view addSubview:startBtn];
    
    UIButton *pauseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [pauseBtn setBackgroundColor:[UIColor redColor]];
    [pauseBtn setTitle:@"pause" forState:UIControlStateNormal];
    [pauseBtn addTarget:self action:@selector(onPauseBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.pauseBtn = pauseBtn;
    [self.view addSubview:pauseBtn];
    
    UIButton *resumeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [resumeBtn setBackgroundColor:[UIColor redColor]];
    [resumeBtn setTitle:@"resume" forState:UIControlStateNormal];
    [resumeBtn addTarget:self action:@selector(onResumeBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.resumeBtn = resumeBtn;
    [self.view addSubview:resumeBtn];
    
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [cancelBtn setBackgroundColor:[UIColor redColor]];
    [cancelBtn setTitle:@"cancel" forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(onCancelBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.cancelBtn = cancelBtn;
    [self.view addSubview:cancelBtn];
    
    UILabel *inStreamSpeed = [[UILabel alloc] init];
    inStreamSpeed.backgroundColor = [UIColor redColor];
    [inStreamSpeed setText:@"下行流量"];
    [inStreamSpeed setTextColor:[UIColor whiteColor]];
    self.inStreamSpeed = inStreamSpeed;
    [self.view addSubview:inStreamSpeed];
    
    UILabel *outStreamSpeed = [[UILabel alloc] init];
    outStreamSpeed.backgroundColor = [UIColor redColor];
    [outStreamSpeed setText:@"上行流量"];
    [outStreamSpeed setTextColor:[UIColor whiteColor]];
    self.outStreamSpeed = outStreamSpeed;
    [self.view addSubview:outStreamSpeed];
}

- (void)onStartBtnClicked:(UIButton *)sender
{
    [self.taskArray removeAllObjects];
    dispatch_queue_t downloadQueue = dispatch_queue_create("com.yy.download.queue", DISPATCH_QUEUE_SERIAL);
    self.downloadQueue = downloadQueue;
    for (int i = 0; i < 10; i++) {
        dispatch_sync(downloadQueue, ^{
            NSLog(@"add dataTask:%@, thread:%@", @(i), [NSThread currentThread]);
            NSURLSessionDataTask *dataTask = [self getDataTask];
            dataTask.taskDescription = [NSString stringWithFormat:@"任务_%@", @(i)];
            [self.taskArray setObject:dataTask forKey:dataTask.taskDescription];
        });
        if (i == 9) {
            NSString *taskId = [NSString stringWithFormat:@"任务_%@", @(1)];
            NSURLSessionDataTask *dataTask = self.taskArray[taskId];
            self.dataTask = dataTask;
            [dataTask resume];
        }
    }
}

- (void)onPauseBtnClicked:(UIButton *)sender
{
    [self.dataTask suspend];
}

- (void)onResumeBtnClicked:(UIButton *)sender
{
    [self.dataTask resume];
}

- (void)onCancelBtnClicked:(UIButton *)sender
{
    [self.dataTask cancel];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    self.inStreamSpeed.frame = CGRectMake(20, CGRectGetMaxY(statusBarFrame) + 10, 200, 25);
    self.outStreamSpeed.frame = CGRectMake(20, CGRectGetMaxY(self.inStreamSpeed.frame) + 10, 200, 25);
    
    self.startBtn.frame = CGRectMake((self.view.bounds.size.width - 200) * 0.5, CGRectGetMaxX(self.outStreamSpeed.frame) + 20, 200, 50);
    self.pauseBtn.frame = CGRectMake(CGRectGetMinX(self.startBtn.frame), CGRectGetMaxY(self.startBtn.frame) + 20, 200, 50);
    self.resumeBtn.frame = CGRectMake(CGRectGetMinX(self.startBtn.frame), CGRectGetMaxY(self.pauseBtn.frame) + 20, 200, 50);
    self.cancelBtn.frame = CGRectMake(CGRectGetMinX(self.startBtn.frame), CGRectGetMaxY(self.resumeBtn.frame) + 20, 200, 50);
}

- (NSURLSessionDataTask *)getDataTask
{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    NSURL *url = [NSURL URLWithString:@"http://sznk.fcloud.store.qq.com/store_raw_download?buid=16821&uuid=b4c539a7ae1741cdb9950cbcde77030c&fsname=CourseTeacher_1.2.4.2_DailyBuild.dmg"];
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url];

    self.downloadTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(onDownloadTimerTimeout:) userInfo:nil repeats:NO];
    return dataTask;
}

- (void)onDownloadTimerTimeout:(NSTimer *)timer
{
    dispatch_async(self.downloadQueue, ^{
        if (self.dataTask.state == NSURLSessionTaskStateRunning) {
            [self.dataTask suspend];
            NSInteger nextRunTime = arc4random() % 4 + 1; // 1-5秒后执行
            nextRunTime = kSleepTime;
            NSLog(@"暂停下载%@, %@秒后继续", self.dataTask.taskDescription, @(nextRunTime));
            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadTimer = [NSTimer scheduledTimerWithTimeInterval:nextRunTime target:self selector:@selector(onDownloadTimerTimeout:) userInfo:nil repeats:NO];
            });
            
        } else if (self.dataTask.state == NSURLSessionTaskStateSuspended) {
            [self.dataTask resume];
            NSLog(@"继续下载%@, %@秒后将暂停", self.dataTask.taskDescription, @(kDownloadTime));
            dispatch_async(dispatch_get_main_queue(), ^{
                self.downloadTimer = [NSTimer scheduledTimerWithTimeInterval:kDownloadTime target:self selector:@selector(onDownloadTimerTimeout:) userInfo:nil repeats:NO];
            });
        }
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    dispatch_async(self.downloadQueue, ^{
        self.startTime = [NSDate date];
        NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *fullPath = [path stringByAppendingPathComponent:dataTask.response.suggestedFilename];
        [[NSFileManager defaultManager] createFileAtPath:fullPath contents:nil attributes:nil];
        self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:fullPath];
        NSLog(@"%@开始下载, 文件总大小：%@, 线程：%@",dataTask.taskDescription, @(dataTask.countOfBytesExpectedToReceive), [NSThread currentThread]);
        completionHandler(NSURLSessionResponseAllow);
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    dispatch_async(self.downloadQueue, ^{
        [self.fileHandle writeData:data];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    dispatch_async(self.downloadQueue, ^{
        NSTimeInterval currentCost = [[NSDate date] timeIntervalSinceDate:self.startTime];
        NSLog(@"%@:下载耗时：%@ms", task.taskDescription ,@(currentCost));
        NSString *taskId = task.taskDescription;
        [self.taskArray removeObjectForKey:task.taskDescription];
        taskId = [taskId stringByReplacingOccurrencesOfString:@"任务_" withString:@""];
        
        taskId = [NSString stringWithFormat:@"任务_%@", @([taskId integerValue] + 1)];
        
        self.totalCost += currentCost;
        [self.fileHandle closeFile];
        self.fileHandle = nil;
        self.dataTask = nil;
        NSURLSessionDataTask *nextTask = self.taskArray[taskId];
        
        if (nextTask != nil) {
            self.dataTask = nextTask;
            [nextTask resume];
        } else {
            NSLog(@"平均下载时间:%@", @(self.totalCost / 10.0));
            self.totalCost = 0;
            [self.downloadTimer invalidate];
            self.downloadTimer = nil;
        }
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    NSLog(@"我回来了");
}

- (NSMutableDictionary *)taskArray
{
    if (_taskArray == nil) {
        _taskArray = [NSMutableDictionary dictionary];
    }
    return _taskArray;
}
@end
