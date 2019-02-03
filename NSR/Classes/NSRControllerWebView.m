#import "NSRControllerWebView.h"
#import "NSR.h"

@implementation NSRControllerWebView

-(void)loadView {
	[super loadView];
	[[NSR sharedInstance] registerWebView:self];
	self.webConfiguration = [[WKWebViewConfiguration alloc] init];
	[self.webConfiguration.userContentController addScriptMessageHandler:self name:@"app"];
	int sh = [UIApplication sharedApplication].statusBarFrame.size.height;
	CGSize size = self.view.frame.size;
	self.webView = [[NSRWebView alloc] initWithFrame:CGRectMake(0,sh, size.width, size.height-sh) configuration:self.webConfiguration];
	self.webView.navigationDelegate = self;
	self.webView.scrollView.showsVerticalScrollIndicator = NO;
	self.webView.scrollView.showsHorizontalScrollIndicator = NO;
	self.webView.scrollView.bounces = NO;
	if (@available(iOS 11.0, *)) {
		self.webView.scrollView.insetsLayoutMarginsFromSafeArea = NO;
	}
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:self.url]];
	[self.view addSubview: self.webView];
}

-(void)viewDidLoad {
	[super viewDidLoad];
	[self performSelector:@selector(checkBody) withObject:nil afterDelay:15];
}

-(void)navigate:(NSString*) url {
	[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]]];
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	NSDictionary *body = (NSDictionary*)message.body;
	NSR* nsr = [NSR sharedInstance];
	if(body[@"log"] != nil) {
		NSRLog(@"%@",body[@"log"]);
	}
	if(body[@"event"] != nil && body[@"payload"] != nil) {
		[nsr sendEvent:body[@"event"] payload:body[@"payload"]];
	}
	if(body[@"crunchEvent"] != nil && body[@"payload"] != nil) {
		[nsr crunchEvent:body[@"crunchEvent"] payload:body[@"payload"]];
	}
	if(body[@"archiveEvent"] != nil && body[@"payload"] != nil) {
		[nsr archiveEvent:body[@"archiveEvent"] payload:body[@"payload"]];
	}
	if(body[@"action"] != nil) {
		[nsr sendAction:body[@"action"] policyCode:body[@"code"] details:body[@"details"]];
	}
	if(body[@"what"] != nil) {
		if([@"init" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[nsr authorize:^(BOOL authorized) {
				NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
				[message setObject:[nsr getSettings][@"base_url"] forKey:@"api"];
				[message setObject:[nsr getToken] forKey:@"token"];
				[message setObject:[nsr getLang] forKey:@"lang"];
				[message setObject:[nsr uuid] forKey:@"deviceUid"];
				[self eval:[NSString stringWithFormat:@"%@(%@)",body[@"callBack"], [nsr dictToJson:message]]];
			}];
		}
		if([@"close" isEqualToString:body[@"what"]]) {
			[self close];
		}
		if([@"photo" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[self takePhoto:body[@"callBack"]];
		}
		if([@"location" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[self getLocation:body[@"callBack"]];
		}
		if([@"user" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:[[nsr getUser] toDict:YES]]]];
		}
		if([@"showApp" isEqualToString:body[@"what"]]) {
			[nsr showApp:body[@"params"]];
		}
		if([@"showUrl" isEqualToString:body[@"what"]] && body[@"url"] != nil) {
			[nsr showUrl:body[@"url"] params:body[@"params"]];
		}
		if ([@"store" isEqualToString:body[@"what"]] && body[@"key"] != nil && body[@"data"] != nil) {
			[[NSUserDefaults standardUserDefaults] setObject:body[@"data"] forKey:[NSString stringWithFormat:@"NSR_WV_%@",body[@"key"]]];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		if ([@"retrive" isEqualToString:body[@"what"]] && body[@"key"] != nil && body[@"callBack"] != nil) {
			NSDictionary* val = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"NSR_WV_%@",body[@"key"]]];
			[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], val != nil?[nsr dictToJson:val]:@"null"]];
		}
		if([@"callApi" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[nsr authorize:^(BOOL authorized) {
				if(!authorized){
					NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
					[result setObject:@"error" forKey:@"status"];
					[result setObject:@"not authorized" forKey:@"message"];
					[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:result]]];
					return;
				}
				NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
				[headers setObject:[nsr getToken] forKey:@"ns_token"];
				[headers setObject:[nsr getLang] forKey:@"ns_lang"];
				[nsr.securityDelegate secureRequest:body[@"endpoint"] payload:body[@"payload"] headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
					if(error == nil) {
						[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:responseObject]]];
					} else {
						NSMutableDictionary* result = [[NSMutableDictionary alloc] init];
						[result setObject:@"error" forKey:@"status"];
						[result setObject:[NSString stringWithFormat:@"%@", error] forKey:@"message"];
						[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:result]]];
					}
				}];
			}];
		}
		if([@"geoCode" isEqualToString:body[@"what"]] && body[@"location"] != nil && body[@"callBack"] != nil) {
			CLGeocoder* geocoder = [[CLGeocoder alloc] init];
			CLLocation* location = [[CLLocation alloc] initWithLatitude:[body[@"location"][@"latitude"] doubleValue] longitude:[body[@"location"][@"longitude"] doubleValue]];
			[geocoder reverseGeocodeLocation:location completionHandler:^(NSArray* placemarks, NSError* error){
				if(placemarks != nil && [placemarks count] > 0) {
					CLPlacemark* placemark= placemarks[0];
					NSMutableDictionary* address = [[NSMutableDictionary alloc] init];
					[address setObject:[placemark ISOcountryCode] forKey:@"countryCode"];
					[address setObject:[placemark country] forKey:@"countryName"];
					NSString* addressString = [[placemark addressDictionary][@"FormattedAddressLines"] componentsJoinedByString:@", "];
					[address setObject:addressString forKey:@"address"];
					[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:address]]];
				}
			}];
		}
		if(nsr.workflowDelegate != nil && [@"executeLogin" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
			[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr.workflowDelegate executeLogin:self.webView.URL.absoluteString]?@"true":@"false"]];
		}
		if(nsr.workflowDelegate != nil && [@"executePayment" isEqualToString:body[@"what"]] && body[@"payment"] != nil) {
			NSDictionary* paymentInfo = [nsr.workflowDelegate executePayment:body[@"payment"] url:self.webView.URL.absoluteString];
			if(body[@"callBack"] != nil) {
				[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], paymentInfo != nil?[nsr dictToJson:paymentInfo]:@""]];
			}
		}
		if(nsr.workflowDelegate != nil && [@"confirmTransaction" isEqualToString:body[@"what"]] && body[@"paymentInfo"] != nil) {
			[nsr.workflowDelegate confirmTransaction:body[@"paymentInfo"]];
		}
	}
}

