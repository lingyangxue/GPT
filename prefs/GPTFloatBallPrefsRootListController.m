#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSLinkCell.h>
#import <spawn.h>
#import <UIKit/UIKit.h>

#define kDomain    @"com.yourname.gptfloatball"
#define kPlistPath @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist"

// ================= plist 读写 =================
static NSMutableDictionary *readPrefs(void) {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:kPlistPath];
    return d ?: [NSMutableDictionary new];
}
static void writePrefs(NSDictionary *d) {
    [d writeToFile:kPlistPath atomically:YES];
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.yourname.gptfloatball/settingsChanged"),
        NULL, NULL, YES);
}
static NSString *strOr(NSString *s, NSString *fb) {
    return (s && s.length > 0) ? s : fb;
}

// ================= 自定义 LinkCell：右侧显示字符串 =================
@interface GPTLinkCell : PSLinkCell
@end
@implementation GPTLinkCell
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    NSString *right = [specifier propertyForKey:@"rightDetail"];
    if (right.length == 0) { self.accessoryView = nil; return; }

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 150, 30)];
    lbl.text = right;
    lbl.textColor = [UIColor secondaryLabelColor];
    lbl.font = [UIFont systemFontOfSize:17];
    lbl.textAlignment = NSTextAlignmentRight;
    [box addSubview:lbl];

    UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(155, 3, 24, 24)];
    if (@available(iOS 13.0, *)) {
        iv.image = [UIImage systemImageNamed:@"chevron.right"];
        iv.tintColor = [UIColor tertiaryLabelColor];
    }
    iv.contentMode = UIViewContentModeScaleAspectFit;
    [box addSubview:iv];

    self.accessoryView = box;
}
@end

// ================= 1. API Key =================
@interface GPTSubAPIKeyController : PSListController
@end
@implementation GPTSubAPIKeyController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *a = [NSMutableArray array];
        PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"输入你的 API Key"];
        [g setProperty:@"DeepSeek 与 OpenAI 都是 sk- 开头。改完自动保存。" forKey:@"footerText"];
        [a addObject:g];

        PSSpecifier *edit = [PSSpecifier preferenceSpecifierNamed:@"API Key"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [edit setProperty:kDomain forKey:@"defaults"];
        [edit setProperty:@"apiKey"  forKey:@"key"];
        [a addObject:edit];

        PSSpecifier *base = [PSSpecifier preferenceSpecifierNamed:@"API 地址"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [base setProperty:kDomain forKey:@"defaults"];
        [base setProperty:@"apiBaseURL" forKey:@"key"];
        [a addObject:base];

        _specifiers = a;
    }
    return _specifiers;
}
@end

// ================= 2. 角色预设 =================
@interface GPTSubRoleController : PSListController
@end
@implementation GPTSubRoleController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *a = [NSMutableArray array];
        PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"选择角色预设"];
        [g setProperty:@"作为 system 消息注入每次对话" forKey:@"footerText"];
        [a addObject:g];

        NSArray *roles = @[
            @[@"默认助手", @"你是一个简洁的AI助手，用中文回答。"],
            @[@"翻译",     @"你是一个专业翻译，把用户输入翻译成英文（输入是英文则翻译成中文）。"],
            @[@"编程",     @"你是一个资深程序员，回答技术问题简洁准确，给出代码示例。"],
            @[@"写作",     @"你是一个中文写作助手，帮用户润色、改写、扩写文本。"]
        ];
        for (NSArray *r in roles) {
            PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:r[0]
                                                            target:self
                                                               set:@selector(setRole:specifier:)
                                                               get:@selector(getRole:)
                                                            detail:nil cell:PSListItemCell edit:nil];
            [s setProperty:r[1] forKey:@"rolePrompt"];
            [a addObject:s];
        }

        PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"自定义角色"];
        [a addObject:g2];
        PSSpecifier *edit = [PSSpecifier preferenceSpecifierNamed:@"systemPrompt"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [edit setProperty:kDomain forKey:@"defaults"];
        [edit setProperty:@"systemPrompt" forKey:@"key"];
        [a addObject:edit];

        _specifiers = a;
    }
    return _specifiers;
}
- (id)getRole:(PSSpecifier *)s {
    NSString *cur = strOr(readPrefs()[@"systemPrompt"], @"");
    return [cur isEqualToString:[s propertyForKey:@"rolePrompt"]] ? @YES : @NO;
}
- (void)setRole:(id)v specifier:(PSSpecifier *)s {
    NSMutableDictionary *d = readPrefs();
    d[@"systemPrompt"] = [s propertyForKey:@"rolePrompt"];
    writePrefs(d);
    [self reloadSpecifiers];
}
@end

