#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kPrefsDomain @"com.yourname.gptfloatball"
static inline NSString *prefsPath(void) {
    return @"/var/mobile/Library/Preferences/com.yourname.gptfloatball.plist";
}

@interface GPTSettings : NSObject
+ (BOOL)isEnabled;
+ (BOOL)ballEnabled;
+ (NSString *)apiKey;
+ (NSString *)apiBaseURL;
+ (NSString *)modelName;
+ (NSString *)iconPath;
+ (NSString *)systemPrompt;
+ (double)temperature;
+ (NSInteger)maxTokens;
+ (CGFloat)ballSize;
+ (CGFloat)ballOpacity;
+ (CGFloat)windowScale;
+ (NSArray *)chatHistory;
+ (void)saveChatHistory:(NSArray *)history;
+ (void)clearHistory;
+ (void)setValue:(id)value forKey:(NSString *)key;
@end
