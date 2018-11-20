#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <MapKit/MapKit.h>
#import "NSRSampleViewController.h"

@interface NSRSampleAppDelegate : UIResponder <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) NSRSampleViewController* viewController;

@end
