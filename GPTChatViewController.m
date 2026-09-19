#import "GPTChatViewController.h"
#import "GPTSettings.h"

@interface GPTChatViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *messages;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation GPTChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"GPT 助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                             target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"清空" style:UIBarButtonItemStylePlain
               target:self action:@selector(clearAll)];

    self.messages = [NSMutableArray arrayWithArray:[GPTSettings chatHistory]];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    UIView *inputBar = [UIView new];
    inputBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    inputBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:inputBar];

    self.inputField = [UITextField new];
    self.inputField.placeholder = @"输入消息...";
    self.inputField.borderStyle = UITextBorderStyleRoundedRect;
    self.inputField.delegate = self;
    self.inputField.returnKeyType = UIReturnKeySend;
    self.inputField.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBar addSubview:self.inputField];

    UIButton *sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [sendBtn setTitle:@"发送" forState:UIControlStateNormal];
    [sendBtn addTarget:self action:@selector(sendMessage) forControlEvents:UIControlEventTouchUpInside];
    sendBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBar addSubview:sendBtn];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [inputBar addSubview:self.spinner];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:inputBar.topAnchor],

        [inputBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [inputBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [inputBar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [inputBar.heightAnchor constraintEqualToConstant:60],

        [self.inputField.leadingAnchor constraintEqualToAnchor:inputBar.leadingAnchor constant:12],
        [self.inputField.centerYAnchor constraintEqualToAnchor:inputBar.centerYAnchor constant:-10],
        [self.inputField.trailingAnchor constraintEqualToAnchor:sendBtn.leadingAnchor constant:-8],

        [sendBtn.trailingAnchor constraintEqualToAnchor:inputBar.trailingAnchor constant:-12],
        [sendBtn.centerYAnchor constraintEqualToAnchor:self.inputField.centerYAnchor],
        [sendBtn.widthAnchor constraintEqualToConstant:60],

        [self.spinner.centerXAnchor constraintEqualToAnchor:inputBar.centerXAnchor],
        [self.spinner.bottomAnchor constraintEqualToAnchor:inputBar.bottomAnchor constant:-4],
    ]];

    [self scrollToBottom];
}

- (void)close {
    if (self.dismissBlock) self.dismissBlock();
}

- (void)clearAll {
    [self.messages removeAllObjects];
    [GPTSettings clearHistory];
    [self.tableView reloadData];
}

- (void)scrollToBottom {
    if (self.messages.count == 0) return;
    NSIndexPath *last = [NSIndexPath indexPathForRow:self.messages.count - 1 inSection:0];
    [self.tableView scrollToRowAtIndexPath:last atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (void)sendMessage {
    NSString *text = [self.inputField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0) return;

    NSString *apiKey = [GPTSettings apiKey];
    if (apiKey.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"未配置"
            message:@"请先在设置中填写 OpenAI API Key" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    self.inputField.text = @"";

    [self.messages addObject:@{@"role": @"user", @"content": text}];
    [self.tableView reloadData];
    [self scrollToBottom];

    [self.spinner startAnimating];

    NSMutableArray *apiMessages = [NSMutableArray array];
    [apiMessages addObject:@{@"role": @"system", @"content": @"你是一个简洁的AI助手，用中文回答。"}];
    for (NSDictionary *msg in self.messages) {
        [apiMessages addObject:msg];
    }

    NSDictionary *body = @{
        @"model": [GPTSettings modelName],
        @"messages": apiMessages,
        @"temperature": @0.7,
        @"max_tokens": @1024
    };

    NSURL *url = [NSURL URLWithString:[GPTSettings apiBaseURL]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey]
   forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    request.timeoutInterval = 60;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.spinner stopAnimating];

            if (error) {
                [self.messages addObject:@{@"role": @"assistant",
                    @"content": [NSString stringWithFormat:@"请求失败: %@", error.localizedDescription]}];
                [self.tableView reloadData];
                [self scrollToBottom];
                return;
            }

            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];

            NSString *reply = nil;
            if (json[@"choices"] && [json[@"choices"] count] > 0) {
                reply = json[@"choices"][0][@"message"][@"content"];
            } else if (json[@"error"]) {
                reply = [NSString stringWithFormat:@"API错误: %@", json[@"error"][@"message"]];
            }

            if (reply.length > 0) {
                [self.messages addObject:@{@"role": @"assistant", @"content": reply}];
                [GPTSettings saveChatHistory:self.messages];
            } else {
                [self.messages addObject:@{@"role": @"assistant", @"content": @"未收到有效回复"}];
            }

            [self.tableView reloadData];
            [self scrollToBottom];
        });
    }];
    [task resume];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self sendMessage];
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"ChatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:15];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSDictionary *msg = self.messages[indexPath.row];
    BOOL isUser = [msg[@"role"] isEqualToString:@"user"];
    cell.textLabel.text = isUser ? [NSString stringWithFormat:@"你: %@", msg[@"content"]]
                                  : [NSString stringWithFormat:@"GPT: %@", msg[@"content"]];
    cell.textLabel.textColor = isUser ? [UIColor systemBlueColor] : [UIColor labelColor];
    return cell;
}

@end
