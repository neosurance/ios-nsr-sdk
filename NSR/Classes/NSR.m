#import <math.h>
#import "NSR.h"
#import "NSRDefaultSecurityDelegate.h"
#import "NSRControllerWebView.h"
#import "NSREventWebView.h"

@implementation NSR

-(NSString*)version {
	return @"2.0.3";
}

-(NSString*)os {
	return @"iOS";
}

+(id)sharedInstance {
	static NSR *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
		[sharedInstance setSecurityDelegate:[[NSRDefaultSecurityDelegate alloc] init]];
	});
	return sharedInstance;
}

-(id)init {
	if (self = [super init]) {
		self.pushPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:[[self frameworkBundle] URLForResource:@"NSR_push" withExtension:@"wav"] error:nil];
		self.pushPlayer.volume = 1;
		self.pushPlayer.numberOfLoops = 0;
		
		self.significantLocationManager = [[CLLocationManager alloc] init];
		[self.significantLocationManager setAllowsBackgroundLocationUpdates:YES];
		[self.significantLocationManager setPausesLocationUpdatesAutomatically:NO];
		self.significantLocationManager.delegate = self;
		[self.significantLocationManager requestAlwaysAuthorization];
		
		self.stillLocationManager = [[CLLocationManager alloc] init];
		[self.stillLocationManager setAllowsBackgroundLocationUpdates:YES];
		[self.stillLocationManager setPausesLocationUpdatesAutomatically:NO];
		[self.stillLocationManager setDistanceFilter:kCLDistanceFilterNone];
		[self.stillLocationManager setDesiredAccuracy:kCLLocationAccuracyBest];
		[self.stillLocationManager requestAlwaysAuthorization];
		
		self.motionActivityManager = [[CMMotionActivityManager alloc] init];
		self.motionActivities = [[NSMutableArray alloc] init];
		activityInited = NO;
		
		[[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status){
			[self traceConnection:status];
		}];
		
		stillLocationSent = NO;
		controllerWebView = nil;
		eventWebView = nil;
		lastConnection = nil;
		lastPower = nil;
		lastActivity = nil;
		eventWebViewSynchTime = 0;
		setupInited = NO;
	}
	return self;
}

-(void)initJob {
	[[AFNetworkReachabilityManager sharedManager] stopMonitoring];
	
	[self.significantLocationManager stopMonitoringSignificantLocationChanges];
	
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(tracePower) object: nil];
	
	if(activityInited) {
		[self.motionActivityManager stopActivityUpdates];
		activityInited = NO;
	}
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
	
	NSDictionary* conf = [self getConf];
	if(conf != nil){
		if (eventWebView == nil && conf[@"local_tracking"] && [conf[@"local_tracking"] boolValue]) {
			NSLog(@"Making NSREventWebView");
			eventWebView = [[NSREventWebView alloc] init];
			eventWebViewSynchTime = [[NSDate date] timeIntervalSince1970];
		}
		
		if([conf[@"connection"][@"enabled"] boolValue]) {
			[[AFNetworkReachabilityManager sharedManager] startMonitoring];
		}
		if([conf[@"power"][@"enabled"] boolValue]) {
			[self tracePower];
		}
		if([conf[@"activity"][@"enabled"] boolValue]) {
			[self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity* activity) {
				[self traceActivity:activity];
			}];
			activityInited = YES;
		}
		if([conf[@"position"][@"enabled"] boolValue]) {
			[self.significantLocationManager startMonitoringSignificantLocationChanges];
		}
	}
}

