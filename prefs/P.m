#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

#define kPrefsDomain @"com.yourname.gptfloatball"
#define kPlist @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist"
#define kIcon @"/var/mobile/Library/Preferences/GPTFloatBall_icon.png"

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
    [[[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain] synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"已保存" message:@"悬浮球已自动刷新。" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (id)readPreferenceValue:(PSSpecifier *)s {
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPlist] ?: @{};
    NSString *k = [s propertyForKey:@"key"];
    if (!k) return nil;
    id v = p[k];
    if (!v) v = [s propertyForKey:@"default"];
    return v;
}

- (void)setPreferenceValue:(id)v specifier:(PSSpecifier *)s {
    NSString *k = [s propertyForKey:@"key"];
    if (!k) return;
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:kPlist] ?: [NSMutableDictionary new];
    p[k] = v;
    [p writeToFile:kPlist atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
}

- (void)fetchModelList {
    [self.view endEditing:YES];
    NSDictionary *p = [NSDictionary dictionaryWithContentsOfFile:kPlist] ?: @{};
    NSString *key = p[@"apiKey"] ?: @"";
    NSString *base = p[@"apiBaseURL"] ?: @"https://api.deepseek.com/v1/chat/completions";
    if (key.length == 0) { [self tip:@"请先填 API Key"]; return; }
    NSString *u = [base stringByReplacingOccurrencesOfString:@"/chat/completions" withString:@"/models"];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:u]];
    [r setValue:[NSString stringWithFormat:@"Bearer %@", key] forHTTPHeaderField:@"Authorization"];
    UIAlertController *load = [UIAlertController alertControllerWithTitle:@"获取中..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:load animated:YES completion:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData *d, NSURLResponse *rs, NSError *e) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [load dismissViewControllerAnimated:YES completion:^{
                if (e) { [self tip:e.localizedDescription]; return; }
                NSDictionary *j = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                NSArray *arr = j[@"data"];
                if (![arr isKindOfClass:[NSArray class]]) { [self tip:@"获取失败"]; return; }
                UIAlertController *s = [UIAlertController alertControllerWithTitle:@"选择模型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
                for (NSDictionary *m in arr) {
                    NSString *mid = m[@"id"];
                    if (mid.length == 0) continue;
                    [s addAction:[UIAlertAction actionWithTitle:mid style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                        NSMutableDictionary *pp = [NSMutableDictionary dictionaryWithContentsOfFile:kPlist] ?: [NSMutableDictionary new];
                        pp[@"modelName"] = mid;
                        [pp writeToFile:kPlist atomically:YES];
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
                        [self reloadSpecifiers];
                    }]];
                }
                [s addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                s.popoverPresentationController.sourceView = self.view;
                s.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2, 1, 1);
                [self presentViewController:s animated:YES completion:nil];
            }];
        });
    }] resume];
}

- (void)tip:(NSString *)m {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"提示" message:m preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)pickImage {
    UIImagePickerController *p = [[UIImagePickerController alloc] init];
    p.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    p.delegate = self;
    p.allowsEditing = YES;
    [self presentViewController:p animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)p didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *img = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [p dismissViewControllerAnimated:YES completion:^{
        if (!img) return;
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(128, 128), NO, 1.0);
        [img drawInRect:CGRectMake(0, 0, 128, 128)];
        UIImage *scaled = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [UIImagePNGRepresentation(scaled) writeToFile:kIcon atomically:YES];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kPlist] ?: [NSMutableDictionary new];
        dict[@"iconPath"] = kIcon;
        [dict writeToFile:kPlist atomically:YES];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
        [self tip:@"图标已更新"];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)p { [p dismissViewControllerAnimated:YES completion:nil]; }

- (void)clearHistory {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithContentsOfFile:kPlist] ?: [NSMutableDictionary new];
    [d removeObjectForKey:@"chatHistory"];
    [d writeToFile:kPlist atomically:YES];
    [self apply];
}

@end
