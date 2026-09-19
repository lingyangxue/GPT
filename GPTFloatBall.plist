#import <Foundation/Foundation.h>
#import <roothide.h>

#define kPrefsDomain  @"com.yourname.gptfloatball"

static inline NSString *prefsPath(void) {
    return @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist";
}

@interface GPTSettings : NSObject
+ (BOOL)isEnabled;
+ (NSString *)apiKey;
+ (NSString *)apiBaseURL;
+ (NSString *)modelName;
+ (NSString *)iconPath;
+ (NSArray *)chatHistory;
+ (void)saveChatHistory:(NSArray *)history;
+ (void)clearHistory;
@end
