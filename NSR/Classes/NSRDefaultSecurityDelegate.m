#import "NSRDefaultSecurityDelegate.h"

@implementation NSRDefaultSecurityDelegate

-(void)secureRequest:(NSString*)endpoint payload:(NSDictionary*)payload headers:(NSDictionary*)headers completionHandler:(void (^)(NSDictionary* responseObject, NSError *error))completionHandler {
	NSString* url = [[[NSR sharedInstance] getSettings][@"base_url"] stringByAppendingFormat:@"%@", endpoint];
	NSRLog(@"%@", url);
	AFJSONRequestSerializer *serializer = [AFJSONRequestSerializer serializer];
	AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
	if(headers != nil) {
		for(NSString* key in [headers keyEnumerator]) {
			NSString* value = [headers objectForKey:key];
			[serializer setValue:value forHTTPHeaderField:key];
		}
	}
	[serializer setValue:@"application/json;charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
	manager.requestSerializer = serializer;
	
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:(payload != nil ? payload : [[NSDictionary alloc] init]) options:0 error:&error];
	NSDictionary *parameters = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
	
	[manager POST:url parameters:parameters progress:nil success:^(NSURLSessionDataTask *task, id responseObject) {
		NSRLog(@"Response: %@", responseObject);
		completionHandler(responseObject, nil);
	} failure:^(NSURLSessionDataTask *task, NSError *error) {
		NSRLog(@"Error: %@", error);
		completionHandler(nil, error);
	}];
}

@end
