#import <UIKit/UIKit.h>
@interface GPTChatViewController : UIViewController
@property (nonatomic, copy) void (^dismissBlock)(void);
@end