// ================= 3. 模型 =================
@interface GPTSubModelController : PSListController
@end
@implementation GPTSubModelController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *a = [NSMutableArray array];
        PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"选择模型"];
        [g setProperty:@"点选预设，或在下方自定义输入" forKey:@"footerText"];
        [a addObject:g];

        NSArray *models = @[@"deepseek-chat", @"deepseek-reasoner",
                            @"gpt-4o-mini", @"gpt-4o", @"gpt-3.5-turbo"];
        for (NSString *m in models) {
            PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:m
                                                            target:self
                                                               set:@selector(setModel:specifier:)
                                                               get:@selector(getModel:)
                                                            detail:nil cell:PSListItemCell edit:nil];
            [s setProperty:m forKey:@"modelName"];
            [a addObject:s];
        }

        PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"自定义模型"];
        [a addObject:g2];
        PSSpecifier *edit = [PSSpecifier preferenceSpecifierNamed:@"模型名"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [edit setProperty:kDomain forKey:@"defaults"];
        [edit setProperty:@"modelName" forKey:@"key"];
        [a addObject:edit];

        _specifiers = a;
    }
    return _specifiers;
}
- (id)getModel:(PSSpecifier *)s {
    NSString *cur = strOr(readPrefs()[@"modelName"], @"");
    return [cur isEqualToString:[s propertyForKey:@"modelName"]] ? @YES : @NO;
}
- (void)setModel:(id)v specifier:(PSSpecifier *)s {
    NSMutableDictionary *d = readPrefs();
    d[@"modelName"] = [s propertyForKey:@"modelName"];
    writePrefs(d);
    [self reloadSpecifiers];
}
@end

// ================= 4. 使用场景 / 温度 =================
@interface GPTSubTempController : PSListController
@end
@implementation GPTSubTempController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *a = [NSMutableArray array];
        PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"选择使用场景"];
        [g setProperty:@"值越高回答越有创意，越低越严谨（0.0 ~ 2.0）" forKey:@"footerText"];
        [a addObject:g];

        NSArray *ps = @[
            @[@"严谨 0.3", @"0.3"],
            @[@"平衡 1.0", @"1.0"],
            @[@"创意 1.3", @"1.3"],
            @[@"非常创意 1.8", @"1.8"]
        ];
        for (NSArray *p in ps) {
            PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:p[0]
                                                            target:self
                                                               set:@selector(setTemp:specifier:)
                                                               get:@selector(getTemp:)
                                                            detail:nil cell:PSListItemCell edit:nil];
            [s setProperty:p[1] forKey:@"tempValue"];
            [a addObject:s];
        }

        PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"自定义"];
        [a addObject:g2];
        PSSpecifier *edit = [PSSpecifier preferenceSpecifierNamed:@"温度"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [edit setProperty:kDomain forKey:@"defaults"];
        [edit setProperty:@"temperature" forKey:@"key"];
        [a addObject:edit];

        _specifiers = a;
    }
    return _specifiers;
}
- (id)getTemp:(PSSpecifier *)s {
    NSString *cur = strOr(readPrefs()[@"temperature"], @"");
    return [cur isEqualToString:[s propertyForKey:@"tempValue"]] ? @YES : @NO;
}
- (void)setTemp:(id)v specifier:(PSSpecifier *)s {
    NSMutableDictionary *d = readPrefs();
    d[@"temperature"] = [s propertyForKey:@"tempValue"];
    writePrefs(d);
    [self reloadSpecifiers];
}
@end

