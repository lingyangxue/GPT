#import <Foundation/Foundation.h>

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
+ (NSString *)systemPrompt;       // 新增
+ (double)temperature;            // 新增
+ (NSInteger)maxTokens;           // 新增
+ (NSArray *)chatHistory;
+ (void)saveChatHistory:(NSArray *)history;
+ (void)clearHistory;
@end
