#import <UIKit/UIKit.h>
#import <roothide.h>
#import <objc/runtime.h>
#import "GPTSettings.h"

static UIWindow *ballWin = nil;
static UIView *dlg = nil;
static UIView *titleBar = nil;
static UILabel *titleLbl = nil;
static UIButton *clearBtn = nil;
static UIButton *closeBtn = nil;
static UIView *inputBar = nil;
static UIButton *polishBtn = nil;
static UIButton *sendBtn = nil;
static UITableView *chatTable = nil;
static UITextField *chatInput = nil;
static NSMutableArray *msgs = nil;
static CGFloat gKbHeight = 0;

// ============ 每次都获取当前活跃的 scene ============
static UIWindowScene *activeScene(void) {
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
            return (UIWindowScene *)s;
        }
    }
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] && s.activationState != UISceneActivationStateUnattached) {
            return (UIWindowScene *)s;
        }
    }
    return nil;
}

@interface ChatBall : NSObject <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
+ (instancetype)shared;
- (void)tap;
- (void)pan:(UIPanGestureRecognizer *)g;
- (void)close;
- (void)send;
- (void)polish;
- (void)clearAll;
- (void)copyMsg:(UIButton *)sender;
@end

@implementation ChatBall
+ (instancetype)shared {
    static ChatBall *i = nil; static dispatch_once_t t;
    dispatch_once(&t, ^{ i = [[ChatBall alloc] init]; });
    return i;
}
- (UIWindow *)hostWin {
    for (UIScene *sc in [UIApplication sharedApplication].connectedScenes) {
        if (![sc isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)sc;
        for (UIWindow *w in ws.windows) if (w.isKeyWindow) return w;
    }
    return [UIApplication sharedApplication].windows.firstObject;
}
- (void)doLayout {
    if (!dlg) return;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat W = screen.size.width;
    CGFloat H = screen.size.height;
    CGFloat kbH = gKbHeight;
    CGFloat tbH = 30, ibH = 60;
    CGFloat chatH = (kbH > 0) ? 200 : 0;
    CGFloat dlgH = tbH + chatH + ibH;
    CGFloat dlgY = (kbH > 0) ? (H - kbH - dlgH) : (H - dlgH);
    dlg.frame = CGRectMake(0, dlgY, W, dlgH);
    titleBar.frame = CGRectMake(0, 0, W, tbH);
    titleLbl.frame = CGRectMake(0, 0, W, tbH);
    clearBtn.frame = CGRectMake(W - 100, 0, 50, tbH);
    closeBtn.frame = CGRectMake(W - 44, 0, 44, tbH);
    inputBar.frame = CGRectMake(0, dlgH - ibH, W, ibH);
    chatTable.frame = CGRectMake(0, tbH, W, chatH);
    CGFloat btnW = 50;
    CGFloat tfW = W - 2 * btnW - 24;
    chatInput.frame = CGRectMake(12, 10, tfW, 40);
    polishBtn.frame = CGRectMake(12 + tfW, 10, btnW, 40);
    sendBtn.frame = CGRectMake(12 + tfW + btnW, 10, btnW, 40);
}
- (void)kbShow:(NSNotification *)n {
    CGRect kb = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    gKbHeight = kb.size.height;
    [self doLayout];
}
- (void)kbHide:(NSNotification *)n {
    gKbHeight = 0;
    [self doLayout];
}
- (void)tap {
    if (dlg) return;
    // 每次打开时用当前活跃 scene 创建对话
    UIWindowScene *scene = activeScene();
    if (!scene) return;
    if (!msgs) msgs = [NSMutableArray array];
    gKbHeight = 0;

    UIWindow *host = [[UIWindow alloc] initWithWindowScene:scene];
    host.frame = [UIScreen mainScreen].bounds;
    host.windowLevel = UIWindowLevelNormal + 1;
    host.backgroundColor = [UIColor clearColor];
    host.rootViewController = [UIViewController new];
    host.rootViewController.view.frame = host.bounds;
    host.rootViewController.view.backgroundColor = [UIColor clearColor];
    [host makeKeyAndVisible];

    dlg = [[UIView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height - 90, [UIScreen mainScreen].bounds.size.width, 90)];
    dlg.backgroundColor = [UIColor systemBackgroundColor];
    dlg.layer.cornerRadius = 12;
    dlg.layer.masksToBounds = YES;
    [host.rootViewController.view addSubview:dlg];

    titleBar = [[UIView alloc] init];
    titleBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [dlg addSubview:titleBar];

    titleLbl = [[UILabel alloc] init];
    titleLbl.text = @"GPT 助手";
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.font = [UIFont boldSystemFontOfSize:13];
    titleLbl.textColor = [UIColor secondaryLabelColor];
    [titleBar addSubview:titleLbl];

    clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [clearBtn addTarget:self action:@selector(clearAll) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:clearBtn];

    closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:closeBtn];

    inputBar = [[UIView alloc] init];
    inputBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [dlg addSubview:inputBar];

    chatInput = [[UITextField alloc] init];
    chatInput.placeholder = @"输入消息...";
    chatInput.borderStyle = UITextBorderStyleRoundedRect;
    chatInput.delegate = self;
    chatInput.returnKeyType = UIReturnKeySend;
    chatInput.backgroundColor = [UIColor systemBackgroundColor];
    [inputBar addSubview:chatInput];

    polishBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [polishBtn setTitle:@"润色" forState:UIControlStateNormal];
    [polishBtn addTarget:self action:@selector(polish) forControlEvents:UIControlEventTouchUpInside];
    [inputBar addSubview:polishBtn];

    sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [sendBtn addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [inputBar addSubview:sendBtn];

    chatTable = [[UITableView alloc] init];
    chatTable.delegate = self;
    chatTable.dataSource = self;
    chatTable.rowHeight = UITableViewAutomaticDimension;
    chatTable.estimatedRowHeight = 44;
    chatTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    [dlg addSubview:chatTable];

    [self doLayout];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbHide:) name:UIKeyboardWillHideNotification object:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (chatInput) [chatInput becomeFirstResponder];
    });
}
- (void)close {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [chatInput resignFirstResponder];
    // 找到 dlg 所在的窗口并销毁
    UIWindow *host = dlg.window;
    if (dlg) { [dlg removeFromSuperview]; dlg = nil; }
    titleBar = nil; titleLbl = nil; clearBtn = nil; closeBtn = nil;
    inputBar = nil; polishBtn = nil; sendBtn = nil; chatTable = nil; chatInput = nil;
    gKbHeight = 0;
    if (host) { host.hidden = YES; host = nil; }
}
- (void)clearAll { [msgs removeAllObjects]; [chatTable reloadData]; }
- (void)send {
    NSString *t = [chatInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) return;
    chatInput.text = @"";
    [msgs addObject:@{@"role": @"user", @"content": t}];
    [chatTable reloadData];
    [self scrollBottom];
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObject:@{@"role": @"system", @"content": [GPTSettings systemPrompt]}];
    for (NSDictionary *m in msgs) [arr addObject:m];
    [self callAPI:arr polish:NO];
}
- (void)polish {
    NSString *t = [chatInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (t.length == 0) { [self alert:@"请先在输入框输入要润色的文字"]; return; }
    chatInput.text = @"";
    NSArray *arr = @[
        @{@"role": @"system", @"content": @"你是一个中文表达优化助手。用户会给你一句话，你要把这句话改得更有意思、更生动、更有魅力、更好听，但必须保持原意。只返回改写后的文本，不要添加任何解释、对话或引号。"},
        @{@"role": @"user", @"content": t}
    ];
    [self callAPI:arr polish:YES];
}
- (void)callAPI:(NSArray *)arr polish:(BOOL)polish {
    NSString *key = [GPTSettings apiKey];
    if (key.length == 0) { [self alert:@"请先在 设置 → GPT悬浮球 里填 API Key"]; return; }
    NSDictionary *body = @{
        @"model": [GPTSettings modelName],
        @"messages": arr,
        @"temperature": @([GPTSettings temperature]),
        @"max_tokens": @([GPTSettings maxTokens])
    };
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[GPTSettings apiBaseURL]]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    req.timeoutInterval = 60;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (err) { [self alert:[NSString stringWithFormat:@"网络错误: %@", err.localizedDescription]]; return; }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *reply = json[@"choices"][0][@"message"][@"content"];
            if (reply.length == 0) {
                NSString *e = json[@"error"][@"message"];
                [self alert:e.length > 0 ? e : @"未收到有效回复"];
                return;
            }
            if (polish) {
                UIWindow *host = [self hostWin];
                UIViewController *vc = host.rootViewController;
                UIAlertController *a = [UIAlertController alertControllerWithTitle:@"润色结果" message:reply preferredStyle:UIAlertControllerStyleAlert];
                [a addAction:[UIAlertAction actionWithTitle:@"使用" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                    chatInput.text = reply;
                    [chatInput becomeFirstResponder];
                }]];
                [a addAction:[UIAlertAction actionWithTitle:@"直接发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                    [self sendText:reply];
                }]];
                [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                [vc presentViewController:a animated:YES completion:nil];
            } else {
                [msgs addObject:@{@"role": @"assistant", @"content": reply}];
                [chatTable reloadData];
                [self scrollBottom];
            }
        });
    }] resume];
}
- (void)sendText:(NSString *)text {
    [msgs addObject:@{@"role": @"user", @"content": text}];
    [chatTable reloadData];
    [self scrollBottom];
    NSMutableArray *arr = [NSMutableArray array];
    [arr addObject:@{@"role": @"system", @"content": [GPTSettings systemPrompt]}];
    for (NSDictionary *m in msgs) [arr addObject:m];
    [self callAPI:arr polish:NO];
}
- (void)scrollBottom {
    if (msgs.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:msgs.count - 1 inSection:0];
    [chatTable scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}
- (void)alert:(NSString *)m {
    UIWindow *host = [self hostWin];
    UIViewController *vc = host.rootViewController;
    if (!vc) return;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"提示" message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return msgs.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cid];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UILabel *lbl = [[UILabel alloc] init];
        lbl.numberOfLines = 0;
        lbl.font = [UIFont systemFontOfSize:15];
        lbl.tag = 9999;
        lbl.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:lbl];
        UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [copyBtn setTitle:@"📋" forState:UIControlStateNormal];
        copyBtn.titleLabel.font = [UIFont systemFontOfSize:16];
        copyBtn.tag = 9998;
        copyBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:copyBtn];
        [NSLayoutConstraint activateConstraints:@[
            [lbl.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [lbl.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [lbl.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
            [lbl.trailingAnchor constraintEqualToAnchor:copyBtn.leadingAnchor constant:-6],
            [copyBtn.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-10],
            [copyBtn.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [copyBtn.widthAnchor constraintEqualToConstant:36],
            [copyBtn.heightAnchor constraintEqualToConstant:36],
        ]];
    }
    UILabel *lbl = [cell.contentView viewWithTag:9999];
    UIButton *copyBtn = [cell.contentView viewWithTag:9998];
    NSDictionary *m = msgs[ip.row];
    BOOL u = [m[@"role"] isEqualToString:@"user"];
    lbl.text = u ? [NSString stringWithFormat:@"你: %@", m[@"content"]] : [NSString stringWithFormat:@"GPT: %@", m[@"content"]];
    lbl.textColor = u ? [UIColor systemBlueColor] : [UIColor labelColor];
    [copyBtn removeTarget:nil action:nil forControlEvents:UIControlEventAllEvents];
    objc_setAssociatedObject(copyBtn, "row", @(ip.row), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [copyBtn addTarget:self action:@selector(copyMsg:) forControlEvents:UIControlEventTouchUpInside];
    return cell;
}
- (void)copyMsg:(UIButton *)sender {
    NSNumber *r = objc_getAssociatedObject(sender, "row");
    if (!r) return;
    NSInteger row = r.integerValue;
    if (row < 0 || row >= (NSInteger)msgs.count) return;
    NSDictionary *m = msgs[row];
    NSString *text = m[@"content"];
    if (text.length == 0) return;
    [UIPasteboard generalPasteboard].string = text;
    [self alert:@"已复制到剪贴板"];
}
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self send]; return YES; }
- (void)pan:(UIPanGestureRecognizer *)g {
    UIView *v = g.view; UIWindow *w = v.window;
    CGPoint t = [g translationInView:w];
    CGPoint c = w.center;
    c.x += t.x; c.y += t.y;
    w.center = c;
    [g setTranslation:CGPointZero inView:w];
    if (g.state == UIGestureRecognizerStateEnded) {
        CGSize sc = [UIScreen mainScreen].bounds.size;
        CGFloat sz = [GPTSettings ballSize];
        CGFloat x = w.frame.origin.x, y = w.frame.origin.y;
        if (x < sc.width / 2) { x = 10; } else { x = sc.width - sz - 10; }
        if (y < 60) y = 60;
        if (y > sc.height - sz - 60) y = sc.height - sz - 60;
        [UIView animateWithDuration:0.25 animations:^{ w.frame = CGRectMake(x, y, sz, sz); }];
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setFloat:x forKey:@"ballX"]; [d setFloat:y forKey:@"ballY"]; [d synchronize];
    }
}
@end