// ================= 5. 输出 tokens =================
@interface GPTSubTokensController : PSListController
@end
@implementation GPTSubTokensController
- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *a = [NSMutableArray array];
        PSSpecifier *g = [PSSpecifier groupSpecifierWithName:@"选择最大输出 tokens"];
        [g setProperty:@"值越大回复越长，也越消耗额度" forKey:@"footerText"];
        [a addObject:g];

        for (NSString *v in @[@"512", @"1024", @"2048", @"4096", @"8192"]) {
            PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:v
                                                            target:self
                                                               set:@selector(setTk:specifier:)
                                                               get:@selector(getTk:)
                                                            detail:nil cell:PSListItemCell edit:nil];
            [s setProperty:v forKey:@"tkValue"];
            [a addObject:s];
        }

        PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"自定义"];
        [a addObject:g2];
        PSSpecifier *edit = [PSSpecifier preferenceSpecifierNamed:@"tokens"
                                                            target:self
                                                               set:@selector(setPreferenceValue:specifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil cell:PSEditTextCell edit:nil];
        [edit setProperty:kDomain forKey:@"defaults"];
        [edit setProperty:@"maxTokens" forKey:@"key"];
        [a addObject:edit];

        _specifiers = a;
    }
    return _specifiers;
}
- (id)getTk:(PSSpecifier *)s {
    NSString *cur = strOr(readPrefs()[@"maxTokens"], @"");
    return [cur isEqualToString:[s propertyForKey:@"tkValue"]] ? @YES : @NO;
}
- (void)setTk:(id)v specifier:(PSSpecifier *)s {
    NSMutableDictionary *d = readPrefs();
    d[@"maxTokens"] = [s propertyForKey:@"tkValue"];
    writePrefs(d);
    [self reloadSpecifiers];
}
@end

// ===================== 主控制器 =====================
@interface GPTFloatBallPrefsRootListController : PSListController
@end

@implementation GPTFloatBallPrefsRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GPT悬浮球";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

- (NSArray *)specifiers {
    if (!_specifiers) _specifiers = [self buildSpecifiers];
    return _specifiers;
}

- (NSArray *)buildSpecifiers {
    NSMutableArray *a = [NSMutableArray array];
    NSDictionary *p = readPrefs();

    // 顶部
    PSSpecifier *g0 = [PSSpecifier groupSpecifierWithName:@"DeepSeek 探索未至之境"];
    [g0 setProperty:@"本功能对接官方 API，需到官方购买额度才能正常使用" forKey:@"footerText"];
    [a addObject:g0];

    // API key
    NSString *apiKey = p[@"apiKey"];
    [a addObject:[self link:@"API key"
                     detail:[GPTSubAPIKeyController class]
                       right:(apiKey.length > 0 ? @"已配置" : @"未配置")]];

    // 角色预设
    NSString *prompt = p[@"systemPrompt"];
    [a addObject:[self link:@"AI 角色预设"
                     detail:[GPTSubRoleController class]
                       right:(prompt.length > 0 ? @"已配置" : @"默认助手")]];

    // 模型
    NSString *m = p[@"modelName"]; if (m.length == 0) m = @"deepseek-chat";
    [a addObject:[self link:@"AI 模型" detail:[GPTSubModelController class] right:m]];

    // 温度
    NSString *t = p[@"temperature"]; if (t.length == 0) t = @"1.0";
    [a addObject:[self link:@"使用场景" detail:[GPTSubTempController class] right:t]];

    // tokens
    NSString *tk = p[@"maxTokens"]; if (tk.length == 0) tk = @"1024";
    [a addObject:[self link:@"限制输出 tokens" detail:[GPTSubTokensController class] right:tk]];

    // 按钮组
    [a addObject:[PSSpecifier groupSpecifierWithName:nil]];
    [a addObject:[self button:@"查询额度" action:@selector(doQueryBalance)]];
    [a addObject:[self button:@"调用日志" action:@selector(doShowLogs)]];
    [a addObject:[self button:@"点击测试" action:@selector(doTestCall)]];

    // 总开关
    PSSpecifier *g2 = [PSSpecifier groupSpecifierWithName:@"开关"];
    [a addObject:g2];
    PSSpecifier *en = [PSSpecifier preferenceSpecifierNamed:@"启用悬浮球"
                                                     target:self
                                                        set:@selector(setPreferenceValue:specifier:)
                                                        get:@selector(readPreferenceValue:)
                                                     detail:nil cell:PSSwitchCell edit:nil];
    [en setProperty:kDomain forKey:@"defaults"];
    [en setProperty:@"enabled" forKey:@"key"];
    [a addObject:en];

    return a;
}

