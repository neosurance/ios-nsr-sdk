#import <WebKit/WebKit.h>
#import <MapKit/MapKit.h>

@interface NSREventWebView : NSObject<WKScriptMessageHandler>

@property (strong, nonatomic) WKWebView* webView;
@property (strong, nonatomic) WKWebViewConfiguration* webConfiguration;

-(void) synch;
-(void) crunchEvent:(NSString*)event payload:(NSDictionary*)payload;

@end
