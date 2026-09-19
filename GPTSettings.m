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
