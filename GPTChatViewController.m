NSMutableArray *apiMessages = [NSMutableArray array];
    [apiMessages addObject:@{@"role": @"system", @"content": @"你是一个简洁的AI助手，用中文回答。"}];
    for (NSDictionary *msg in self.messages) {
        [apiMessages addObject:msg];
    }

    NSDictionary *body = @{
        @"model": [GPTSettings modelName],
        @"messages": apiMessages,
        @"temperature": @0.7,
        @"max_tokens": @1024
    };
