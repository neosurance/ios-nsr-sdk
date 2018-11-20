#import "NSREventWebView.h"
#import "NSR.h"

@implementation NSREventWebView

-(id)init {
	if (self = [super init]) {
		self.webConfiguration = [[WKWebViewConfiguration alloc] init];
		[self.webConfiguration.userContentController addScriptMessageHandler:self name:@"app"];
		self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:self.webConfiguration];
		[self.webView loadRequest:[[NSURLRequest alloc] initWithURL:[[[NSR sharedInstance] frameworkBundle] URLForResource:@"eventCrucher" withExtension:@"html"]]];
	}
	return self;
}

-(void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
	NSDictionary *body = (NSDictionary*)message.body;
	NSR* nsr = [NSR sharedInstance];
	if(body[@"log"] != nil) {
		NSLog(@"%@",body[@"log"]);
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
	if(body[@"what"] != nil) {
		if([@"init" isEqualToString:body[@"synched"]]) {
			[nsr eventWebViewSynched];
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
		if([@"push" isEqualToString:body[@"what"]] && body[@"title"] != nil && body[@"body"] != nil) {
			NSMutableDictionary* push = [[NSMutableDictionary alloc] init];
			[push setObject:body[@"title"] forKey:@"title"];
			[push setObject:body[@"body"] forKey:@"body"];
			[push setObject:body[@"url"] forKey:@"url"];
			[nsr showPush:push];
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
			bool extend = (body[@"extend"] != nil && [body[@"extend"] boolValue]);
			[nsr accurateLocation:[body[@"meters"] doubleValue] duration:(int)[body[@"duration"] integerValue] extend:extend];
		}
		if([@"accurateLocationEnd" isEqualToString:body[@"what"]]) {
			[nsr accurateLocationEnd];
		}
	}
}

-(void) synch {
	[self eval:@"synch()"];
}

-(void) reset {
	[self eval:@"localStorage.clear();synch()"];
}

-(void) crunchEvent:(NSString*)event payload:(NSDictionary*)payload {
	NSR* nsr = [NSR sharedInstance];
	NSMutableDictionary* nsrEvent = [[NSMutableDictionary alloc] init];
	[nsrEvent setObject:event forKey:@"event"];
	[nsrEvent setObject:payload forKey:@"payload"];
	[self	eval:[NSString stringWithFormat:@"crunchEvent(%@)", [nsr dictToJson:nsrEvent]]];
}

-(void)eval:(NSString*)javascript {
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[self.webView evaluateJavaScript:javascript completionHandler:^(id result, NSError *error) {}];
	});
}
@end