-(void)tracePower {
	NSDictionary* conf = [self getConf];
	if(conf != nil && [conf[@"power"][@"enabled"] boolValue]) {
		UIDevice* currentDevice = [UIDevice currentDevice];
		[currentDevice setBatteryMonitoringEnabled:YES];
		UIDeviceBatteryState batteryState = [currentDevice batteryState];
		int batteryLevel = (int)([currentDevice batteryLevel]*100);
		NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
		[payload setObject:[NSNumber numberWithInteger: batteryLevel] forKey:@"level"];
		if(batteryState == UIDeviceBatteryStateUnplugged) {
			[payload setObject:@"unplugged" forKey:@"type"];
		} else {
			[payload setObject:@"plugged" forKey:@"type"];
		}
		if([payload[@"type"] compare:lastPower] != NSOrderedSame || abs(batteryLevel - lastPowerLevel) > 5) {
			lastPower = payload[@"type"];
			lastPowerLevel = batteryLevel;
			[self crunchEvent:@"power" payload:payload];
		}
		[self performSelector:@selector(tracePower) withObject: nil afterDelay: [conf[@"time"] intValue]];
	}
}

-(void)traceConnection:(AFNetworkReachabilityStatus)status {
	NSDictionary* conf = [self getConf];
	if(conf !=nil && [conf[@"connection"][@"enabled"] boolValue]) {
		NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
		NSString* connection = nil;
		if (status == AFNetworkReachabilityStatusReachableViaWiFi) {
			connection = @"wi-fi";
		} else if (status == AFNetworkReachabilityStatusReachableViaWWAN) {
			connection = @"mobile";
		}
		if(connection != nil && [connection compare:lastConnection] != NSOrderedSame) {
			[payload setObject:connection forKey:@"type"];
			[self crunchEvent:@"connection" payload:payload];
			lastConnection = connection;
		}
		NSLog(@"traceConnection: %@",connection);
	}
}

