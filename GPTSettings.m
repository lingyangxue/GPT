#import "GPTSettings.h"

@implementation GPTSettings

+ (NSDictionary *)_readPrefs {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:prefsPath()];
    return dict ?: @{};
}

+ (void)setValue:(id)value forKey:(NSString *)key {
    if (!key) return;
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath()] ?: [NSMutableDictionary new];
    if (value) dict[key] = value;
    else [dict removeObjectForKey:key];
    [dict writeToFile:prefsPath() atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
}

+ (BOOL)_boolForKey:(NSString *)k def:(BOOL)d {
    id v = [self _readPrefs][k];
    if (!v) return d;
    if ([v isKindOfClass:[NSNumber class]]) return [v boolValue];
    if ([v isKindOfClass:[NSString class]]) return [v boolValue];
    return d;
}

+ (BOOL)isEnabled { return YES; }
+ (BOOL)ballEnabled { return YES; }

+ (NSString *)apiKey { return [self _readPrefs][@"apiKey"] ?: @""; }
+ (NSString *)apiBaseURL {
    NSString *url = [self _readPrefs][@"apiBaseURL"];
    return url.length > 0 ? url : @"https://api.deepseek.com/v1/chat/completions";
}
+ (NSString *)modelName {
    NSString *m = [self _readPrefs][@"modelName"];
    return m.length > 0 ? m : @"deepseek-chat";
}
+ (NSString *)iconPath {
    NSString *p = [self _readPrefs][@"iconPath"];
    return p.length > 0 ? p : nil;
}
+ (NSString *)systemPrompt {
    NSString *s = [self _readPrefs][@"systemPrompt"];
    return s.length > 0 ? s : @"你是一个简洁的AI助手，用中文回答。";
}
+ (double)temperature {
    NSString *t = [self _readPrefs][@"temperature"];
    return t.length > 0 ? [t doubleValue] : 0.7;
}
+ (NSInteger)maxTokens {
    NSString *t = [self _readPrefs][@"maxTokens"];
    return t.length > 0 ? [t integerValue] : 1024;
}
+ (CGFloat)ballSize {
    NSString *s = [self _readPrefs][@"ballSize"];
    CGFloat v = s.length > 0 ? [s floatValue] : 36;
    if (v < 20) v = 20;
    if (v > 150) v = 150;
    return v;
}
+ (CGFloat)ballOpacity {
    NSString *s = [self _readPrefs][@"ballOpacity"];
    CGFloat v = s.length > 0 ? [s floatValue] : 0.9;
    if (v < 0.1) v = 0.1;
    if (v > 1.0) v = 1.0;
    return v;
}
+ (CGFloat)windowScale {
    NSString *s = [self _readPrefs][@"windowScale"];
    CGFloat v = s.length > 0 ? [s floatValue] : 1.0;
    if (v < 0.5) v = 0.5;
    if (v > 1.0) v = 1.0;
    return v;
}
+ (NSArray *)chatHistory { return [self _readPrefs][@"chatHistory"] ?: @[]; }
+ (void)saveChatHistory:(NSArray *)history {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath()] ?: [NSMutableDictionary new];
    dict[@"chatHistory"] = history;
    [dict writeToFile:prefsPath() atomically:YES];
}
+ (void)clearHistory {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:prefsPath()] ?: [NSMutableDictionary new];
    [dict removeObjectForKey:@"chatHistory"];
    [dict writeToFile:prefsPath() atomically:YES];
}
@end
