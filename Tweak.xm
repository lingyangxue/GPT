#import <UIKit/UIKit.h>
#import <roothide.h>
#import "GPTSettings.h"

static UIWindow *ballWin = nil;
static UIButton *overlay = nil;
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

@interface ChatBall : NSObject <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
+ (instancetype)shared;
- (void)tap;
- (void)pan:(UIPanGestureRecognizer *)g;
- (void)close;
- (void)send;
- (void)polish;
- (void)clearAll;
- (void)relayout:(CGFloat)kbH;
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

// ============ 根据键盘高度重排所有元素 ============
- (void)relayout:(CGFloat)kbH {
    if (!dlg) return;
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat W = screen.size.width;
    CGFloat H = screen.size.height;

    CGFloat scale = [GPTSettings windowScale];
    CGFloat availH = H - kbH;
    CGFloat topY = 50;                              // 顶部留出状态栏
    CGFloat maxH = availH - topY - 10;
    if (maxH < 240) maxH = 240;

    CGFloat dialogH = MIN(H * scale, maxH);
    CGFloat dialogW = W * scale;
    CGFloat dialogX = (W - dialogW) / 2;
    CGFloat dialogY = topY + (maxH - dialogH) / 2;
    if (dialogY < topY) dialogY = topY;

    CGRect df = CGRectMake(dialogX, dialogY, dialogW, dialogH);
    if (kbH > 0) {
        [UIView animateWithDuration:0.25 animations:^{ dlg.frame = df; }];
    } else {
        dlg.frame = df;
    }

    CGFloat tbH = 50, cbH = 46, ibH = 60;
    titleBar.frame = CGRectMake(0, 0, dialogW, tbH);
    titleLbl.frame = CGRectMake(0, 0, dialogW, tbH);
    clearBtn.frame = CGRectMake(dialogW - 60, 5, 50, 40);
    closeBtn.frame = CGRectMake(0, dialogH - cbH, dialogW, cbH);
    inputBar.frame = CGRectMake(0, dialogH - cbH - ibH, dialogW, ibH);

    CGFloat btnW = 50;
    CGFloat tfW = dialogW - 2 * btnW - 24;
    chatInput.frame = CGRectMake(12, 10, tfW, 40);
    polishBtn.frame = CGRectMake(12 + tfW, 10, btnW, 40);
    sendBtn.frame = CGRectMake(12 + tfW + btnW, 10, btnW, 40);

    chatTable.frame = CGRectMake(0, tbH, dialogW, dialogH - tbH - cbH - ibH);
}

// ============ 键盘通知 ============
- (void)kbShow:(NSNotification *)n {
    CGRect kb = [n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [self relayout:kb.size.height];
}

- (void)kbHide:(NSNotification *)n {
    [self relayout:0];
}

// ============ 打开对话 ============
- (void)tap {
    if (overlay) return;
    UIWindow *host = [self hostWin];
    if (!host) return;
    CGRect screen = host.bounds;
    if (!msgs) msgs = [NSMutableArray array];

    // 背景（可点击关闭）
    overlay = [UIButton buttonWithType:UIButtonTypeCustom];
    overlay.frame = screen;
    overlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    [overlay addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [host addSubview:overlay];

    // 对话框
    dlg = [[UIView alloc] init];
    dlg.backgroundColor = [UIColor systemBackgroundColor];
    dlg.layer.cornerRadius = 16;
    dlg.layer.masksToBounds = YES;
    [overlay addSubview:dlg];

    // 标题栏
    titleBar = [[UIView alloc] init];
    titleBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [dlg addSubview:titleBar];

    titleLbl = [[UILabel alloc] init];
    titleLbl.text = @"GPT 助手";
    titleLbl.textAlignment = NSTextAlignmentCenter;
    titleLbl.font = [UIFont boldSystemFontOfSize:17];
    [titleBar addSubview:titleLbl];

    clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [clearBtn setTitle:@"清空" forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(clearAll) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:clearBtn];

    // 底部关闭按钮
    closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setTitle:@"关 闭" forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    closeBtn.backgroundColor = [UIColor systemRedColor];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
    [dlg addSubview:closeBtn];

    // 输入栏
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

    // 对话列表
    chatTable = [[UITableView alloc] init];
    chatTable.delegate = self;
    chatTable.dataSource = self;
    chatTable.rowHeight = UITableViewAutomaticDimension;
    chatTable.estimatedRowHeight = 50;
    chatTable.separatorStyle = UITableViewCellSeparatorStyleNone;
    [dlg addSubview:chatTable];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbHide:) name:UIKeyboardWillHideNotification object:nil];

    [self relayout:0];  // 先按无键盘布局
    [chatInput becomeFirstResponder];
}

- (void)close {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [chatInput resignFirstResponder];
    if (overlay) { [overlay removeFromSuperview]; overlay = nil; }
    dlg = nil; titleBar = nil; titleLbl = nil; clearBtn = nil; closeBtn = nil;
    inputBar = nil; polishBtn = nil; sendBtn = nil; chatTable = nil; chatInput = nil;
}

- (void)clearAll {
    [msgs removeAllObjects];
    [chatTable reloadData];
}

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
    if (t.length == 0) return;
    chatInput.text = @"";
    NSArray *arr = @[
        @{@"role": @"system", @"content": @"你是一个专业的中文润色助手。只返回润色后的文本。"},
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
                chatInput.text = reply;
                [chatInput becomeFirstResponder];
            } else {
                [msgs addObject:@{@"role": @"assistant", @"content": reply}];
                [chatTable reloadData];
                [self scrollBottom];
            }
        });
    }] resume];
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
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSDictionary *m = msgs[ip.row];
    BOOL u = [m[@"role"] isEqualToString:@"user"];
    cell.textLabel.text = u ? [NSString stringWithFormat:@"你: %@", m[@"content"]] : [NSString stringWithFormat:@"GPT: %@", m[@"content"]];
    cell.textLabel.textColor = u ? [UIColor systemBlueColor] : [UIColor labelColor];
    return cell;
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

static void makeBall(void) {
    if (ballWin) return;
    UIWindowScene *s = nil;
    for (UIScene *x in [UIApplication sharedApplication].connectedScenes) {
        if ([x isKindOfClass:[UIWindowScene class]]) { s = (UIWindowScene *)x; break; }
    }
    if (!s) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1500000000), dispatch_get_main_queue(), ^{ makeBall(); });
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
    if (ballWin) { ballWin.hidden = YES; ballWin = nil; }
}

static void onSettingsChanged(CFNotificationCenterRef c, void *o, CFStringRef n, const void *obj, CFDictionaryRef u) {
    dispatch_async(dispatch_get_main_queue(), ^{ removeBall(); makeBall(); });
}

%ctor {
    %init;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ makeBall(); });
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, onSettingsChanged, CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
