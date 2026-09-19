#import "GPTSettings.h"

@implementation GPTSettings

+ (NSDictionary *)_readPrefs {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:prefsPath()];
    return dict ?: @{};
}

+ (BOOL)isEnabled {
    NSNumber *v = [self _readPrefs][@"enabled"];
    return v ? [v boolValue] : YES;
}

+ (NSString *)apiKey {
    return [self _readPrefs][@"apiKey"] ?: @"";
}

+ (NSString *)apiBaseURL {
    NSString *url = [self _readPrefs][@"apiBaseURL"];
    return url.length > 0 ? url : @"https://api.openai.com/v1/chat/completions";
}

+ (NSString *)modelName {
    NSString *m = [self _readPrefs][@"modelName"];
    return m.length > 0 ? m : @"gpt-4o-mini";
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

+ (NSArray *)chatHistory {
    return [self _readPrefs][@"chatHistory"] ?: @[];
}

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
