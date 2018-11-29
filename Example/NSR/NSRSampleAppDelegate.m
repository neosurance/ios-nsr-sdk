#import "NSRSampleAppDelegate.h"
#import "NSRSampleViewController.h"
#import <NSR/NSR.h>

@implementation NSRSampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.viewController = [[NSRSampleViewController alloc] init];
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];

	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
	center.delegate = self;
	UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound;
	[center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError* _Nullable error) {}];
	
	return YES;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler  {
	completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler  {
	NSDictionary* userInfo = response.notification.request.content.userInfo;
	NSLog(@">>> code %@",userInfo[@"code"]);
	NSLog(@">>> expirationTime %@",userInfo[@"expirationTime"]);

	if(![[NSR sharedInstance] forwardNotification:response]) {
		//TODO: handle your notification
	}
	completionHandler();
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
