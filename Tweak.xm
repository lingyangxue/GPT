#import <UIKit/UIKit.h>
#import <roothide.h>
#import "GPTSettings.h"
#import "GPTChatViewController.h"

static UIWindow *ballWin = nil;
static UIWindow *chatWin = nil;
static UIWindow *prevKeyWin = nil;

@interface Ball : NSObject
+ (instancetype)shared;
- (void)tap;
- (void)pan:(UIPanGestureRecognizer *)g;
@end

@implementation Ball
+ (instancetype)shared {
    static Ball *i = nil; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[Ball alloc] init]; });
    return i;
}

- (UIWindowScene *)scene {
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)s;
        }
    }
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
    }
    return nil;
}

- (void)tap {
    if (chatWin) return;
    UIWindowScene *s = [self scene];
    if (!s) return;
    prevKeyWin = [UIApplication sharedApplication].keyWindow;
    GPTChatViewController *vc = [GPTChatViewController new];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat scale = [GPTSettings windowScale];
    CGFloat w = screen.size.width * scale;
    CGFloat h = screen.size.height * scale;
    CGFloat x = (screen.size.width - w) / 2.0;
    CGFloat y = (screen.size.height - h) / 2.0;
    chatWin = [[UIWindow alloc] initWithWindowScene:s];
    chatWin.frame = CGRectMake(x, y, w, h);
    chatWin.windowLevel = UIWindowLevelAlert;
    chatWin.rootViewController = nav;
    chatWin.backgroundColor = [UIColor systemBackgroundColor];
    chatWin.layer.cornerRadius = 16;
    chatWin.layer.masksToBounds = YES;
    [chatWin makeKeyAndVisible];
    vc.dismissBlock = ^{
        chatWin.hidden = YES;
        chatWin = nil;
        [prevKeyWin makeKeyWindow];
        prevKeyWin = nil;
    };
}

- (void)pan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view;
    UIWindow *w = v.window;
    CGPoint t = [g translationInView:w];
    w.center = CGPointMake(w.center.x + t.x, w.center.y + t.y);
    [g setTranslation:CGPointZero inView:w];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGSize sc = [UIScreen mainScreen].bounds.size;
        CGFloat sz = [GPTSettings ballSize];
        CGFloat x = w.frame.origin.x;
        CGFloat y = w.frame.origin.y;
        if (x < sc.width / 2) {
            x = 10;
        } else {
            x = sc.width - sz - 10;
        }
        if (y < 60) {
            y = 60;
        } else if (y > sc.height - sz - 60) {
            y = sc.height - sz - 60;
        }
        [UIView animateWithDuration:0.25 animations:^{
            w.frame = CGRectMake(x, y, sz, sz);
        }];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setFloat:x forKey:@"ballX"];
        [d setFloat:y forKey:@"ballY"];
        [d synchronize];
    }
}
@end

static void makeBall(void) {
    if (ballWin) return;
    UIWindowScene *s = nil;
    for (UIScene *x in [UIApplication sharedApplication].connectedScenes) {
        if ([x isKindOfClass:[UIWindowScene class]]) {
            s = (UIWindowScene *)x;
            break;
        }
    }
    if (!s) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1500000000), dispatch_get_main_queue(), ^{
            makeBall();
        });
        return;
    }
    CGFloat sz = [GPTSettings ballSize];
    CGFloat alpha = [GPTSettings ballOpacity];
    ballWin = [[UIWindow alloc] initWithWindowScene:s];
    ballWin.frame = CGRectMake(0, 0, sz, sz);
    ballWin.windowLevel = UIWindowLevelStatusBar + 100;
    ballWin.backgroundColor = [UIColor clearColor];
    ballWin.rootViewController = [UIViewController new];
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(0, 0, sz, sz);
    b.layer.cornerRadius = sz / 2.0;
    b.layer.masksToBounds = YES;
    b.backgroundColor = [UIColor colorWithRed:0.1 green:0.45 blue:0.91 alpha:1.0];
    b.alpha = alpha;
    NSString *iconPath = [GPTSettings iconPath];
    UIImage *icon = iconPath ? [UIImage imageWithContentsOfFile:iconPath] : nil;
    if (icon) {
        [b setImage:icon forState:UIControlStateNormal];
        b.imageView.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        [b setTitle:@"AI" forState:UIControlStateNormal];
        [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:MAX(14, sz * 0.3)];
    }
    [b addTarget:[Ball shared] action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[Ball shared] action:@selector(pan:)];
    [b addGestureRecognizer:pan];
    [ballWin.rootViewController.view addSubview:b];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    CGFloat x = [d floatForKey:@"ballX"];
    CGFloat y = [d floatForKey:@"ballY"];
    if (x == 0 && y == 0) {
        CGSize sc = [UIScreen mainScreen].bounds.size;
        x = sc.width - sz - 20;
        y = sc.height / 2;
    }
    ballWin.frame = CGRectMake(x, y, sz, sz);
    ballWin.hidden = NO;
}

static void removeBall(void) {
    if (ballWin) {
        ballWin.hidden = YES;
        ballWin = nil;
    }
}

static void onSettingsChanged(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
    dispatch_async(dispatch_get_main_queue(), ^{
        removeBall();
        makeBall();
    });
}

%ctor {
    %init;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        makeBall();
    });
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, onSettingsChanged, CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}