- (PSSpecifier *)link:(NSString *)label detail:(Class)cls right:(NSString *)right {
    PSSpecifier *s = [PSSpecifier preferenceSpecifierNamed:label
                                                    target:self set:nil get:nil
                                                    detail:cls cell:PSLinkCell edit:nil];
    [s setProperty:[GPTLinkCell class] forKey:@"cellClass"];
    [s setProperty:right ?: @"" forKey:@"rightDetail"];
    return s;
}

- (PSSpecifier *)button:(NSString *)label action:(SEL)action {
    return [PSSpecifier preferenceSpecifierNamed:label
                                          target:self set:action get:nil
                                          detail:nil cell:PSButtonCell edit:nil];
}

// ===== 查询额度 =====
- (void)doQueryBalance {
    NSString *key = readPrefs()[@"apiKey"];
    if (key.length == 0) { [self alert:@"请先配置 API Key"]; return; }
    NSString *pfx = key.length > 8 ? [key substringToIndex:8] : key;
    [self alert:[NSString stringWithFormat:
        @"额度查询请到服务商官网查询。\n\n当前 Key 前 8 位：\n%@...", pfx]];
}

// ===== 调用日志 =====
- (void)doShowLogs {
    NSArray *hist = readPrefs()[@"chatHistory"];
    if (hist.count == 0) { [self alert:@"暂无调用记录"]; return; }
    NSMutableString *s = [NSMutableString string];
    NSInteger start = MAX(0, (NSInteger)hist.count - 10);
    for (NSInteger i = start; i < (NSInteger)hist.count; i++) {
        NSDictionary *m = hist[i];
        [s appendFormat:@"[%@] %@\n\n", m[@"role"], m[@"content"]];
    }
    [self alert:s];
}

// ===== 点击测试 =====
- (void)doTestCall {
    NSString *key = readPrefs()[@"apiKey"];
    if (key.length == 0) { [self alert:@"请先配置 API Key"]; return; }

    NSDictionary *p = readPrefs();
    NSString *base  = strOr(p[@"apiBaseURL"], @"https://api.openai.com/v1/chat/completions");
    NSString *model = strOr(p[@"modelName"],  @"gpt-4o-mini");

    NSDictionary *body = @{
        @"model": model,
        @"messages": @[@{@"role": @"user", @"content": @"你好"}],
        @"max_tokens": @64
    };
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:base]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    req.timeoutInterval = 30;

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"测试中..."
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (err) { [self alert:[NSString stringWithFormat:@"网络错误: %@", err.localizedDescription]]; return; }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSString *reply = json[@"choices"][0][@"message"][@"content"];
                if (reply) {
                    [self alert:[NSString stringWithFormat:@"✅ 测试成功\n\n模型: %@\n\n回复: %@", model, reply]];
                } else if (json[@"error"]) {
                    [self alert:[NSString stringWithFormat:@"❌ API 错误\n\n%@", json[@"error"][@"message"]]];
                } else {
                    [self alert:@"❌ 未知响应"];
                }
            }];
        });
    }] resume];
}

- (void)alert:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"GPT悬浮球"
        message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

@end