-(void)traceActivity:(CMMotionActivity*) activity {
	NSLog(@"traceActivity IN");
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
	[self performSelector:@selector(sendActivity) withObject: nil afterDelay: 5];
	if([self.motionActivities count] == 0) {
		[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
		[self performSelector:@selector(recoveryActivity) withObject: nil afterDelay: 15];
	}
	[self.motionActivities addObject:activity];
}

-(void)sendActivity {
	NSLog(@"sendActivity");
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
	[self innerSendActivity];
}

-(void)recoveryActivity {
	NSLog(@"recoveryActivity");
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
	[self innerSendActivity];
}

-(void) innerSendActivity {
	NSLog(@"innerSendActivity");
	NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
	
	int walkNumber = 0;
	int stillNumber = 0;
	int carNumber = 0;
	int runNumber = 0;
	int bicycleNumber = 0;
	CMMotionActivity* motionToSend = nil;
	int toSendNumber = 0;
	
	for (CMMotionActivity* activity in self.motionActivities)
	{
		if(activity.walking)  {
			walkNumber++;
			if(walkNumber > toSendNumber){
				toSendNumber = walkNumber;
				motionToSend = activity;
				[payload setObject:@"walk" forKey:@"type"];
			}
		} else if(activity.stationary)  {
			stillNumber++;
			if(stillNumber > toSendNumber){
				toSendNumber = stillNumber;
				motionToSend = activity;
				[payload setObject:@"still" forKey:@"type"];
			}
		} else if(activity.automotive)  {
			carNumber++;
			if(carNumber > toSendNumber){
				toSendNumber = carNumber;
				motionToSend = activity;
				[payload setObject:@"car" forKey:@"type"];
			}
		} else if(activity.running)  {
			runNumber++;
			if(runNumber > toSendNumber){
				toSendNumber = runNumber;
				motionToSend = activity;
				[payload setObject:@"run" forKey:@"type"];
			}
		} else if(activity.cycling)  {
			bicycleNumber++;
			if(bicycleNumber > toSendNumber){
				toSendNumber = bicycleNumber;
				motionToSend = activity;
				[payload setObject:@"bicycle" forKey:@"type"];
			}
		}
	}
	[self.motionActivities removeAllObjects];
	
	if(motionToSend != nil) {
		if(motionToSend.confidence == CMMotionActivityConfidenceLow) {
			[payload setObject:[NSNumber numberWithInt:25] forKey:@"confidence"];
		} else if(motionToSend.confidence == CMMotionActivityConfidenceMedium) {
			[payload setObject:[NSNumber numberWithInt:50] forKey:@"confidence"];
		} else if(motionToSend.confidence == CMMotionActivityConfidenceHigh) {
			[payload setObject:[NSNumber numberWithInt:100] forKey:@"confidence"];
		}
		int confidence = [payload[@"confidence"] intValue];
		NSLog(@"activity.type  %@", payload[@"type"]);
		NSLog(@"activity.confidence  %i", confidence);
		NSDictionary* conf = [self getConf];
		if(conf != nil){
			int minConfidence = [conf[@"activity"][@"confidence"] intValue];
			if(confidence >= minConfidence && [payload[@"type"] compare:lastActivity] != NSOrderedSame) {
				lastActivity = payload[@"type"];
				[self crunchEvent:@"activity" payload:payload];
				if([conf[@"position"][@"enabled"] boolValue] && !stillLocationSent && motionToSend.stationary) {
					[self.stillLocationManager startUpdatingLocation];
				}
			}
		}
	}
}

-(void)setup:(NSDictionary*)settings {
	NSLog(@"setup");
	NSMutableDictionary* mutableSettings = [[NSMutableDictionary alloc] initWithDictionary:settings];
	NSLog(@"%@", mutableSettings);
	if(mutableSettings[@"ns_lang"] == nil) {
		NSString * language = [[NSLocale preferredLanguages] firstObject];
		NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
		[mutableSettings setObject:languageDic[NSLocaleLanguageCode] forKey:@"ns_lang"];
	}
	if(mutableSettings[@"dev_mode"]  == nil) {
		[mutableSettings setObject:[NSNumber numberWithInt:0] forKey:@"dev_mode"];
	}
	[self setSettings: mutableSettings];
	if(!setupInited){
		setupInited = YES;
		[self initJob];
	}
}

-(void)registerUser:(NSRUser*) user {
	NSLog(@"registerUser %@", [user toDict:YES]);
	[self forgetUser];
	[self setUser:user];
	
	[self authorize:^(BOOL authorized) {
		if(authorized){
			NSLog(@"registerUser authorized");
		} else {
			NSLog(@"registerUser not authorized");
		}
	}];
}

-(void)crunchEvent:(NSString *)event payload:(NSDictionary *)payload {
	NSDictionary* conf = [self getConf];
	if (conf != nil && conf[@"local_tracking"] != nil && [conf[@"local_tracking"] boolValue]) {
		NSLog(@"crunchEvent event %@", event);
		NSLog(@"crunchEvent payload %@", payload);
		if (eventWebView != nil) {
			[eventWebView crunchEvent:event payload:payload];
		}
	} else {
		[self sendEvent:event payload:payload];
	}
}

-(void)sendEvent:(NSString *)event payload:(NSDictionary *)payload {
	NSLog(@"sendEvent event %@", event);
	NSLog(@"sendEvent payload %@", payload);
	
	[self authorize:^(BOOL authorized) {
		if(!authorized){
			return;
		}
		
		NSMutableDictionary* eventPayload = [[NSMutableDictionary alloc] init];
		[eventPayload setObject:event forKey:@"event"];
		[eventPayload setObject:payload forKey:@"payload"];
		[eventPayload setObject:[[NSTimeZone localTimeZone] name] forKey:@"timezone"];
		[eventPayload setObject:[NSNumber numberWithLong:([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"event_time"];
		
		NSMutableDictionary* devicePayLoad = [[NSMutableDictionary alloc] init];
		[devicePayLoad setObject:[self uuid] forKey:@"uid"];
		NSString* pushToken = [self getPushToken];
		if(pushToken != nil) {
			[devicePayLoad setObject:pushToken forKey:@"push_token"];
		}
		[devicePayLoad setObject:[self os] forKey:@"os"];
		[devicePayLoad setObject:[[NSProcessInfo processInfo] operatingSystemVersionString] forKey:@"version"];
		struct utsname systemInfo;
		uname(&systemInfo);
		[devicePayLoad setObject:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] forKey:@"model"];
		
		NSMutableDictionary* requestPayload = [[NSMutableDictionary alloc] init];
		[requestPayload setObject:eventPayload forKey:@"event"];
		[requestPayload setObject:[[self getUser] toDict:NO] forKey:@"user"];
		[requestPayload setObject:devicePayLoad forKey:@"device"];
		
		NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
		[headers setObject:[self getToken] forKey:@"ns_token"];
		[headers setObject:[self getLang] forKey:@"ns_lang"];
		
		[self.securityDelegate secureRequest:@"event" payload:requestPayload headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
			if (error == nil) {
				BOOL skipPush = (responseObject[@"skipPush"] != nil && [responseObject[@"skipPush"] boolValue]);
				NSArray* pushes = responseObject[@"pushes"];
				if(!skipPush) {
					if([pushes count] > 0){
						[self showPush: pushes[0]];
					}
				} else {
					if([pushes count] > 0){
						[self showUrl: pushes[0][@"url"]];
					}
				}
			} else {
				NSLog(@"sendEvent %@", error);
			}
		}];
	}];
}

-(void)sendAction:(NSString *)action policyCode:(NSString *)code details:(NSString *)details {
	NSLog(@"sendAction action %@", action);
	NSLog(@"sendEvent policyCode %@", code);
	NSLog(@"sendEvent details %@", details);
	
	[self authorize:^(BOOL authorized) {
		if(!authorized){
			return;
		}
		
		NSMutableDictionary* requestPayload = [[NSMutableDictionary alloc] init];
		[requestPayload setObject:action forKey:@"action"];
		[requestPayload setObject:code forKey:@"code"];
		[requestPayload setObject:details forKey:@"details"];
		[requestPayload setObject:[[NSTimeZone localTimeZone] name] forKey:@"timezone"];
		[requestPayload setObject:[NSNumber numberWithLong:([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"action_time"];
		
		NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
		[headers setObject:[self getToken] forKey:@"ns_token"];
		[headers setObject:[self getLang] forKey:@"ns_lang"];
		
		[self.securityDelegate secureRequest:@"action" payload:requestPayload headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
			if (error == nil) {
				NSLog(@"sendAction %@", responseObject);
			} else {
				NSLog(@"sendAction %@", error);
			}
		}
		 ];
	}];
}

-(BOOL)forwardNotification:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
	NSDictionary* userInfo = response.notification.request.content.userInfo;
	if(userInfo != nil && [@"NSR" isEqualToString:userInfo[@"provider"]]) {
		if(userInfo[@"url"] != nil){
			[self showUrl:userInfo[@"url"]];
		}
		return YES;
	}
	return NO;
}

-(void)showPush:(NSDictionary*)push {
	NSMutableDictionary* mPush = [[NSMutableDictionary alloc] initWithDictionary:push];
	[mPush setObject:@"NSR" forKey:@"provider"];
	
	UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
	[content setTitle:mPush[@"title"]];
	[content setBody:mPush[@"body"]];
	[content setUserInfo:mPush];
	if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
		[self.pushPlayer play];
	} else {
		[content setSound:[UNNotificationSound soundNamed:@"NSR_push.wav"]];
	}
	
	UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:0.1 repeats:NO];
	UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:[NSString stringWithFormat:@"NSR%@", [NSDate date]] content:content trigger:trigger];
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

-(void)setUser:(NSRUser*) user{
	[[NSUserDefaults standardUserDefaults] setObject:[user toDict:YES] forKey:@"NSR_user"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSRUser*)getUser {
	NSDictionary* userDict = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_user"];
	if(userDict != nil) {
		return [[NSRUser alloc] initWithDict:userDict];
	}
	return nil;
}

-(void)setSettings:(NSDictionary*) settings{
	[[NSUserDefaults standardUserDefaults] setObject:settings forKey:@"NSR_settings"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary*)getSettings {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_settings"];
}

-(NSString*)getLang {
	return [[self getSettings] objectForKey:@"ns_lang"];
}

-(void)setAuth:(NSDictionary*) auth{
	[[NSUserDefaults standardUserDefaults] setObject:auth forKey:@"NSR_auth"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary*)getAuth {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_auth"];
}

-(NSString*)getToken {
	return [[self getAuth] objectForKey:@"token"];
}

-(NSString*)getPushToken {
	return [[self getSettings] objectForKey:@"push_token"];
}

-(void)setConf:(NSDictionary*) conf{
	[[NSUserDefaults standardUserDefaults] setObject:conf forKey:@"NSR_conf"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary*)getConf {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_conf"];
}

-(void)setAppUrl:(NSString*) appUrl{
	[[NSUserDefaults standardUserDefaults] setObject:appUrl forKey:@"NSR_appUrl"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getAppUrl {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_appUrl"];
}

-(void)authorize:(void (^)(BOOL authorized))completionHandler {
	NSDictionary* auth = [self getAuth];
	NSLog(@"saved setting: %@", auth);
	if(auth != nil && [auth[@"expire"] longValue]/1000 > [[NSDate date] timeIntervalSince1970]) {
		completionHandler(YES);
	} else {
		NSRUser* user = [self getUser];
		NSDictionary* settings = [self getSettings];
		if(user != nil && settings != nil) {
			NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
			[payload setObject:user.code forKey:@"user_code"];
			[payload setObject:settings[@"code"] forKey:@"code"];
			[payload setObject:settings[@"secret_key"] forKey:@"secret_key"];
			
			NSMutableDictionary* sdkPayload = [[NSMutableDictionary alloc] init];
			[sdkPayload setObject:[self version] forKey:@"version"];
			[sdkPayload setObject:settings[@"dev_mode"] forKey:@"dev"];
			[sdkPayload setObject:[self os] forKey:@"os"];
			[payload setObject:sdkPayload forKey:@"sdk"];
			
			NSLog(@"security delegate: %@", [[NSR sharedInstance] securityDelegate]);
			[self.securityDelegate secureRequest:@"authorize" payload:payload headers:nil completionHandler:^(NSDictionary *responseObject, NSError *error) {
				if (error) {
					completionHandler(NO);
				} else {
					NSDictionary* response = [[NSMutableDictionary alloc] initWithDictionary:responseObject];
					
					NSDictionary* auth = response[@"auth"];
					NSLog(@"authorize auth: %@", auth);
					[self setAuth:auth];
					
					NSDictionary* oldConf = [self getConf];
					NSDictionary* conf = response[@"conf"];
					NSLog(@"authorize conf: %@", conf);
					[self setConf:conf];
					
					NSString* appUrl = response[@"app_url"];
					NSLog(@"authorize appUrl: %@", appUrl);
					[self setAppUrl:appUrl];
					
					if([self needsInitJob:conf oldConf:oldConf]){
						NSLog(@"authorize needsInitJob");
						[self initJob];
					}
					if(conf[@"local_tracking"] && [conf[@"local_tracking"] boolValue]){
						[self synchEventWebView];
					}
					completionHandler(YES);
				}
			}];
		}
	}
}

-(void)synchEventWebView {
	long t = [[NSDate date] timeIntervalSince1970];
	if(eventWebView != nil && t - eventWebViewSynchTime > (60*60*8)){
		[eventWebView synch];
		eventWebViewSynchTime = t;
	}
}

-(BOOL)needsInitJob:(NSDictionary*)conf oldConf:(NSDictionary*)oldConf {
	return (oldConf == nil || [conf[@"time"] intValue] != [oldConf[@"time"] intValue] || (eventWebView == nil && conf[@"local_tracking"] && [conf[@"local_tracking"] boolValue]));
}

-(void)forgetUser {
	NSLog(@"forgetUser");
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_conf"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_auth"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_appUrl"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_user"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self initJob];
}

-(void)showApp {
	[self showApp:nil];
}

-(void)showApp:(NSDictionary*)params {
	[self showUrl:[self getAppUrl] params:params];
}

-(void)showUrl:(NSString*) url {
	[self showUrl:url params:nil];
}

-(void)showUrl:(NSString*)url params:(NSDictionary*)params {
	NSLog(@"showUrl %@, %@", url, params);
	if(params != nil) {
		for (NSString* key in params) {
			NSString* value = [NSString stringWithFormat:@"%@", [params objectForKey:key]];
			value = [value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
			if ([url containsString:@"?"]) {
				url = [url stringByAppendingString:@"&"];
			} else {
				url = [url stringByAppendingString:@"?"];
			}
			url = [url stringByAppendingString:key];
			url = [url stringByAppendingString:@"="];
			url = [url stringByAppendingString:value];
		}
	}
	if (controllerWebView != nil) {
		[controllerWebView navigate:url];
	} else {
		UIViewController* topController = [self topViewController];
		NSRControllerWebView* controller = [[NSRControllerWebView alloc] init];
		controller.url = [NSURL URLWithString:url];
		controller.barStyle = [topController preferredStatusBarStyle];
		[controller.view setBackgroundColor:topController.view.backgroundColor];
		[topController presentViewController:controller animated:YES completion:nil];
	}
}

-(void) registerWebView:(NSRControllerWebView*)newWebView {
	if(controllerWebView != nil){
		[controllerWebView close];
	}
	controllerWebView = newWebView;
}

-(void) clearWebView {
	controllerWebView = nil;
}

-(NSString*) uuid {
	NSString* uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
	NSLog(@"uuid: %@", uuid);
	return uuid;
}

-(NSString*) dictToJson:(NSDictionary*) dict {
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
	return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

-(NSBundle*) frameworkBundle {
	NSString* mainBundlePath = [[NSBundle bundleForClass:[NSR class]] resourcePath];
	NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"NSR.bundle"];
	return [NSBundle bundleWithPath:frameworkBundlePath];
}

-(UIViewController*) topViewController {
	return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

-(UIViewController*) topViewController:(UIViewController *)rootViewController {
	if ([rootViewController isKindOfClass:[UINavigationController class]]) {
		UINavigationController *navigationController = (UINavigationController *)rootViewController;
		return [self topViewController:[navigationController.viewControllers lastObject]];
	}
	if ([rootViewController isKindOfClass:[UITabBarController class]]) {
		UITabBarController *tabController = (UITabBarController *)rootViewController;
		return [self topViewController:tabController.selectedViewController];
	}
	if (rootViewController.presentedViewController) {
		return [self topViewController:rootViewController.presentedViewController];
	}
	return rootViewController;
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	if(manager == self.stillLocationManager) {
		[manager stopUpdatingLocation];
	}
	CLLocation *newLocation = [locations lastObject];
	NSLog(@"enter didUpdateToLocation");
	NSDictionary* conf = [self getConf];
	if(conf != nil && [conf[@"position"][@"enabled"] boolValue]) {
		NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
		[payload setObject:[NSNumber numberWithFloat:newLocation.coordinate.latitude] forKey:@"latitude"];
		[payload setObject:[NSNumber numberWithFloat:newLocation.coordinate.longitude] forKey:@"longitude"];
		stillLocationSent = (manager == self.stillLocationManager);
		[self crunchEvent:@"position" payload:payload];
	}
	NSLog(@"didUpdateToLocation exit");
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSLog(@"didFailWithError");
}
@end
