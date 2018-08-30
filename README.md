# ![](https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/IOS_logo.svg/48px-IOS_logo.svg.png) iOS - Neosurance SDK 

- Collects info from device sensors and from the hosting app
- Exchanges info with the AI engines
- Sends the push notification
- Displays a landing page
- Displays the list of the purchased policies

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

NeosuranceSDK(NSR) is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'NSR'
```

## Requirements

1. Inside your **AndroidManifest.xml** be sure to have the following permissions:

	```xml
	<uses-permission android:name="android.permission.INTERNET" />
	<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
	<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
	<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
	<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
	<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
	<uses-permission android:name="android.permission.CAMERA" />
	<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
	<uses-permission android:name="com.google.android.gms.permission.ACTIVITY_RECOGNITION" />
	```
2. Inside your **AndroidManifest.xml** be sure to have the following activity:

	```xml
	<activity
		android:name="eu.neosurance.sdk.NSRActivityWebView"
		android:configChanges="orientation|screenSize|keyboardHidden"
		android:screenOrientation="portrait"
		android:theme="@style/AppTheme.NSRWebView" />
	```

3. Inside your **values/styles.xml** be sure to have the following style:
	
	```xml
	<style name="AppTheme.NSRWebView">
		<item name="windowNoTitle">true</item>
		<item name="windowActionBar">false</item>
		<item name="android:windowFullscreen">false</item>
		<item name="android:windowContentOverlay">@null</item>
	</style>
	```

## Use

1. ### setup
	Earlier in your application startup flow (tipically inside the **onCreate** method of your main activity) call the **setup** method using

	**base_url**: provided by us, used only if no *securityDelegate* is configured  
	**code**: the community code provided by us  
	**secret_key**: the community secret key provided by us  
	**dev_mode** *optional*: [0|1] activate the *developer mode*, all the webView in your app will be inspectable  
	**ask_permission** *optional*: [0|1] the SDK will use default dialogs to ask for the required permissions once in application life  
	**push_icon** *optional*: [resource id] the icon used in notification, if none provided neosurance badge will be used
	
	```java
	JSONObject settings = new JSONObject();
	settings.put("base_url", "https://<provided base url>");
	settings.put("code", "<provided code>");
	settings.put("secret_key", "<provided secret_key>");
	settings.put("dev_mode", 1);
	settings.put("ask_permission", 0);
	settings.put("push_icon", R.drawable.pushIcon);
	NSR.getInstance(this).setup(settings);
	```
2. ### setSecurityDelegate *optional*
	If the communications must be secured using any policy.  
	A **securityDelegate** implementing the following interface can be configured:
	
	```java
	public interface NSRSecurityDelegate {
		void secureRequest(Context ctx, String endpoint, JSONObject payload, JSONObject headers, NSRSecurityResponse completionHandler) throws Exception;
	}
	```
	It's *mandatory* that your **securityDelegate** implement the **default constructor**.
	
	Then use the ***setSecurityDelegate*** method
	
	```java
	NSR.getInstance(this).setSecurityDelegate(<yourSecurityDelegate>);
	```
	
3. ### setWorkFlowDelegate *optional*  
	If the purchase workflow must be interrupted in order to perform user login or to perform payment.  
	A **workflowDelegate** implementing the following interface must be configured:
	
	```java
	public interface NSRWorkflowDelegate {
		boolean executeLogin(Context ctx, String url);
		JSONObject executePayment(Context ctx, JSONObject payment, String url);
	}
	```
	
	It's *mandatory* that your ** workflowDelegate** implement the **default constructor**.
	
	Then use the ***setWorkflowDelegate*** method

	```java
	NSR.getInstance(this).setWorkflowDelegate(<yourWorkflowDelegate>);
	```
	
	when login or payment is performed you must call the methods **loginExecuted** and **paymentExecuted** to resume the workflow
	
	```java
	NSR.getInstance(this).loginExecuted(<theGivenUrl>);
	...
	NSR.getInstance(this).paymentExecuted(<paymentTransactionInfo>,<theGivenUrl>);
	```
	
4. ### registerUser  
	When the user is recognized by your application, register him in our *SDK* creating an **NSRUser** and using the **registerUser** method.  
	The **NSRUser** has the following fields:
	
	**code**: the user code in your system (can be equals to the email)  
	**email**: the email is the real primary key  
	**firstname** *optional*  
	**lastname** *optional*  
	**mobile** *optional*  
	**fiscalCode** *optional*  
	**gender** *optional*  
	**birthday** *optional*  
	**address** *optional*  
	**zipCode** *optional*  
	**city** *optional*  
	**stateProvince** *optional*  
	**country** *optional*  
	**extra** *optional*: will be shared with us  
	**locals** *optional*: will not be exposed outside the device  

	```java
	NSRUser user = new NSRUser();
	user.setEmail("jhon.doe@acme.com");
	user.setCode("jhon.doe@acme.com");
	user.setFirstName("Jhon");
	user.setLastName("Doe");
	NSR.getInstance(this).registerUser(user);
	```
5. ### forgetUser *optional*
	If you want propagate user logout to the SDK use the **forgetUser** method.  
	Note that without user no tracking will be performed.
	
	```java
	NSR.getInstance(this). forgetUser();
	```
6. ### showApp *optional*
	Is possible to show the list of the purchased policies (*communityApp*) using the **showApp** methods
	
	```java
	NSR.getInstance(this).showApp();
	```
	or
	
	```java
	JSONObject params = new JSONObject();
	params.put("page", "profiles");
	NSR.getInstance(this).showApp(params);
	```
7. ### showUrl *optional*
	If custom web views are needed the **showUrl** methods can be used
	
	```java
	NSR.getInstance(this).showUrl(params);
	```
	or
	
	```java
	JSONObject params = new JSONObject();
	params.put("privacy", true);
	NSR.getInstance(this).showUrl(params);
	```
8. ### sendEvent *optional*
	The application can send explicit events to the system with **sendEvent** method
	
	```java
	JSONObject payload = new JSONObject();
	payload.put("latitude", latitude);
	payload.put("longitude", longitude);
	NSR.getInstance(this).sendEvent("position", payload);
	```
	
9. ### sendAction *optional*
	The application can send tracing information events to the system with **sendAction** method
	
	```java          
	NSR.getInstance(this).sendAction("read", "xxxx123xxxx", "general condition read");
	```

## Author

info@neosurance.eu

## License

NeosuranceSDK is available under the MIT license. See the LICENSE file for more info.

