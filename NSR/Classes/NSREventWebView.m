#import "NSREventWebView.h"
#import "NSR.h"

@implementation NSREventWebView

-(id)init {
	if (self = [super init]) {
		NSR* nsr = [NSR sharedInstance];
		self.webConfiguration = [[WKWebViewConfiguration alloc] init];
		[self.webConfiguration.userContentController addScriptMessageHandler:self name:@"app"];
		self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:self.webConfiguration];
		NSURL* rurl = [[nsr frameworkBundle] URLForResource:@"eventCruncher" withExtension:@"html"];
		NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?ns_lang=%@&ns_log=%@", rurl ,[nsr getLang],[NSR logDisabled]?@"false":@"true"]];
		[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:url]];
	}
	return self;
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	@try {
		NSDictionary *body = (NSDictionary*)message.body;
		NSR* nsr = [NSR sharedInstance];
		if(body[@"log"] != nil) {
			NSRLog(@"%@",body[@"log"]);
		}
		if(body[@"event"] != nil && body[@"payload"] != nil) {
			[nsr sendEvent:body[@"event"] payload:body[@"payload"]];
		}
		if(body[@"archiveEvent"] != nil && body[@"payload"] != nil) {
			[nsr archiveEvent:body[@"archiveEvent"] payload:body[@"payload"]];
		}
		if(body[@"action"] != nil) {
			[nsr sendAction:body[@"action"] policyCode:body[@"code"] details:body[@"details"]];
		}
		if(body[@"push"] != nil) {
			if(body[@"delay"] != nil) {
				[nsr showPush:(body[@"id"] != nil)?body[@"id"]:[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]] push:body[@"push"] delay:[body[@"delay"] intValue]];
			}else{
				[nsr showPush:body[@"push"]];
			}
		}
		if(body[@"killPush"] != nil) {
			[nsr killPush:body[@"killPush"]];
		}
		if(body[@"what"] != nil) {
			if([@"continueInitJob" isEqualToString:body[@"what"]]) {
				[nsr continueInitJob];
			}
			if([@"init" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
				[nsr authorize:^(BOOL authorized) {
					if(authorized){
						NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
						[message setObject:[nsr getSettings][@"base_url"] forKey:@"api"];
						[message setObject:[nsr getToken] forKey:@"token"];
						[message setObject:[nsr getLang] forKey:@"lang"];
						[message setObject:[nsr uuid] forKey:@"deviceUid"];
						[self eval:[NSString stringWithFormat:@"%@(%@)",body[@"callBack"], [nsr dictToJson:message]]];
					}
				}];
			}
			if([@"token" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
				[nsr authorize:^(BOOL authorized) {
					if(authorized) {
						[self eval:[NSString stringWithFormat:@"%@('%@')",body[@"callBack"], [nsr getToken]]];
					}
				}];
			}
			if([@"user" isEqualToString:body[@"what"]] && body[@"callBack"] != nil) {
				[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:[[nsr getUser] toDict:YES]]]];
			}
			if([@"geoCode" isEqualToString:body[@"what"]] && body[@"location"] != nil && body[@"callBack"] != nil) {
				CLGeocoder* geocoder = [[CLGeocoder alloc] init];
				CLLocation* location = [[CLLocation alloc] initWithLatitude:[body[@"location"][@"latitude"] doubleValue] longitude:[body[@"location"][@"longitude"] doubleValue]];
				[geocoder reverseGeocodeLocation:location completionHandler:^(NSArray* placemarks, NSError* error){
					@try {
						if(error == nil && placemarks != nil && [placemarks count] > 0) {
							CLPlacemark* placemark= placemarks[0];
							if([placemark ISOcountryCode] != nil && [placemark country] != nil) {
								NSMutableDictionary* address = [[NSMutableDictionary alloc] init];
								[address setObject:[placemark ISOcountryCode] forKey:@"countryCode"];
								[address setObject:[placemark country] forKey:@"countryName"];
								if([placemark addressDictionary] != nil && [placemark addressDictionary][@"FormattedAddressLines"] != nil){
									NSString* addressString = [[placemark addressDictionary][@"FormattedAddressLines"] componentsJoinedByString:@", "];
									[address setObject:addressString forKey:@"address"];
								}
								[self eval:[NSString stringWithFormat:@"%@(%@)", body[@"callBack"], [nsr dictToJson:address]]];
							}
						}
					}@catch (NSException *exception) {
						NSRLog(@"NSREventWebView geoCode error %@", exception.reason);
					}
				}];
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
			if([@"accurateLocation" isEqualToString:body[@"what"]] && body[@"meters"] != nil && body[@"duration"] != nil) {
				bool extend = [nsr getBoolean:body key:@"extend"];
				[nsr accurateLocation:[body[@"meters"] doubleValue] duration:(int)[body[@"duration"] integerValue] extend:extend];
			}
			if([@"accurateLocationEnd" isEqualToString:body[@"what"]]) {
				[nsr accurateLocationEnd];
			}
		}
	}
	@catch (NSException *exception) {
		NSRLog(@"NSREventWebView didReceiveScriptMessage error %@", exception.reason);
	}
}

-(void) synch {
	[self eval:@"EVC.synch()"];
}

-(void) reset {
	[self eval:@"localStorage.clear();EVC.synch()"];
}

-(void) crunchEvent:(NSString*)event payload:(NSDictionary*)payload {
	NSR* nsr = [NSR sharedInstance];
	NSMutableDictionary* nsrEvent = [[NSMutableDictionary alloc] init];
	[nsrEvent setObject:event forKey:@"event"];
	[nsrEvent setObject:payload forKey:@"payload"];
	[self	eval:[NSString stringWithFormat:@"EVC.innerCrunchEvent(%@)", [nsr dictToJson:nsrEvent]]];
}

-(void)eval:(NSString*)javascript {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		if(self.webView != nil){
			[self.webView evaluateJavaScript:javascript completionHandler:^(id result, NSError *error) {}];
		}
	});
}

-(void)close {
	if(self.webView != nil){
		[self.webView stopLoading];
		[self.webView setNavigationDelegate: nil];
		[self setWebView:nil];
	}
}

@end
