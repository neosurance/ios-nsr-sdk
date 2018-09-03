#import "NSRUser.h"

@implementation NSRUser

-(id)initWithDict:(NSDictionary*) dict  {
	if (self = [super init]) {
		if([dict objectForKey:@"code"] != nil) {
			self.code = [dict objectForKey:@"code"];
		}
		if([dict objectForKey:@"email"] != nil) {
			self.email = [dict objectForKey:@"email"];
		}
		if([dict objectForKey:@"firstname"] != nil) {
			self.firstname = [dict objectForKey:@"firstname"];
		}
		if([dict objectForKey:@"lastname"] != nil) {
			self.lastname = [dict objectForKey:@"lastname"];
		}
		if([dict objectForKey:@"mobile"] != nil) {
			self.mobile = [dict objectForKey:@"mobile"];
		}
		if([dict objectForKey:@"fiscalCode"] != nil) {
			self.fiscalCode = [dict objectForKey:@"fiscalCode"];
		}
		if([dict objectForKey:@"gender"] != nil) {
			self.gender = [dict objectForKey:@"gender"];
		}
		if([dict objectForKey:@"birthday"] != nil) {
			self.birthday = [dict objectForKey:@"birthday"];
		}
		if([dict objectForKey:@"address"] != nil) {
			self.address = [dict objectForKey:@"address"];
		}
		if([dict objectForKey:@"zipCode"] != nil) {
			self.zipCode = [dict objectForKey:@"zipCode"];
		}
		if([dict objectForKey:@"city"] != nil) {
			self.city = [dict objectForKey:@"city"];
		}
		if([dict objectForKey:@"stateProvince"] != nil) {
			self.stateProvince = [dict objectForKey:@"stateProvince"];
		}
		if([dict objectForKey:@"country"] != nil) {
			self.country = [dict objectForKey:@"country"];
		}
		if([dict objectForKey:@"extra"] != nil) {
			self.extra = [dict objectForKey:@"extra"];
		}
		if([dict objectForKey:@"locals"] != nil) {
			self.locals = [dict objectForKey:@"locals"];
		}
	}
	return self;
}

-(NSDictionary*)toDict:(BOOL) withLocals {
	NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
	if(self.code != nil) {
		[dict setObject:self.code forKey:@"code"];
	}
	if(self.email != nil) {
		[dict setObject:self.email forKey:@"email"];
	}
	if(self.firstname != nil) {
		[dict setObject:self.firstname forKey:@"firstname"];
	}
	if(self.lastname != nil) {
		[dict setObject:self.lastname forKey:@"lastname"];
	}
	if(self.mobile != nil) {
		[dict setObject:self.mobile forKey:@"mobile"];
	}
	if(self.fiscalCode != nil) {
		[dict setObject:self.fiscalCode forKey:@"fiscalCode"];
	}
	if(self.gender != nil) {
		[dict setObject:self.gender forKey:@"gender"];
	}
	if(self.birthday != nil) {
		[dict setObject:self.birthday forKey:@"birthday"];
	}
	if(self.address != nil) {
		[dict setObject:self.address forKey:@"address"];
	}
	if(self.zipCode != nil) {
		[dict setObject:self.zipCode forKey:@"zipCode"];
	}
	if(self.city != nil) {
		[dict setObject:self.city forKey:@"city"];
	}
	if(self.stateProvince != nil) {
		[dict setObject:self.stateProvince forKey:@"stateProvince"];
	}
	if(self.country != nil) {
		[dict setObject:self.country forKey:@"country"];
	}
	if(self.extra != nil) {
		[dict setObject:self.extra forKey:@"extra"];
	}
	if(self.locals != nil && withLocals) {
		[dict setObject:self.locals forKey:@"locals"];
	}
	return dict;
}

@end
