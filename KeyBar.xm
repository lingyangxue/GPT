#import <UIKit/UIKit.h>
#import <roothide.h>
#import "GPTSettings.h"

static UIWindow *kbBarWin = nil;

@interface KbBarHandler : NSObject
+ (void)openChat;
@end

@implementation KbBarHandler
+ (void)openChat {
    UIWindow *kw = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow && w != kbBarWin) { kw = w; break; }
    }
    if (!kw) return;
    UIViewController *top = kw.rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    if (!top) return;

    Class vcClass = NSClassFromString(@"GPTChatViewController");
    if (!vcClass) return;
    UIViewController *vc = [[vcClass alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [top presentViewController:nav animated:YES completion:nil];
}
@end

static void showKbBar(CGFloat kbY, CGFloat kbW) {
    if (kbBarWin) return;
    if (![GPTSettings isEnabled]) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
    }
    if (!scene) return;

    CGFloat H = 44;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    CGFloat y = kbY - H;
    if (y < 0) y = screenH - H - 300;

    kbBarWin = [[UIWindow alloc] initWithWindowScene:scene];
    kbBarWin.frame = CGRectMake(0, y, kbW, H);
    kbBarWin.windowLevel = UIWindowLevelAlert + 2000;
    kbBarWin.backgroundColor = [UIColor secondarySystemBackgroundColor];
    kbBarWin.rootViewController = [UIViewController new];
    kbBarWin.hidden = NO;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(12, 7, 130, 30);
    [btn setTitle:@"🤖 GPT 助手" forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.45 blue:0.91 alpha:1.0];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    btn.layer.cornerRadius = 8;
    [btn addTarget:[KbBarHandler class] action:@selector(openChat) forControlEvents:UIControlEventTouchUpInside];
    [kbBarWin.rootViewController.view addSubview:btn];
}

static void hideKbBar(void) {
    if (kbBarWin) {
        kbBarWin.hidden = YES;
        kbBarWin = nil;
    }
}

static void kbShow(NSNotification *n) {
    CGRect kbFrame = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        showKbBar(kbFrame.origin.y, kbFrame.size.width);
    });
}

static void kbHide(NSNotification *n) {
    hideKbBar();
}

%ctor {
    %init;
    if (![GPTSettings isEnabled]) return;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        kbShow(n);
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        kbHide(n);
    }];
}
