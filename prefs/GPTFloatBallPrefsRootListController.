#import "GPTFloatBallPrefsRootListController.h"
#import <spawn.h>
#import <roothide.h>

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
    posix_spawn(&pid, jbroot(@"/usr/bin/killall"), NULL, NULL, (char * const *)args, NULL);
}

@end
