#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#define kPrefsDomain @"com.yourname.gptfloatball"
#define kPrefsPlist @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist"
#define kIconPath @"/var/mobile/Library/Preferences/GPTFloatBall_icon.png"

@interface GPTFloatBallPrefsRootListController : PSListController <UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@end

@implementation GPTFloatBallPrefsRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithTitle:@"应用更改" style:UIBarButtonItemStyleDone target:self action:@selector(apply)];
}

- (void)apply {
    [self.view endEditing:YES];
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];
    [ud synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功" message:@"设置已生效，悬浮球已自动刷新。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: @{};
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return nil;
    id val = prefs[key];
    if (!val) val = [specifier propertyForKey:@"default"];
    return val;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: [NSMutableDictionary new];
    prefs[key] = value;
    [prefs writeToFile:kPrefsPlist atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
}

- (void)fetchModelList {
    [self.view endEditing:YES];
    NSUserDefaults *ud = [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];
    [ud synchronize];
    NSString *apiKey = [ud stringForKey:@"apiKey"];
    NSString *baseURL = [ud stringForKey:@"apiBaseURL"];
    if (!baseURL || baseURL.length == 0) baseURL = @"https://api.deepseek.com/v1/chat/completions";
    if (!apiKey || apiKey.length == 0) { [self showAlert:@"请先填写 API Key"]; return; }

    NSString *modelsURL = baseURL;
    if ([modelsURL containsString:@"/chat/completions"]) {
        modelsURL = [modelsURL stringByReplacingOccurrencesOfString:@"/chat/completions" withString:@"/models"];
    } else if ([modelsURL hasSuffix:@"/"]) {
        modelsURL = [modelsURL stringByAppendingString:@"models"];
    } else {
        modelsURL = [modelsURL stringByAppendingString:@"/models"];
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:modelsURL]];
    req.HTTPMethod = @"GET";
    [req setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    req.timeoutInterval = 15;

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"获取中..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) { [self showAlert:[NSString stringWithFormat:@"网络错误: %@", error.localizedDescription]]; return; }
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *dataArray = json[@"data"];
                if (!dataArray || ![dataArray isKindOfClass:[NSArray class]]) { [self showAlert:@"获取失败，请检查 API 地址和 Key"]; return; }

                UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择模型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                for (NSDictionary *model in dataArray) {
                    NSString *modelID = model[@"id"];
                    if (modelID.length == 0) continue;
                    [sheet addAction:[UIAlertAction actionWithTitle:modelID style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                        NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: [NSMutableDictionary new];
                        p[@"modelName"] = modelID;
                        [p writeToFile:kPrefsPlist atomically:YES];
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
                        [self reloadSpecifiers];
                    }]];
                }
                [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                sheet.popoverPresentationController.sourceView = self.view;
                sheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
                [self presentViewController:sheet animated:YES completion:nil];
            }];
        });
    }] resume];
}

- (void)showAlert:(NSString *)msg {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)pickImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    picker.allowsEditing = YES;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:^{
        if (!image) return;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(128, 128), NO, 1.0);
        [image drawInRect:CGRectMake(0, 0, 128, 128)];
        UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *data = UIImagePNGRepresentation(scaled);
        [data writeToFile:kIconPath atomically:YES];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: [NSMutableDictionary new];
        dict[@"iconPath"] = kIconPath;
        [dict writeToFile:kPrefsPlist atomically:YES];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
        [self showAlert:@"图标已更新，悬浮球会自动刷新"];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)clearHistory {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: [NSMutableDictionary new];
    [dict removeObjectForKey:@"chatHistory"];
    [dict writeToFile:kPrefsPlist atomically:YES];
    [self apply];
}

@end