// ============ 悬浮球 ============
static void makeBall(void) {
    if (ballWin) return;
    UIWindowScene *s = activeScene();
    if (!s) return;  // scene 还没就绪，等下一次 watchdog 检查

    CGFloat sz = [GPTSettings ballSize];
    CGFloat alpha = [GPTSettings ballOpacity];
    ballWin = [[UIWindow alloc] initWithWindowScene:s];
    ballWin.frame = CGRectMake(0, 0, sz, sz);
    ballWin.windowLevel = UIWindowLevelStatusBar + 100;
    ballWin.backgroundColor = [UIColor clearColor];
    ballWin.rootViewController = [UIViewController new];
    ballWin.rootViewController.view.frame = ballWin.bounds;

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
        b.titleLabel.font = [UIFont boldSystemFontOfSize:MAX(10, sz * 0.3)];
    }
    [b addTarget:[ChatBall shared] action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[ChatBall shared] action:@selector(pan:)];
    [b addGestureRecognizer:pan];
    [ballWin.rootViewController.view addSubview:b];

    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    CGFloat x = [d floatForKey:@"ballX"];
    CGFloat y = [d floatForKey:@"ballY"];
    if (x == 0 && y == 0) {
        CGSize sc = [UIScreen mainScreen].bounds.size;
        x = sc.width - sz - 20; y = sc.height / 2;
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

// ============ 通知 ============
static void onSettingsChanged(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
    dispatch_async(dispatch_get_main_queue(), ^{ removeBall(); makeBall(); });
}

static void onActive(NSNotification *n) {
    dispatch_async(dispatch_get_main_queue(), ^{ removeBall(); makeBall(); });
}

static void watchdogTick(void) {
    // 每次都重新判断 scene，不对就重建
    UIWindowScene *s = activeScene();
    if (!s) return;
    if (ballWin && ballWin.windowScene == s && !ballWin.hidden) return;
    removeBall();
    makeBall();
}

%ctor {
    %init;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
        onActive(n);
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        makeBall();
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
            watchdogTick();
        }];
    });

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, onSettingsChanged, CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
