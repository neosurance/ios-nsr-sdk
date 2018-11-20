#import <UIKit/UIKit.h>
#import <NSR/NSRWebView.h>

@interface NSRSampleViewController : UIViewController<WKScriptMessageHandler>

@property(strong, nonatomic) NSRWebView* webView;
@property(strong, nonatomic) WKWebViewConfiguration* webConfiguration;

@end
