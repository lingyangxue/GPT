#import "GPTChatViewController.h"
#import "GPTSettings.h"

@interface GPTChatViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UIButton *inputBtn;
@property (nonatomic, strong) UIView *bar;
@end

@implementation GPTChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GPT 助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearAll)];
    self.messages = [NSMutableArray arrayWithArray:[GPTSettings chatHistory]];

    CGFloat W = self.view.bounds.size.width;
    CGFloat H = self.view.bounds.size.height;
    CGFloat safeB = self.view.safeAreaInsets.bottom;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, W, H - 60 - safeB) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    self.bar = [[UIView alloc] initWithFrame:CGRectMake(0, H - 60 - safeB, W, 60 + safeB)];
    self.bar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.bar];

    self.inputBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.inputBtn.frame = CGRectMake(12, 10, W - 130, 40);
    [self.inputBtn setTitle:@"点击输入消息..." forState:UIControlStateNormal];
    [self.inputBtn setTitleColor:[UIColor secondaryLabelColor] forState:UIControlStateNormal];
    self.inputBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    self.inputBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    self.inputBtn.backgroundColor = [UIColor systemBackgroundColor];
    self.inputBtn.layer.cornerRadius = 8;
    self.inputBtn.layer.borderColor = [UIColor separatorColor].CGColor;
    self.inputBtn.layer.borderWidth = 1;
    self.inputBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
    self.inputBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.inputBtn addTarget:self action:@selector(showInputDialog) forControlEvents:UIControlEventTouchUpInside];
    [self.bar addSubview:self.inputBtn];

    UIButton *polishBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    polishBtn.frame = CGRectMake(W - 108, 10, 48, 40);
    [polishBtn setTitle:@"润色" forState:UIControlStateNormal];
    [polishBtn addTarget:self action:@selector(showPolishDialog) forControlEvents:UIControlEventTouchUpInside];
    polishBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.bar addSubview:polishBtn];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sendBtn.frame = CGRectMake(W - 56, 10, 48, 40);
    [sendBtn setTitle:@"输入" forState:UIControlStateNormal];
    [sendBtn addTarget:self action:@selector(showInputDialog) forControlEvents:UIControlEventTouchUpInside];
    sendBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.bar addSubview:sendBtn];
}

- (void)close { if (self.dismissBlock) self.dismissBlock(); }
- (void)clearAll { [self.messages removeAllObjects]; [GPTSettings clearHistory]; [self.tableView reloadData]; }

// ============ 弹窗输入 ============
- (void)showInputDialog {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"输入消息" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入要发送的内容";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSString *t = a.textFields.firstObject.text ?: @"";
        t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length == 0) return;
        [self sendText:t];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)showPolishDialog {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"润色文本" message:@"输入要润色的文字" preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"输入原始文本";
    }];
    [a addAction:[UIAlertAction actionWithTitle:@"润色" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
        NSString *t = a.textFields.firstObject.text ?: @"";
        t = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length == 0) return;
        [self polishText:t];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

// ============ 发送 ============
- (void)sendText:(NSString *)text {
    if ([GPTSettings apiKey].length == 0) { [self alert:@"请先在设置里填 API Key"]; return; }
    [self.messages addObject:@{@"role": @"user", @"content": text}];
    [self.tableView reloadData];
    if (self.messages.count > 0) {
        NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
    }
    NSMutableArray *msgs = [NSMutableArray array];
    [msgs addObject:@{@"role": @"system", @"content": [GPTSettings systemPrompt]}];
    for (NSDictionary *m in self.messages) [msgs addObject:m];
    [self callAPI:msgs isPolish:NO];
}

- (void)polishText:(NSString *)text {
    if ([GPTSettings apiKey].length == 0) { [self alert:@"请先在设置里填 API Key"]; return; }
    NSArray *msgs = @[
        @{@"role": @"system", @"content": @"你是一个专业的中文润色助手。请对用户提供的文本进行润色，使其更通顺、优美、专业，只返回润色后的文本。"},
        @{@"role": @"user", @"content": text}
    ];
    [self callAPI:msgs isPolish:YES];
}

- (void)callAPI:(NSArray *)msgs isPolish:(BOOL)isPolish {
    NSDictionary *body = @{
        @"model": [GPTSettings modelName],
        @"messages": msgs,
        @"temperature": @([GPTSettings temperature]),
        @"max_tokens": @([GPTSettings maxTokens])
    };
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[GPTSettings apiBaseURL]]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [GPTSettings apiKey]] forHTTPHeaderField:@"Authorization"];
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
            if (isPolish) {
                UIAlertController *show = [UIAlertController alertControllerWithTitle:@"润色结果" message:reply preferredStyle:UIAlertControllerStyleAlert];
                [show addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                    [self sendText:reply];
                }]];
                [show addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:show animated:YES completion:nil];
            } else {
                [self.messages addObject:@{@"role": @"assistant", @"content": reply}];
                [GPTSettings saveChatHistory:self.messages];
                [self.tableView reloadData];
                if (self.messages.count > 0) {
                    NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
                    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
                }
            }
        });
    }] resume];
}

- (void)alert:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.messages.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *cid = @"c";
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSDictionary *m = self.messages[ip.row];
    BOOL isUser = [m[@"role"] isEqualToString:@"user"];
    cell.textLabel.text = isUser ? [NSString stringWithFormat:@"你: %@", m[@"content"]] : [NSString stringWithFormat:@"GPT: %@", m[@"content"]];
    cell.textLabel.textColor = isUser ? [UIColor systemBlueColor] : [UIColor labelColor];
    return cell;
}

@end
