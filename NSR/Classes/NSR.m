#import <math.h>
#import "NSR.h"
#import "NSRDefaultSecurityDelegate.h"
#import "NSRControllerWebView.h"
#import "NSREventWebView.h"

@implementation NSR

static BOOL _logDisabled = NO;
+(BOOL)logDisabled {
	return _logDisabled;
}

-(NSString*)version {
	return @"2.2.12";
}

-(NSString*)os {
	return @"iOS";
}

-(BOOL)getBoolean:(NSDictionary*)dict key:(NSString*)key {
	if(dict != nil && dict[key] != nil) {
		return [dict[key] boolValue];
	} else {
		return NO;
	}
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
		self.stillLocationManager = nil;
		self.locationManager = nil;
		self.hardLocationManager = nil;

		stillLocationSent = NO;
		controllerWebView = nil;
		eventWebView = nil;
		setupInited = NO;
	}
	return self;
}

-(void)initJob {
	if([self gracefulDegradate]) {
		return;
	}
	[self stopHardTraceLocation];
	[self stopTraceLocation];
	[self stopTraceConnection];
	
	if(![self synchEventWebView]){
		[self continueInitJob];
	}
}

-(void)continueInitJob {
	[self traceConnection];
	[self traceLocation];
	[self hardTraceLocation];
}

-(void)initStillLocation {
	if(self.stillLocationManager == nil) {
		NSRLog(@"initStillLocation");
		self.stillLocationManager = [[CLLocationManager alloc] init];
		[self.stillLocationManager setAllowsBackgroundLocationUpdates:YES];
		[self.stillLocationManager setPausesLocationUpdatesAutomatically:NO];
		[self.stillLocationManager setDistanceFilter:kCLDistanceFilterNone];
		[self.stillLocationManager setDesiredAccuracy:kCLLocationAccuracyBest];
		self.stillLocationManager.delegate = self;
		[self.stillLocationManager requestAlwaysAuthorization];
	}
}

-(void)initLocation {
	if(self.locationManager == nil) {
		NSRLog(@"initLocation");
		self.locationManager = [[CLLocationManager alloc] init];
		[self.locationManager setAllowsBackgroundLocationUpdates:YES];
		[self.locationManager setPausesLocationUpdatesAutomatically:NO];
		self.locationManager.delegate = self;
		[self.locationManager requestAlwaysAuthorization];
	}
}

-(void)initHardLocation {
	if(self.hardLocationManager == nil) {
		NSRLog(@"initHardLocation");
		self.hardLocationManager = [[CLLocationManager alloc] init];
		[self.hardLocationManager setAllowsBackgroundLocationUpdates:YES];
		[self.hardLocationManager setPausesLocationUpdatesAutomatically:NO];
		[self.hardLocationManager setDesiredAccuracy:kCLLocationAccuracyBest];
		self.hardLocationManager.delegate = self;
		[self.hardLocationManager requestAlwaysAuthorization];
	}
}

-(void)traceLocation {
	NSDictionary* conf = [self getConf];
	if(conf != nil && [self getBoolean:conf[@"position"] key:@"enabled"]) {
		[self initLocation];
		//[self.locationManager setDistanceFilter:500];
		//[self.locationManager startUpdatingLocation];
		[self.locationManager startMonitoringSignificantLocationChanges];
	}
}

-(void)hardTraceLocation {
	NSRLog(@"hardTraceLocation");
	NSDictionary* conf = [self getConf];
	if(conf != nil && [self getBoolean:conf[@"position"] key:@"enabled"]) {
		if([self isHardTraceLocation]){
			[self initHardLocation];
			[self.hardLocationManager setDistanceFilter:[self getHardTraceMeters]];
			[self.hardLocationManager startUpdatingLocation];
			NSRLog(@"hardTraceLocation reactivated");
		}else{
			[self stopHardTraceLocation];
			[self setHardTraceEnd:0];
		}
	}
}

-(void)stopHardTraceLocation {
	if(self.hardLocationManager != nil){
		NSRLog(@"stopHardTraceLocation");
		[self.hardLocationManager stopUpdatingLocation];
	}
}

