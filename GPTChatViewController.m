#import "GPTChatViewController.h"
#import "GPTSettings.h"

@interface GPTChatViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UITextField *inputField;
@end

@implementation GPTChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GPT 助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"清空" style:UIBarButtonItemStylePlain target:self action:@selector(clearAll)];
    self.messages = [NSMutableArray arrayWithArray:[GPTSettings chatHistory]];

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];

    UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 60, self.view.bounds.size.width, 60)];
    bar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    bar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:bar];

    self.inputField = [[UITextField alloc] initWithFrame:CGRectMake(12, 10, self.view.bounds.size.width - 130, 40)];
    self.inputField.placeholder = @"输入消息...";
    self.inputField.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField.delegate = self;
    self.inputField.returnKeyType = UIReturnKeySend;
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bar addSubview:self.inputField];

    UIButton *polishBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    polishBtn.frame = CGRectMake(self.view.bounds.size.width - 108, 10, 48, 40);
    [polishBtn setTitle:@"润色" forState:UIControlStateNormal];
    [polishBtn addTarget:self action:@selector(polishText) forControlEvents:UIControlEventTouchUpInside];
    polishBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [bar addSubview:polishBtn];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    sendBtn.frame = CGRectMake(self.view.bounds.size.width - 56, 10, 48, 40);
    [sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [sendBtn addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    sendBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [bar addSubview:sendBtn];
}

- (void)close { if (self.dismissBlock) self.dismissBlock(); }
- (void)clearAll { [self.messages removeAllObjects]; [GPTSettings clearHistory]; [self.tableView reloadData]; }

- (void)polishText {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    NSString *key = [GPTSettings apiKey];
    if (key.length == 0) { [self alert:@"请先在设置里填 API Key"]; return; }
    self.inputField.text = @"";
    NSArray *msgs = @[
        @{@"role": @"system", @"content": @"你是一个专业的中文润色助手。请对用户提供的文本进行润色，使其更通顺、优美、专业，只返回润色后的文本，不要添加任何解释或对话。"},
        @{@"role": @"user", @"content": text}
    ];
    [self callAPI:msgs isPolish:YES];
}

- (void)sendMessage {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;
    NSString *key = [GPTSettings apiKey];
    if (key.length == 0) { [self alert:@"请先在设置里填 API Key"]; return; }
    self.inputField.text = @"";
    [self.messages addObject:@{@"role": @"user", @"content": text}];
    [self.tableView reloadData];

    NSMutableArray *msgs = [NSMutableArray array];
    [msgs addObject:@{@"role": @"system", @"content": [GPTSettings systemPrompt]}];
    for (NSDictionary *m in self.messages) [msgs addObject:m];
    [self callAPI:msgs isPolish:NO];
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
                self.inputField.text = reply;
                [self.inputField becomeFirstResponder];
            } else {
                [self.messages addObject:@{@"role": @"assistant", @"content": reply}];
                [GPTSettings saveChatHistory:self.messages];
                [self.tableView reloadData];
                NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
                [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
            }
        });
    }] resume];
}

- (void)alert:(NSString *)msg {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self sendMessage]; return YES; }

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
