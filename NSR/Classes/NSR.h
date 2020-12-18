#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import <CoreMotion/CoreMotion.h>
#import <UserNotifications/UserNotifications.h>
#import <sys/utsname.h>
#import "NSREventWebView.h"
#import "NSRControllerWebView.h"
#import "NSRUser.h"

#define NSRLog if(![NSR logDisabled]) NSLog

@protocol NSRSecurityDelegate<NSObject>
-(void)secureRequest:(NSString* _Nullable)endpoint payload:(NSDictionary* _Nullable)payload headers:(NSDictionary* _Nullable)headers completionHandler:(void (^)(NSDictionary* responseObject, NSError *error))completionHandler;
@end

@protocol NSRWorkflowDelegate<NSObject>
-(BOOL)executeLogin:(NSString*)url;
-(NSDictionary*)executePayment:(NSDictionary*)payment url:(NSString*)url;
-(void)confirmTransaction:(NSDictionary*)paymentInfo;
-(void)keepAlive;
-(void)goTo:(NSString*)area;
@end

@interface NSR:NSObject<CLLocationManagerDelegate> {
	NSRControllerWebView* controllerWebView;
	NSREventWebView* eventWebView;
	BOOL stillLocationSent;
	BOOL setupInited;
}
@property(nonatomic, strong) CLLocationManager* locationManager;
@property(nonatomic, strong) CLLocationManager* hardLocationManager;
@property(nonatomic, strong) CLLocationManager* stillLocationManager;
@property(nonatomic, strong) CMMotionActivityManager* motionActivityManager;
@property(nonatomic, strong) id <NSRSecurityDelegate> securityDelegate;
@property(nonatomic, strong) id <NSRWorkflowDelegate> workflowDelegate;
@property(nonatomic, strong) NSMutableArray* motionActivities;

-(BOOL)getBoolean:(NSDictionary*)dict key:(NSString*)key;
+(BOOL)logDisabled;
+(id)sharedInstance;
-(void)setup:(NSDictionary*)settings;
-(void)forgetUser;
-(NSString*)version;
-(NSString*)os;
-(void)authorize:(void(^)(BOOL authorized))completionHandler;
-(void)registerUser:(NSRUser*) user;
-(void)accurateLocation:(double)meters duration:(int)duration extend:(bool)extend;
-(void)accurateLocationEnd;
-(void)showApp;
-(void)showApp:(NSDictionary*)params;
-(void)showUrl:(NSString*)url;
-(void)showUrl:(NSString*)url params:(NSDictionary*)params;
-(void)closeView;
-(void)sendEvent:(NSString*)event payload:(NSDictionary*)payload;
-(void)policies:(NSDictionary*)criteria completionHandler:(void (^)(NSDictionary* responseObject, NSError *error))completionHandler;
-(void)crunchEvent:(NSString*)event payload:(NSDictionary*)payload;
-(void)archiveEvent:(NSString*)event payload:(NSDictionary*)payload;
-(void)sendAction:(NSString*)action policyCode:(NSString*)code details:(NSString*)details;
-(void)showPush:(NSString*)pid push:(NSDictionary*)push delay:(int)delay;
-(void)killPush:(NSString*)pid;
-(void)showPush:(NSDictionary*)push;
-(BOOL)forwardNotification:(UNNotificationResponse*) response API_AVAILABLE(ios(10.0));

-(void)storeData:(NSString*)key data:(NSDictionary*)data;
-(NSDictionary*)retrieveData:(NSString*)key;

-(void)loginExecuted:(NSString*) url;
-(void)paymentExecuted:(NSDictionary*) paymentInfo url:(NSString*) url;

-(NSDictionary*)getSettings;
-(NSString*)getLang;
-(NSDictionary*)getConf;
-(NSDictionary*)getAuth;
-(NSString*)getToken;
-(NSString*)getAppUrl;
-(NSRUser*)getUser;
-(NSString*)uuid;
-(NSString*)dictToJson:(NSDictionary*)dict;
-(NSBundle*)frameworkBundle;

-(void)registerWebView:(NSRControllerWebView*)controllerWebView;
-(void)clearWebView;

-(void)resetCruncher;

-(void)continueInitJob;

@end
