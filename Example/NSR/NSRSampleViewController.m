#import "NSRSampleViewController.h"
#import <NSR/NSR.h>

@implementation NSRSampleViewController

- (void)viewDidLoad {
	[super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

- (IBAction)registerUser:(UIButton *)sender {
	NSLog(@"Register User");
	NSRUser* user = [[NSRUser alloc] init];
	user.email = @"XXX@neosurance.eu";
	user.code = @"XXX@neosurance.eu";
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

- (IBAction)sendEvent:(UIButton *)sender {
	NSLog(@"Send Event");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[[NSR sharedInstance] sendEvent:@"test" payload:payload];
}

- (IBAction)setup:(UIButton *)sender {
	NSLog(@"Setup");
	NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];
	[settings setObject:@"https://sandbox.neosurancecloud.net/sdk/api/v1.0/" forKey:@"base_url"];
	[settings setObject:@"poste" forKey:@"code"];
	[settings setObject:@"Mxw5H4RWwzrpeacWyu" forKey:@"secret_key"];
	[settings setObject:[NSNumber numberWithBool:YES] forKey:@"dev_mode"];
	[[NSR sharedInstance] setup:settings];
}

-(UIStatusBarStyle) preferredStatusBarStyle{
	return UIStatusBarStyleLightContent;
}


@end
