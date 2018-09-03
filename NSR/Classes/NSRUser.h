@interface NSRUser:NSObject

@property(nonatomic, copy) NSString* code;
@property(nonatomic, copy) NSString* email;
@property(nonatomic, copy) NSString* firstname;
@property(nonatomic, copy) NSString* lastname;
@property(nonatomic, copy) NSString* mobile;
@property(nonatomic, copy) NSString* fiscalCode;
@property(nonatomic, copy) NSString* gender;
@property(nonatomic, copy) NSDate* birthday;
@property(nonatomic, copy) NSString* address;
@property(nonatomic, copy) NSString* zipCode;
@property(nonatomic, copy) NSString* city;
@property(nonatomic, copy) NSString* stateProvince;
@property(nonatomic, copy) NSString* country;
@property(nonatomic, copy) NSDictionary* extra;
@property(nonatomic, copy) NSDictionary* locals;

-(id)initWithDict:(NSDictionary*) dict;
-(NSDictionary*)toDict:(BOOL)withLocals;

@end
