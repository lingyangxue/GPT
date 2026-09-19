#import <UIKit/UIKit.h>
#import <roothide.h>
#import "GPTSettings.h"
#import "GPTChatViewController.h"

static UIWindow *gFloatWindow = nil;
static UIButton *gFloatButton = nil;

static UIImage *getBallIcon(void) {
    NSString *customPath = [GPTSettings iconPath];
    if (customPath && [[NSFileManager defaultManager] fileExistsAtPath:customPath]) {
        UIImage *img = [UIImage imageWithContentsOfFile:customPath];
        if (img) return img;
    }
    NSString *defaultPath = jbroot(@"/Library/Application Support/GPTFloatBall/ball_icon.png");
    UIImage *img = [UIImage imageWithContentsOfFile:defaultPath];
    return img;
}

// 单例：用于处理点击 / 拖拽
@interface GPTFloatBallHandler : NSObject
+ (instancetype)shared;
- (void)ballTapped;
- (void)ballPanned:(UIPanGestureRecognizer *)pan;
@end

@implementation GPTFloatBallHandler

+ (instancetype)shared {
    static GPTFloatBallHandler *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[GPTFloatBallHandler alloc] init];
    });
    return inst;
}

- (void)ballTapped {
    GPTChatViewController *chatVC = [[GPTChatViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:chatVC];
    UIWindow *chatWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    chatWindow.windowLevel = UIWindowLevelAlert + 100;
    chatWindow.rootViewController = nav;
    chatWindow.hidden = NO;

    static UIWindow *sChatWindow = nil;
    sChatWindow = chatWindow;

    chatVC.dismissBlock = ^{
        sChatWindow.hidden = YES;
        sChatWindow = nil;
    };
}

- (void)ballPanned:(UIPanGestureRecognizer *)pan {
    UIView *ball = pan.view;
    UIWindow *win = ball.window;
    CGPoint translation = [pan translationInView:win];
    CGPoint newCenter = CGPointMake(win.center.x + translation.x, win.center.y + translation.y);
    win.center = newCenter;
    [pan setTranslation:CGPointZero inView:win];

    if (pan.state == UIGestureRecognizerStateEnded) {
        CGSize screen = [UIScreen mainScreen].bounds.size;
        CGFloat x = win.frame.origin.x;
        CGFloat y = win.frame.origin.y;
        if (x < screen.width / 2) {
            x = 10;
        } else {
            x = screen.width - 70;
        }
        y = MAX(60, MIN(y, screen.height - 120));
        [UIView animateWithDuration:0.25 animations:^{
            win.frame = CGRectMake(x, y, 60, 60);
        }];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:x forKey:@"ballX"];
        [defaults setFloat:y forKey:@"ballY"];
        [defaults synchronize];
    }
}

@end

static void createFloatBall(void) {
    if (gFloatWindow) return;

    gFloatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    gFloatWindow.windowLevel = UIWindowLevelStatusBar + 100;
    gFloatWindow.backgroundColor = [UIColor clearColor];
    gFloatWindow.rootViewController = [UIViewController new];

    gFloatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    gFloatButton.frame = CGRectMake(0, 0, 60, 60);
    gFloatButton.layer.cornerRadius = 30;
    gFloatButton.layer.masksToBounds = YES;
    gFloatButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.45 blue:0.91 alpha:0.85];

    UIImage *icon = getBallIcon();
    if (icon) {
        [gFloatButton setImage:icon forState:UIControlStateNormal];
        gFloatButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        [gFloatButton setTitle:@"AI" forState:UIControlStateNormal];
        gFloatButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [gFloatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }

    gFloatButton.layer.shadowColor = [UIColor blackColor].CGColor;
    gFloatButton.layer.shadowOffset = CGSizeMake(0, 2);
    gFloatButton.layer.shadowOpacity = 0.3;
    gFloatButton.layer.shadowRadius = 4;
    gFloatButton.layer.masksToBounds = NO;

    // 用单例作为 target
    [gFloatButton addTarget:[GPTFloatBallHandler shared]
                    action:@selector(ballTapped)
          forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:[GPTFloatBallHandler shared]
                action:@selector(ballPanned:)];
    [gFloatButton addGestureRecognizer:pan];

    [gFloatWindow.rootViewController.view addSubview:gFloatButton];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    CGFloat savedX = [defaults floatForKey:@"ballX"];
    CGFloat savedY = [defaults floatForKey:@"ballY"];
    if (savedX == 0 && savedY == 0) {
        CGSize screen = [UIScreen mainScreen].bounds.size;
        savedX = screen.width - 80;
        savedY = screen.height / 2;
    }
    gFloatWindow.frame = CGRectMake(savedX, savedY, 60, 60);

    gFloatWindow.hidden = NO;
}

static void removeFloatBall(void) {
    if (gFloatWindow) {
        gFloatWindow.hidden = YES;
        gFloatWindow = nil;
        gFloatButton = nil;
    }
}

// 通知回调：必须是静态 C 函数，不能用 block（ARC 下会编译失败）
static void settingsChangedCallback(CFNotificationCenterRef center,
                                    void *observer,
                                    CFStringRef name,
                                    const void *object,
                                    CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([GPTSettings isEnabled]) {
            removeFloatBall();
            createFloatBall();
        } else {
            removeFloatBall();
        }
    });
}

%ctor {
    %init;

    if (![GPTSettings isEnabled]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        createFloatBall();
    });

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        settingsChangedCallback,
        CFSTR("com.yourname.gptfloatball/settingsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}
