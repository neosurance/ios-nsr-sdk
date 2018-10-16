#import "NSRSampleWFDelegate.h"

@implementation NSRSampleWFDelegate

-(BOOL)executeLogin:(NSString*)url {
	[[NSUserDefaults standardUserDefaults] setObject:url forKey:@"login_url"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	return YES;
}

-(NSDictionary*)executePayment:(NSDictionary*)payment url:(NSString*)url {
	[[NSUserDefaults standardUserDefaults] setObject:url forKey:@"payment_url"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	return nil;
}

@end
