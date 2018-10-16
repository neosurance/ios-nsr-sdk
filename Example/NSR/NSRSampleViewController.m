#import "NSRSampleViewController.h"
#import "NSRSampleWFDelegate.h"
#import <NSR/NSR.h>

@implementation NSRSampleViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	[self setup:nil];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (IBAction)registerUser:(UIButton *)sender {
	NSLog(@"Register User");
	NSRUser* user = [[NSRUser alloc] init];
	user.email = @"XXX@neosurance.eu";
	user.code = @"XXX@neosurance.eu";
	user.fiscalCode = @"XXXNSRXXX";
	user.firstname = @"XXX";
	user.lastname = @"neosurance";
	[[NSR sharedInstance] registerUser:user];
}

- (IBAction)forgetUser:(UIButton *)sender {
	NSLog(@"Forget User");
	[[NSR sharedInstance] forgetUser];
}

- (IBAction)showApp:(UIButton *)sender {
	NSLog(@"Policies");
	[[NSR sharedInstance] showApp];
}

- (IBAction)sendEventTest:(UIButton *)sender {
	NSLog(@"Send Event");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[payload setValue:@"*" forKey:@"type"];
	[[NSR sharedInstance] sendEvent:@"test" payload:payload];
}

- (IBAction)sendEvent:(UIButton *)sender {
	NSLog(@"Send Event");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[payload setValue:@"IT" forKey:@"fromCode"];
	[payload setValue:@"italia" forKey:@"fromCountry"];
	[payload setValue:@"FR" forKey:@"toCode"];
	[payload setValue:@"francia" forKey:@"toCountry"];
	[[NSR sharedInstance] sendEvent:@"countryChange" payload:payload];
}

- (IBAction)setup:(UIButton *)sender {
	NSLog(@"Setup");
	[[NSR sharedInstance] setWorkflowDelegate:[[NSRSampleWFDelegate alloc] init]];
	NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];
	[settings setObject:@"https://sandbox.neosurancecloud.net/sdk/api/v1.0/" forKey:@"base_url"];
	[settings setObject:@"<code>" forKey:@"code"];
	[settings setObject:@"<secret_key>" forKey:@"secret_key"];
	[settings setObject:[NSNumber numberWithBool:YES] forKey:@"dev_mode"];
	
	[settings setObject:[NSNumber numberWithInt:UIStatusBarStyleDefault] forKey:@"bar_style"];
	[settings setObject:[UIColor colorWithRed:0.2 green:1 blue:1 alpha:1] forKey:@"back_color"];
	
	[[NSR sharedInstance] setup:settings];
}

- (IBAction)appLogin:(UIButton *)sender {
	NSLog(@"AppLogin");
	NSString* url = [[NSUserDefaults standardUserDefaults] objectForKey:@"login_url"];
	if(url != nil){
		[[NSR sharedInstance] loginExecuted:url];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"login_url"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (IBAction)appPayment:(UIButton *)sender {
	NSLog(@"AppPayment");
	NSString* url = [[NSUserDefaults standardUserDefaults] objectForKey:@"payment_url"];
	NSMutableDictionary* paymentInfo = [[NSMutableDictionary alloc] init];
	[paymentInfo setObject:@"abcde" forKey:@"transactionCode"];
	if(url != nil){
		[[NSR sharedInstance] paymentExecuted:paymentInfo url:url];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"payment_url"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

-(UIStatusBarStyle) preferredStatusBarStyle{
	return UIStatusBarStyleLightContent;
}

@end
