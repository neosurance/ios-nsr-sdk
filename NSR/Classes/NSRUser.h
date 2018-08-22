@interface NSRUser : NSObject {
    NSString* code;
    NSString* email;
    NSString* firstname;
    NSString* lastname;
    NSString* mobile;
    NSString* fiscalCode;
    NSString* gender;
    NSDate* birthday;
    NSString* address;
    NSString* zipCode;
    NSString* city;
    NSString* stateProvince;
    NSString* country;
    NSDictionary* extra;
    NSDictionary* locals;
}

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

- (void)fromDict:(NSDictionary*)dict;
- (NSDictionary*)toDict:(BOOL)withLocals;

@end