-(void)accurateLocation:(double)meters duration:(int)duration extend:(bool)extend {
	NSDictionary* conf = [self getConf];
	if(conf != nil && [self getBoolean:conf[@"position"] key:@"enabled"]) {
		NSRLog(@"accurateLocation");
		[self initHardLocation];
		if(![self isHardTraceLocation] || meters != [self getHardTraceMeters]) {
			[self setHardTraceMeters:meters];
			[self setHardTraceEnd:[[NSDate date] timeIntervalSince1970] + duration];
			[self.hardLocationManager setDistanceFilter:meters];
			[self.hardLocationManager startUpdatingLocation];
		}
		if(extend) {
			[self setHardTraceEnd:[[NSDate date] timeIntervalSince1970] + duration];
		}
	}
}

-(void)accurateLocationEnd {
	NSRLog(@"accurateLocationEnd");
	[self stopHardTraceLocation];
	[self setHardTraceEnd:0];
}

-(void)checkHardTraceLocation {
	if(![self isHardTraceLocation]){
		[self stopHardTraceLocation];
		[self setHardTraceEnd:0];
	}
}

-(bool) isHardTraceLocation {
	int hte = [self getHardTraceEnd];
	return (hte > 0 && [[NSDate date] timeIntervalSince1970] < hte);
}

-(int)getHardTraceEnd {
	NSNumber* n = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_hardTraceEnd"];
	if(n != nil) {
		return [n intValue];
	}else{
		return 0;
	}
}

-(void)setHardTraceEnd:(int) hardTraceEnd {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:hardTraceEnd] forKey:@"NSR_hardTraceEnd"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(double)getHardTraceMeters {
	NSNumber* n = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_hardTraceMeters"];
	if(n != nil) {
		return [n doubleValue];
	}else{
		return 0;
	}
}

-(void)setHardTraceMeters:(double) meters {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithDouble:meters] forKey:@"NSR_hardTraceMeters"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


-(void)stopTraceLocation {
	NSRLog(@"stopTraceLocation");
	if(self.locationManager != nil){
		[self.locationManager stopMonitoringSignificantLocationChanges];
	}
}

-(void)initActivity {
	if(self.motionActivityManager == nil){
		NSRLog(@"initActivity");
		self.motionActivityManager = [[CMMotionActivityManager alloc] init];
		self.motionActivities = [[NSMutableArray alloc] init];
	}
}

