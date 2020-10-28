#import "NSRSampleViewController.h"
#import "NSRSampleWFDelegate.h"
#import <NSR/NSR.h>

@implementation NSRSampleViewController

-(void)loadView {
	[super loadView];

	self.config = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"config" ofType:@"plist"]];

	[self setup];

	self.webConfiguration = [[WKWebViewConfiguration alloc] init];
	[self.webConfiguration.userContentController addScriptMessageHandler:self name:@"app"];
	int sh = [UIApplication sharedApplication].statusBarFrame.size.height;
	CGSize size = self.view.frame.size;
	
	self.webView = [[NSRWebView alloc] initWithFrame:CGRectMake(0,sh, size.width, size.height-sh) configuration:self.webConfiguration];
	self.webView.scrollView.bounces = NO;
	if (@available(iOS 11.0, *)) {
		self.webView.scrollView.insetsLayoutMarginsFromSafeArea = NO;
	}
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"sample" withExtension:@"html"]]];
	[self.view addSubview: self.webView];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	NSDictionary *body = (NSDictionary*)message.body;
	if(body[@"what"] != nil) {
		if([@"setup" isEqualToString:body[@"what"]]) {
			[self setup];
		}
		if([@"registerUser" isEqualToString:body[@"what"]]) {
			[self registerUser];
		}
		if([@"forgetUser" isEqualToString:body[@"what"]]) {
			[self forgetUser];
		}
		if([@"showApp" isEqualToString:body[@"what"]]) {
			[self showApp];
		}
		if([@"sendEvent" isEqualToString:body[@"what"]]) {
			[self sendEvent];
		}
		if([@"sendEvent2" isEqualToString:body[@"what"]]) {
			[self sendEvent2];
		}
		if([@"appLogin" isEqualToString:body[@"what"]]) {
			[self appLogin];
		}
		if([@"appPayment" isEqualToString:body[@"what"]]) {
			[self appPayment];
		}
		if([@"accurateLocation" isEqualToString:body[@"what"]]) {
			[[NSR sharedInstance] accurateLocation:0 duration:20 extend:YES];
		}
		if([@"accurateLocationEnd" isEqualToString:body[@"what"]]) {
			[[NSR sharedInstance] accurateLocationEnd];
		}
		if([@"resetCruncher" isEqualToString:body[@"what"]]) {
			[[NSR sharedInstance] resetCruncher];
		}
	}
}

-(void)registerUser {
	NSLog(@"Register User");
	NSRUser* user = [[NSRUser alloc] init];
	user.email = self.config[@"user.email"];
	user.code = self.config[@"user.code"];
	user.firstname = self.config[@"user.firstname"];
	user.lastname = self.config[@"user.lastname"];

	NSDictionary* locals = [[NSMutableDictionary alloc]init];
	[locals setValue:self.config[@"user.email"] forKey:@"email"];
	[locals setValue:self.config[@"user.firstname"] forKey:@"firstname"];
	[locals setValue:self.config[@"user.lastname"] forKey:@"lastname"];
	[user setLocals: locals];
	
	[[NSR sharedInstance] registerUser:user];
}

-(void)forgetUser {
	NSLog(@"Forget User");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[[NSR sharedInstance] crunchEvent:@"forgetUser" payload:payload];
	[self performSelector:@selector(innerForgetUser) withObject:nil afterDelay:2];
}

-(void)innerForgetUser {
	NSLog(@"innerForgetUser User");
	[[NSR sharedInstance] forgetUser];
}

-(void)showApp {
	NSLog(@"Policies");
	[[NSR sharedInstance] showApp];
}

-(void)sendEvent {
	NSLog(@"Send Event");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[[NSR sharedInstance] sendEvent:@"ondemand" payload:payload];
}

-(void)sendEvent2 {
	NSLog(@"Send Event2");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	[[NSR sharedInstance] sendEvent:@"testpush" payload:payload];
}

-(void)setup {
	NSLog(@"Setup");
	[[NSR sharedInstance] setWorkflowDelegate:[[NSRSampleWFDelegate alloc] init]];
	NSMutableDictionary* settings = [[NSMutableDictionary alloc] init];
	[settings setObject:self.config[@"base_url"] forKey:@"base_url"];
	[settings setObject:self.config[@"code"] forKey:@"code"];
	[settings setObject:self.config[@"secret_key"] forKey:@"secret_key"];
	
	[settings setObject:[NSNumber numberWithBool:YES] forKey:@"dev_mode"];
	
	[settings setObject:[NSNumber numberWithInt:UIStatusBarStyleDefault] forKey:@"bar_style"];
	[settings setObject:[UIColor colorWithRed:0.2 green:1 blue:1 alpha:1] forKey:@"back_color"];
	
	[[NSR sharedInstance] setup:settings];
}

-(void)appLogin {
	NSLog(@"AppLogin");
	NSString* url = [[NSUserDefaults standardUserDefaults] objectForKey:@"login_url"];
	if(url != nil){
		[[NSR sharedInstance] loginExecuted:url];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"login_url"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

-(void)appPayment {
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
