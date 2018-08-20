#import "NSRSampleAppDelegate.h"
#import "NSRSampleViewController.h"
#import "NSRSampleWFDelegate.h"
#import <NSR/NSR.h>

@implementation NSRSampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
	center.delegate = self;
	UNAuthorizationOptions options = UNAuthorizationOptionAlert + UNAuthorizationOptionSound;
	[center requestAuthorizationWithOptions:options completionHandler:^(BOOL granted, NSError* _Nullable error) {}];
	
	[[NSR sharedInstance] setWorkflowDelegate:[[NSRSampleWFDelegate alloc] init]];
	NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];
	[settings setObject:@"https://sandbox.neosurancecloud.net/sdk/api/v1.0/" forKey:@"base_url"];
	[settings setObject:@"bikevo" forKey:@"code"];
	[settings setObject:@"uIMM9gQ5e1BDaUKtLP" forKey:@"secret_key"];
	[settings setObject:[NSNumber numberWithBool:YES] forKey:@"dev_mode"];
	[[NSR sharedInstance] setup:settings];
	
	return YES;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler  {
	completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler  {
	if(![[NSR sharedInstance] forwardNotification:response withCompletionHandler:(void(^)(void))completionHandler]) {
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