-(void)traceActivity {
	NSDictionary* conf = [self getConf];
	if(conf != nil && [self getBoolean:conf[@"activity"] key:@"enabled"]) {
		[self initActivity];
		[self.motionActivityManager startActivityUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMMotionActivity* activity) {
			NSRLog(@"traceActivity IN");
			[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
			[self performSelector:@selector(sendActivity) withObject: nil afterDelay: 8];
			if([self.motionActivities count] == 0) {
				[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
				[self performSelector:@selector(recoveryActivity) withObject: nil afterDelay: 16];
			}
			[self.motionActivities addObject:activity];
		}];
	}
}

-(void)sendActivity {
	NSRLog(@"sendActivity");
	[self innerSendActivity];
}

-(void)recoveryActivity {
	NSRLog(@"recoveryActivity");
	[self innerSendActivity];
}

-(void) innerSendActivity {
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(recoveryActivity) object: nil];
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector:@selector(sendActivity) object: nil];
	NSDictionary* conf = [self getConf];
	if(conf == nil || [self.motionActivities count] == 0)
		return;
	NSDictionary* confidences = [[NSMutableDictionary alloc] init];
	NSDictionary* counts = [[NSMutableDictionary alloc] init];
	NSString* candidate = nil;
	int maxConfidence = 0;
	for (CMMotionActivity* activity in self.motionActivities) {
		NSRLog(@"activity type %@ confidence %i", [self activityType:activity], [self activityConfidence:activity]);
		NSString* type = [self activityType:activity];
		if(type != nil) {
			int confidence = [confidences[type] intValue] + [self activityConfidence:activity];
			[confidences setValue:[NSNumber numberWithInt:confidence] forKey:type];
			int count = [counts[type] intValue] + 1;
			[counts setValue:[NSNumber numberWithInt:count] forKey:type];
			int weightedConfidence = confidence/count + (count*5);
			if(weightedConfidence > maxConfidence){
				candidate = type;
				maxConfidence = weightedConfidence;
			}
		}
	}
	[self.motionActivities removeAllObjects];
	if(maxConfidence > 100) {
		maxConfidence = 100;
	}
	int minConfidence = [conf[@"activity"][@"confidence"] intValue];
	NSRLog(@"candidate %@", candidate);
	NSRLog(@"maxConfidence %i", maxConfidence);
	NSRLog(@"minConfidence %i", minConfidence);
	NSRLog(@"lastActivity %@", [self getLastActivity]);
	if(candidate != nil && [candidate compare:[self getLastActivity]] != NSOrderedSame && maxConfidence >= minConfidence) {
		NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
		[payload setObject:candidate forKey:@"type"];
		[payload setObject:[NSNumber numberWithInt:maxConfidence] forKey:@"confidence"];
		[self setLastActivity:candidate];
		[self crunchEvent:@"activity" payload:payload];
		if([self getBoolean:conf[@"position"] key:@"enabled"] && !stillLocationSent && [candidate compare:@"still"] == NSOrderedSame) {
			[self initStillLocation];
			[self.stillLocationManager startUpdatingLocation];
		}
	}
	[self.motionActivityManager stopActivityUpdates];
}

-(int)activityConfidence:(CMMotionActivity*)activity {
	if(activity.confidence == CMMotionActivityConfidenceLow) {
		return 25;
	} else if(activity.confidence == CMMotionActivityConfidenceMedium) {
		return 50;
	} else if(activity.confidence == CMMotionActivityConfidenceHigh) {
		return 100;
	}
	return 0;
}

-(NSString*)activityType:(CMMotionActivity*) activity {
	if(activity.stationary) {
		return @"still";
	} else if(activity.walking) {
		return @"walk";
	} else if(activity.running) {
		return @"run";
	} else if(activity.cycling) {
		return @"bicycle";
	} else if(activity.automotive) {
		return @"car";
	}
	return nil;
}

