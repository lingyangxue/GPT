#import "GPTSettings.h"

@implementation GPTSettings

+ (NSUserDefaults *)ud {
    return [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];
}

+ (void)setValue:(id)value forKey:(NSString *)key {
    if (!key) return;
    NSUserDefaults *ud = [self ud];
    if (value) [ud setObject:value forKey:key];
    else [ud removeObjectForKey:key];
    [ud synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.yourname.gptfloatball/settingsChanged"), NULL, NULL, YES);
}

+ (BOOL)isEnabled {
    NSUserDefaults *ud = [self ud];
    if ([ud objectForKey:@"enabled"] == nil) return YES;
    return [ud boolForKey:@"enabled"];
}

+ (BOOL)ballEnabled {
    NSUserDefaults *ud = [self ud];
    if ([ud objectForKey:@"ballEnabled"] == nil) return YES;
    return [ud boolForKey:@"ballEnabled"];
}

+ (NSString *)apiKey {
    NSString *v = [[self ud] stringForKey:@"apiKey"];
    return v ?: @"";
}

+ (NSString *)apiBaseURL {
    NSString *url = [[self ud] stringForKey:@"apiBaseURL"];
    return url.length > 0 ? url : @"https://api.deepseek.com/v1/chat/completions";
}

+ (NSString *)modelName {
    NSString *m = [[self ud] stringForKey:@"modelName"];
    return m.length > 0 ? m : @"deepseek-chat";
}

+ (NSString *)iconPath {
    NSString *p = [[self ud] stringForKey:@"iconPath"];
    return p.length > 0 ? p : nil;
}

+ (NSString *)systemPrompt {
    NSString *s = [[self ud] stringForKey:@"systemPrompt"];
    return s.length > 0 ? s : @"你是一个简洁的AI助手，用中文回答。";
}

+ (double)temperature {
    NSUserDefaults *ud = [self ud];
    if ([ud objectForKey:@"temperature"] == nil) return 0.7;
    return [[ud stringForKey:@"temperature"] doubleValue];
}

+ (NSInteger)maxTokens {
    NSUserDefaults *ud = [self ud];
    if ([ud objectForKey:@"maxTokens"] == nil) return 1024;
    return [[ud stringForKey:@"maxTokens"] integerValue];
}

+ (CGFloat)ballSize {
    NSUserDefaults *ud = [self ud];
    NSString *s = [ud stringForKey:@"ballSize"];
    CGFloat v = s.length > 0 ? [s floatValue] : 36;
    if (v < 20) v = 20;
    if (v > 150) v = 150;
    return v;
}

+ (CGFloat)ballOpacity {
    NSUserDefaults *ud = [self ud];
    NSString *s = [ud stringForKey:@"ballOpacity"];
    CGFloat v = s.length > 0 ? [s floatValue] : 0.9;
    if (v < 0.1) v = 0.1;
    if (v > 1.0) v = 1.0;
    return v;
}

+ (CGFloat)windowScale {
    NSUserDefaults *ud = [self ud];
    NSString *s = [ud stringForKey:@"windowScale"];
    CGFloat v = s.length > 0 ? [s floatValue] : 1.0;
    if (v < 0.5) v = 0.5;
    if (v > 1.0) v = 1.0;
    return v;
}

+ (NSArray *)chatHistory {
    NSArray *a = [[self ud] arrayForKey:@"chatHistory"];
    return a ?: @[];
}

+ (void)saveChatHistory:(NSArray *)history {
    NSUserDefaults *ud = [self ud];
    [ud setObject:history forKey:@"chatHistory"];
    [ud synchronize];
}

+ (void)clearHistory {
    NSUserDefaults *ud = [self ud];
    [ud removeObjectForKey:@"chatHistory"];
    [ud synchronize];
}

@end
