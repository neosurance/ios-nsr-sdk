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
    user.email = @"info@neosurance.eu";
    user.code = @"info@neosurance.eu";
    user.firstname = @"info";
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
    //    SMutableDictionary* settings = [[NSMutableDictionary alloc] init];
    //    [settings setObject:@"https://sandbox.neosurancecloud.net/sdk/api/v1.0/" forKey:@"base_url"];
    //    [settings setObject:@"ing" forKey:@"code"];
    //    [settings setObject:@"uBc4dyQeqp7miIAfis" forKey:@"secret_key"];
    //    [settings setObject:[NSNumber numberWithBool:YES] forKey:@"dev_mode"];
    //    [[NeosuranceSDK sharedInstance] setupWithDictionary:settings];
}

-(UIStatusBarStyle) preferredStatusBarStyle{
	return UIStatusBarStyleLightContent;
}


@end