-(void)setLastActivity:(NSString*) lastActivity {
	[[NSUserDefaults standardUserDefaults] setObject:lastActivity forKey:@"NSR_lastActivity"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getLastActivity {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_lastActivity"];
}

-(void)traceConnection {
}

-(void)stopTraceConnection {
}

-(void)setLastConnection:(NSString*) lastConnection {
	[[NSUserDefaults standardUserDefaults] setObject:lastConnection forKey:@"NSR_lastConnection"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getLastConnection {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_lastConnection"];
}

-(void)tracePower {
	NSDictionary* conf = [self getConf];
	if(conf != nil && [self getBoolean:conf[@"power"] key:@"enabled"]) {
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
		if([payload[@"type"] compare:[self getLastPower]] != NSOrderedSame || abs(batteryLevel - [self getLastPowerLevel]) > 5) {
			[self setLastPower:payload[@"type"]];
			[self setLastPowerLevel:batteryLevel];
			[self crunchEvent:@"power" payload:payload];
		}
	}
}

-(void)setLastPower:(NSString*) lastPower {
	[[NSUserDefaults standardUserDefaults] setObject:lastPower forKey:@"NSR_lastPower"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getLastPower {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_lastPower"];
}

-(void)setLastPowerLevel:(int) lastPowerLevel {
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:lastPowerLevel] forKey:@"NSR_lastPowerLevel"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(int)getLastPowerLevel {
	NSNumber* n = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_lastPowerLevel"];
	if(n != nil) {
		return [n intValue];
	}else{
		return 0;
	}
}

-(void)opportunisticTrace {
	[self tracePower];
	[self traceActivity];
	if (@available(iOS 10.0, *)) {
		NSString* locationAuth = @"notAuthorized";
		CLAuthorizationStatus st = [CLLocationManager authorizationStatus];
		if(st == kCLAuthorizationStatusAuthorizedAlways){
			locationAuth = @"authorized";
		}else if(st == kCLAuthorizationStatusAuthorizedWhenInUse){
			locationAuth = @"whenInUse";
		}
		NSString* lastLocationAuth = [self getLastLocationAuth];
		if(lastLocationAuth == nil || ![locationAuth isEqualToString:lastLocationAuth]){
			[self setLastLocationAuth:locationAuth];
			NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
			[payload setObject:locationAuth forKey:@"status"];
			[self sendEvent:@"locationAuth" payload:payload];
		}
		
		[[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
			NSString* pushAuth = (settings.authorizationStatus == UNAuthorizationStatusAuthorized)?@"authorized":@"notAuthorized";
			NSString* lastPushAuth = [self getLastPushAuth];
			if(lastPushAuth == nil || ![pushAuth isEqualToString:lastPushAuth]){
				[self setLastPushAuth:pushAuth];
				NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
				[payload setObject:pushAuth forKey:@"status"];
				[self sendEvent:@"pushAuth" payload:payload];
			}
		}];
	}
}

-(void)setLastLocationAuth:(NSString*) locationAuth {
	[[NSUserDefaults standardUserDefaults] setObject:locationAuth forKey:@"NSR_locationAuth"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getLastLocationAuth {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_locationAuth"];
}

-(void)setLastPushAuth:(NSString*) pushAuth {
	[[NSUserDefaults standardUserDefaults] setObject:pushAuth forKey:@"NSR_pushAuth"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSString*)getLastPushAuth {
	return [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_pushAuth"];
}

-(void)setup:(NSDictionary*)settings {
	if([self gracefulDegradate]) {
		return;
	}
	_logDisabled = [self getBoolean:settings key:@"disable_log"];
	
	NSRLog(@"setup");
	NSMutableDictionary* mutableSettings = [[NSMutableDictionary alloc] initWithDictionary:settings];
	NSRLog(@"%@", mutableSettings);
	if(mutableSettings[@"ns_lang"] == nil) {
		NSString * language = [[NSLocale preferredLanguages] firstObject];
		NSDictionary *languageDic = [NSLocale componentsFromLocaleIdentifier:language];
		[mutableSettings setObject:languageDic[NSLocaleLanguageCode] forKey:@"ns_lang"];
	}
	if(mutableSettings[@"dev_mode"] == nil) {
		[mutableSettings setObject:[NSNumber numberWithInt:0] forKey:@"dev_mode"];
	}
	if(mutableSettings[@"back_color"] != nil) {
		UIColor* c = mutableSettings[@"back_color"];
		[mutableSettings removeObjectForKey:@"back_color"];
		CGFloat r;
		CGFloat g;
		CGFloat b;
		CGFloat a;
		[c getRed:&r green:&g blue:&b alpha:&a];
		[mutableSettings setObject:[NSNumber numberWithFloat:r] forKey:@"back_color_r"];
		[mutableSettings setObject:[NSNumber numberWithFloat:g] forKey:@"back_color_g"];
		[mutableSettings setObject:[NSNumber numberWithFloat:b] forKey:@"back_color_b"];
		[mutableSettings setObject:[NSNumber numberWithFloat:a] forKey:@"back_color_a"];
	}
	if(mutableSettings[@"skin"] != nil) {
		[self storeData:@"skin" data:mutableSettings[@"skin"]];
	}
	[self setSettings: mutableSettings];
	if(!setupInited){
		setupInited = YES;
		[self initJob];
	}
}

-(void)registerUser:(NSRUser*) user {
	if([self gracefulDegradate]) {
		return;
	}
	NSRLog(@"registerUser %@", [user toDict:YES]);
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_auth"];
	[self setUser:user];
	
	[self authorize:^(BOOL authorized) {
		NSRLog(@"registerUser %@authorized", authorized?@"":@"not ");
		if(authorized && [self getBoolean:[self getConf] key:@"send_user"]){
			NSRLog(@"sendUser");
			NSMutableDictionary* devicePayLoad = [[NSMutableDictionary alloc] init];
			[devicePayLoad setObject:[self uuid] forKey:@"uid"];
			NSString* pushToken = [self getPushToken];
			if(pushToken != nil) {
				[devicePayLoad setObject:pushToken forKey:@"push_token"];
			}
			[devicePayLoad setObject:[self os] forKey:@"os"];
			NSString* osVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
			[devicePayLoad setObject:[NSString stringWithFormat:@"[sdk:%@] %@",[self version],osVersion] forKey:@"version"];
			struct utsname systemInfo;
			uname(&systemInfo);
			[devicePayLoad setObject:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] forKey:@"model"];
			
			NSMutableDictionary* requestPayload = [[NSMutableDictionary alloc] init];
			[requestPayload setObject:[[self getUser] toDict:NO] forKey:@"user"];
			[requestPayload setObject:devicePayLoad forKey:@"device"];
			
			NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
			[headers setObject:[self getToken] forKey:@"ns_token"];
			[headers setObject:[self getLang] forKey:@"ns_lang"];
	
			[self.securityDelegate secureRequest:@"register" payload:requestPayload headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
				if (error != nil) {
					NSRLog(@"sendUser %@", error);
				}
			}];
		}
	}];
}

-(void)sendAction:(NSString *)action policyCode:(NSString *)code details:(NSString *)details {
	if([self gracefulDegradate]) {
		return;
	}
	NSRLog(@"sendAction action %@", action);
	NSRLog(@"sendAction policyCode %@", code);
	NSRLog(@"sendAction details %@", details);
	
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
				NSRLog(@"sendAction %@", responseObject);
			} else {
				NSRLog(@"sendAction %@", error);
			}
		}];
	}];
}

-(void)crunchEvent:(NSString *)event payload:(NSDictionary *)payload {
	if([self gracefulDegradate]) {
		return;
	}
	if ([self getBoolean:[self getConf] key:@"local_tracking"]) {
		NSRLog(@"crunchEvent event %@", event);
		NSRLog(@"crunchEvent payload %@", payload);
		[self snapshot:event payload:payload];
		[self localCrunchEvent:event payload:payload];
	}else{
		[self sendEvent:event payload:payload];
	}
}

-(void)localCrunchEvent:(NSString *)event payload:(NSDictionary *)payload {
	if (eventWebView == nil) {
		NSRLog(@"localCrunchEvent Making NSREventWebView");
		eventWebView = [[NSREventWebView alloc] init];
	}
	NSRLog(@"localCrunchEvent call eventWebView");
	[eventWebView crunchEvent:event payload:payload];
}

-(void)sendEvent:(NSString *)event payload:(NSDictionary *)payload {
	if([self gracefulDegradate]) {
		return;
	}
	NSRLog(@"sendEvent event %@", event);
	NSRLog(@"sendEvent payload %@", payload);
	
	[self authorize:^(BOOL authorized) {
		if(!authorized){
			return;
		}
		[self snapshot:event payload:payload];
		NSMutableDictionary* eventPayload = [[NSMutableDictionary alloc] init];
		[eventPayload setObject:event forKey:@"event"];
		[eventPayload setObject:[[NSTimeZone localTimeZone] name] forKey:@"timezone"];
		[eventPayload setObject:[NSNumber numberWithLong:([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"event_time"];
		[eventPayload setObject:payload forKey:@"payload"];

		NSMutableDictionary* devicePayLoad = [[NSMutableDictionary alloc] init];
		[devicePayLoad setObject:[self uuid] forKey:@"uid"];
		NSString* pushToken = [self getPushToken];
		if(pushToken != nil) {
			[devicePayLoad setObject:pushToken forKey:@"push_token"];
		}
		[devicePayLoad setObject:[self os] forKey:@"os"];
		NSString* osVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
		[devicePayLoad setObject:[NSString stringWithFormat:@"[sdk:%@] %@",[self version],osVersion] forKey:@"version"];
		struct utsname systemInfo;
		uname(&systemInfo);
		[devicePayLoad setObject:[NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding] forKey:@"model"];
		
		NSMutableDictionary* requestPayload = [[NSMutableDictionary alloc] init];
		[requestPayload setObject:eventPayload forKey:@"event"];
		[requestPayload setObject:[[self getUser] toDict:NO] forKey:@"user"];
		[requestPayload setObject:devicePayLoad forKey:@"device"];
		if([self getBoolean:[self getConf] key:@"send_snapshot"]) {
			[requestPayload setObject:[self snapshot] forKey:@"snapshot"];
		}
		
		NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
		[headers setObject:[self getToken] forKey:@"ns_token"];
		[headers setObject:[self getLang] forKey:@"ns_lang"];
		
		[self.securityDelegate secureRequest:@"event" payload:requestPayload headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
			if (error == nil) {
				NSArray* pushes = responseObject[@"pushes"];
				if(![self getBoolean:responseObject key:@"skipPush"]) {
					if([pushes count] > 0){
						[self showPush: pushes[0]];
						if ([self getBoolean:[self getConf] key:@"local_tracking"]) {
							[self localCrunchEvent:@"pushed" payload:pushes[0]];
						}
					}
				} else {
					if([pushes count] > 0){
						[self showUrl: pushes[0][@"url"]];
					}
				}
			} else {
				NSRLog(@"sendEvent %@", error);
			}
		}];
	}];
}

-(void)archiveEvent:(NSString *)event payload:(NSDictionary *)payload {
	if([self gracefulDegradate]) {
		return;
	}
	NSRLog(@"archiveEvent event %@", event);
	NSRLog(@"archiveEvent payload %@", payload);
	
	[self authorize:^(BOOL authorized) {
		if(!authorized){
			return;
		}
		NSMutableDictionary* eventPayload = [[NSMutableDictionary alloc] init];
		[eventPayload setObject:event forKey:@"event"];
		[eventPayload setObject:[[NSTimeZone localTimeZone] name] forKey:@"timezone"];
		[eventPayload setObject:[NSNumber numberWithLong:([[NSDate date] timeIntervalSince1970]*1000)] forKey:@"event_time"];
		[eventPayload setObject:[[NSDictionary alloc] init] forKey:@"payload"];

		NSMutableDictionary* devicePayLoad = [[NSMutableDictionary alloc] init];
		[devicePayLoad setObject:[self uuid] forKey:@"uid"];

		NSMutableDictionary* userPayLoad = [[NSMutableDictionary alloc] init];
		[userPayLoad setObject:[[self getUser] code] forKey:@"code"];

		NSMutableDictionary* requestPayload = [[NSMutableDictionary alloc] init];
		[requestPayload setObject:eventPayload forKey:@"event"];
		[requestPayload setObject:userPayLoad forKey:@"user"];
		[requestPayload setObject:devicePayLoad forKey:@"device"];
		[requestPayload setObject:[self snapshot:event payload:payload] forKey:@"snapshot"];
		
		NSMutableDictionary* headers = [[NSMutableDictionary alloc] init];
		[headers setObject:[self getToken] forKey:@"ns_token"];
		[headers setObject:[self getLang] forKey:@"ns_lang"];
		
		[self.securityDelegate secureRequest:@"archiveEvent" payload:requestPayload headers:headers completionHandler:^(NSDictionary *responseObject, NSError *error) {
			if (error != nil) {
				NSRLog(@"sendEvent %@", error);
			}
		}];
	}];
}

-(BOOL)forwardNotification:(UNNotificationResponse *)response {
	if (@available(iOS 10.0, *)) {
		NSDictionary* userInfo = response.notification.request.content.userInfo;
		if(userInfo != nil && [@"NSR" isEqualToString:userInfo[@"provider"]]) {
			if(userInfo[@"url"] != nil){
				[self showUrl:userInfo[@"url"]];
			}
			return YES;
		}
	}
	return NO;
}

-(void)showPush:(NSString*) pid push:(NSDictionary*)push delay:(int)delay {
	if (@available(iOS 10.0, *)) {
		NSMutableDictionary* mPush = [[NSMutableDictionary alloc] initWithDictionary:push];
		[mPush setObject:@"NSR" forKey:@"provider"];
		UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
		[content setTitle:mPush[@"title"]];
		[content setBody:mPush[@"body"]];
		[content setUserInfo:mPush];
		[content setSound:[UNNotificationSound soundNamed:@"NSR_push.wav"]];
		UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:delay repeats:NO];
		NSRLog(@"push delegate %@", [[UNUserNotificationCenter currentNotificationCenter] delegate]);
		
		UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:pid content:content trigger:trigger];
		[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
			if (error != nil) {
				NSRLog(@"push error! %@", error.localizedDescription);
			}
		}];
	}
}

-(void)killPush:(NSString*) pid {
	if (@available(iOS 10.0, *)) {
		if(pid != nil){
			[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[pid]];
		}
	}
}

-(void)showPush:(NSDictionary*)push {
	[self showPush:@"NSR" push:push delay:1];
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

-(NSMutableDictionary*)snapshot:(NSString*) event payload:(NSDictionary*)payload {
	NSMutableDictionary* snapshot = [self snapshot];
	[snapshot setValue:payload forKey:event];
	[[NSUserDefaults standardUserDefaults] setObject:snapshot forKey:@"NSR_snapshot"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	return snapshot;
}

-(NSMutableDictionary*)snapshot {
	NSDictionary* snapshot = [[NSUserDefaults standardUserDefaults] objectForKey:@"NSR_snapshot"];
	if(snapshot != nil) {
		return [[NSMutableDictionary alloc] initWithDictionary:snapshot];
	}
	return [[NSMutableDictionary alloc] init];
}

-(void)authorize:(void (^)(BOOL authorized))completionHandler {
	NSDictionary* auth = [self getAuth];
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
			
			NSRLog(@"security delegate: %@", [[NSR sharedInstance] securityDelegate]);
			[self.securityDelegate secureRequest:@"authorize" payload:payload headers:nil completionHandler:^(NSDictionary *responseObject, NSError *error) {
				if (error) {
					completionHandler(NO);
				} else {
					NSDictionary* response = [[NSMutableDictionary alloc] initWithDictionary:responseObject];
					
					NSDictionary* auth = response[@"auth"];
					NSRLog(@"authorize auth: %@", auth);
					[self setAuth:auth];
					
					NSDictionary* oldConf = [self getConf];
					NSDictionary* conf = response[@"conf"];
					NSRLog(@"authorize conf: %@", conf);
					[self setConf:conf];
					
					NSString* appUrl = response[@"app_url"];
					NSRLog(@"authorize appUrl: %@", appUrl);
					[self setAppUrl:appUrl];
					
					if([self needsInitJob:conf oldConf:oldConf]){
						NSRLog(@"authorize needsInitJob");
						[self initJob];
					} else {
						[self synchEventWebView];
					}
					completionHandler(YES);
				}
			}];
		}
	}
}

-(BOOL)synchEventWebView {
	if ([self getBoolean:[self getConf] key:@"local_tracking"]) {
		if(eventWebView == nil) {
			NSRLog(@"Making NSREventWebView");
			eventWebView = [[NSREventWebView alloc] init];
			return YES;
		} else {
			[eventWebView synch];
		}
	}else if(eventWebView != nil) {
		[eventWebView close];
		eventWebView = nil;
	}
	return NO;
}

-(void)resetCruncher {
	if (eventWebView != nil) {
		[eventWebView reset];
	}
}

-(BOOL)needsInitJob:(NSDictionary*)conf oldConf:(NSDictionary*)oldConf {
	return (oldConf == nil ||	![conf isEqualToDictionary:oldConf] || (eventWebView == nil && [self getBoolean:conf key:@"local_tracking"]));
}

-(void)forgetUser {
	if([self gracefulDegradate]) {
		return;
	}
	NSRLog(@"forgetUser");
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_conf"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_auth"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_appUrl"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"NSR_user"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self initJob];
}

-(void)showApp {
	if([self getAppUrl] != nil){
		[self showUrl:[self getAppUrl] params:nil];
	}
}

-(void)showApp:(NSDictionary*)params {
	if([self getAppUrl] != nil){
		[self showUrl:[self getAppUrl] params:params];
	}
}

-(void)showUrl:(NSString*) url {
	[self showUrl:url params:nil];
}

-(void)showUrl:(NSString*)url params:(NSDictionary*)params {
	NSRLog(@"showUrl %@, %@", url, params);
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
		if([self getSettings][@"bar_style"] != nil){
			controller.barStyle = [[self getSettings][@"bar_style"] integerValue];
		}else{
			controller.barStyle = [topController preferredStatusBarStyle];
		}
		if([self getSettings][@"back_color_r"] != nil){
			CGFloat r = [[self getSettings][@"back_color_r"] floatValue];
			CGFloat g = [[self getSettings][@"back_color_g"] floatValue];
			CGFloat b = [[self getSettings][@"back_color_b"] floatValue];
			CGFloat a = [[self getSettings][@"back_color_a"] floatValue];
			UIColor* c = [UIColor colorWithRed:r green:g blue:b alpha:a];
			[controller.view setBackgroundColor:c];
		}else{
			[controller.view setBackgroundColor:topController.view.backgroundColor];
		}
		controller.modalPresentationStyle = 0;
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
	NSRLog(@"uuid: %@", uuid);
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
	@try {
		if(manager == self.stillLocationManager) {
			[manager stopUpdatingLocation];
		}
		[self opportunisticTrace];
		[self checkHardTraceLocation];
		CLLocation *newLocation = [locations lastObject];
		NSRLog(@"enter didUpdateToLocation");
		NSDictionary* conf = [self getConf];
		if(conf != nil && [self getBoolean:conf[@"position"] key:@"enabled"]) {
			NSMutableDictionary* payload = [[NSMutableDictionary alloc] init];
			[payload setObject:[NSNumber numberWithFloat:newLocation.coordinate.latitude] forKey:@"latitude"];
			[payload setObject:[NSNumber numberWithFloat:newLocation.coordinate.longitude] forKey:@"longitude"];
			[payload setObject:[NSNumber numberWithFloat:newLocation.altitude] forKey:@"altitude"];
			[self crunchEvent:@"position" payload:payload];
			stillLocationSent = (manager == self.stillLocationManager);
		}
		NSRLog(@"didUpdateToLocation exit");
	}
	@catch (NSException *exception) {
		NSRLog(@"didUpdateToLocation error");
	}
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	NSRLog(@"didFailWithError");
}

- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(NSError *)error{
	NSRLog(@"didFinishDeferredUpdatesWithError");
}

-(BOOL)gracefulDegradate {
	if (@available(iOS 10.0, *)) {
		return NO;
	}else {
		return YES;
	}
}

-(void)loginExecuted:(NSString*) url {
	if ([self gracefulDegradate]) {
		return;
	}
	NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
	[params setObject:@"yes" forKey:@"loginExecuted"];
	[self showUrl:url params:params];
}

-(void)paymentExecuted:(NSDictionary*) paymentInfo url:(NSString*) url {
	if ([self gracefulDegradate]) {
		return;
	}
	NSMutableDictionary* params = [[NSMutableDictionary alloc] init];
	[params setObject:[self dictToJson:paymentInfo] forKey:@"paymentExecuted"];
	[self showUrl:url params:params];
}

-(void)storeData:(NSString*)key data:(NSDictionary*)data{
[[NSUserDefaults standardUserDefaults] setObject:data forKey:[NSString stringWithFormat:@"NSR_WV_%@",key]];
[[NSUserDefaults standardUserDefaults] synchronize];
}

-(NSDictionary*)retrieveData:(NSString*)key {
	NSDictionary* val = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"NSR_WV_%@",key]];
	return val;
}
@end
