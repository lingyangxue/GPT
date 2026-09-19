#import <Preferences/PSListController.h>
#import <spawn.h>

// ==== 原来在 .h 里的 interface，内联到这里 ====
@interface GPTFloatBallPrefsRootListController : PSListController
@end
// ==============================================

#define kPrefsPlist @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist"

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
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.yourname.gptfloatball/settingsChanged"),
        NULL, NULL, YES);
    [self respring];
}

- (void)clearHistory {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlist] ?: [NSMutableDictionary new];
    [dict removeObjectForKey:@"chatHistory"];
    [dict writeToFile:kPrefsPlist atomically:YES];
    [self apply];
}

- (void)respring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    const char *paths[] = {
        "/var/jb/usr/bin/killall",
        "/usr/bin/killall",
        "/bin/killall",
        NULL
    };
    for (int i = 0; paths[i] != NULL; i++) {
        if (posix_spawn(&pid, paths[i], NULL, NULL, (char * const *)args, NULL) == 0) {
            return;
        }
    }
}

@end