-(void)takePhoto:(NSString*)callBack {
	UIImagePickerController *controller = [[UIImagePickerController alloc] init];
	controller.delegate = self;
	controller.sourceType = UIImagePickerControllerSourceTypeCamera;
	controller.allowsEditing = NO;
	[self presentViewController:controller animated:YES completion:^{
		[self setPhotoCallBack:callBack];
	}];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
	if(self.photoCallBack != nil){
		UIImage* image = info[UIImagePickerControllerOriginalImage];
		CGSize newSize = CGSizeMake(512.0f*image.size.width/image.size.height,512.0f);
		UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
		[image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
		UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		NSData *imageData = UIImageJPEGRepresentation(newImage, 1.0);
		NSString *base64 = [imageData base64EncodedStringWithOptions:kNilOptions];
		[self eval:[NSString stringWithFormat:@"%@('data:image/png;base64,%@')",self.photoCallBack, base64]];
		[picker dismissViewControllerAnimated:YES completion:^{
			[self setPhotoCallBack:nil];
		}];
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:^{
		[self setPhotoCallBack:nil];
	}];
}

-(void)getLocation:(NSString*)callBack {
	if(self.locationManager == nil){
		self.locationManager = [[CLLocationManager alloc] init];
		[self.locationManager setAllowsBackgroundLocationUpdates:YES];
		[self.locationManager setPausesLocationUpdatesAutomatically:NO];
		[self.locationManager setDistanceFilter:kCLDistanceFilterNone];
		[self.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
		self.locationManager.delegate = self;
		[self.locationManager requestAlwaysAuthorization];
	}
	[self setLocationCallBack:callBack];
	[self.locationManager startUpdatingLocation];
}

-(void)locationManager:(CLLocationManager*)manager didUpdateLocations:(NSArray *)locations {
	if([locations count] > 0){
		NSRLog(@"didUpdateToLocation");
		[manager stopUpdatingLocation];
		if(self.locationCallBack != nil){
			CLLocation* loc = [locations lastObject];
			[self eval:[NSString stringWithFormat:@"%@({latitude:%f,longitude:%f,altitude:%f})", self.locationCallBack, loc.coordinate.latitude, loc.coordinate.longitude, loc.altitude]];
			[self setLocationCallBack:nil];
		}
	}
}

-(void)locationManager:(CLLocationManager*)manager didFailWithError:(NSError *)error {
	NSRLog(@"didFailWithError");
}

-(BOOL)shouldAutorotate {
	return NO;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
	return UIInterfaceOrientationPortrait;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

-(UIStatusBarStyle)preferredStatusBarStyle{
	return self.barStyle;
}

-(void)checkBody {
	[self.webView evaluateJavaScript:@"document.body.className" completionHandler:^(id result, NSError *error) {
		if(![result isEqualToString:@"NSR"]) {
			[self close];
		} else {
			[self performSelector:@selector(checkBody) withObject:nil afterDelay:15];
		}
	}];
}

-(void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	if(navigationAction.navigationType == WKNavigationTypeLinkActivated) {
		NSString* url = [NSString stringWithFormat:@"%@", navigationAction.request.URL];
		if([url hasSuffix:@".pdf"]) {
			if (@available(iOS 10.0, *)) {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:NULL];
			}
			decisionHandler(WKNavigationActionPolicyCancel);
		} else {
			decisionHandler(WKNavigationActionPolicyAllow);
		}
	} else {
		decisionHandler(WKNavigationActionPolicyAllow);
	}
}

-(void)close {
	NSRLog(@"%s", __FUNCTION__);
	[[NSR sharedInstance] clearWebView];
	[self dismissViewControllerAnimated:YES completion:^(){
		if(self.webView != nil){
			[self.webView stopLoading];
			[self.webView setNavigationDelegate: nil];
			[self.webView removeFromSuperview];
			[self setWebView:nil];
		}
		if(self.locationManager != nil){
			[self.locationManager stopUpdatingLocation];
			[self.locationManager setDelegate:nil];
			[self setLocationManager:nil];
		}
	}];
}

-(void)eval:(NSString*)javascript {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		if(self.webView != nil){
			[self.webView evaluateJavaScript:javascript completionHandler:^(id result, NSError *error) {}];
		}
	});
}
@end

