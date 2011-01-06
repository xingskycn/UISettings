#import <dlfcn.h>
#import <SpringBoard/SpringBoard.h>
#include "substrate.h"
#import "notify.h"

@interface UIToggle : NSObject {
	void* lib_handle;
}
-(UIToggle*)initWithName:(NSString*)name;
@end


@interface Hook : NSObject {
	UIButton* triggerButton;
	UIView* contentView;
	SBIconLabel* label;
}
+(Hook*)sharedHook;
-(Hook*)initWithButton:(UIButton*)btn andView:(UIView*)view andIconLabel:(SBIconLabel*)label;
@end
@interface UISettingsToggleController : NSObject {
	UIScrollView* toggleContainer;
	NSMutableArray* toggleArray;
	NSMutableArray* dispatcherArray;
}
+ (UISettingsToggleController*)sharedController;
-(CGRect)autoRect;
-(UIButton*)createToggleWithAction:(SEL)action title:(NSString*)title target:(id)target;
@end

@interface UISettingsCore : NSObject {
	UIButton* triggerButton;
	UIView* contentView;
	SBIconLabel* label;
	NSMutableArray* toggles;
	NSMutableArray* viewsInOriginalMenu;
	UIScrollView* toggleContainer;
	id hook;
	int state;
}
+ (UISettingsCore*)sharedSettings;
- (void)hook:(id)sender;
- (void)creatr;
- (void)destroyr;
- (void)redraw;
-(NSMutableArray*) dylibs;
@end

@implementation UISettingsCore
static UISettingsCore* sharedInstance = nil;
-(BOOL)doIhazToggles {
	if ([[self dylibs] count]==0) {
		return NO;
	}
	return YES;
}
-(UIScrollView*)toggleContainer{
	return toggleContainer;
}
static NSMutableArray* kDylibList=nil;
-(NSMutableArray*) dylibs
{
	if (kDylibList==nil) {
		NSLog(@"[UICore]: Initializing dylibs array");
		kDylibList=[[NSMutableArray alloc] init];
		NSFileManager* fm = [[[NSFileManager alloc] init] autorelease];
		NSEnumerator *e = [[fm contentsOfDirectoryAtPath:@"/Library/UISettings/" error:nil] objectEnumerator];
		while (NSString* path=[e nextObject]) {
			if ([[path pathExtension] isEqualToString: @"dylib"]) {
				[kDylibList addObject:path];
			}
		}		
	}
	return kDylibList;
}
-(void)creatr
{
	if(!viewsInOriginalMenu){
		viewsInOriginalMenu=[[NSMutableArray alloc]init];
	}
	int c=0;
	for (UIView* view in contentView.subviews) {
		if(c==0){
			c++;
			continue;
		}
		[view setHidden:YES];
		[viewsInOriginalMenu addObject:view];
	}
	NSEnumerator *e;
	e=[[self dylibs] objectEnumerator];
	while (NSString* path=[e nextObject]) {
		NSLog(@"[UICore]: Loading dylib %@", path);
		[[UIToggle alloc] initWithName:path];
		NSLog(@"[%@]: Loaded", path);
	}
	[self redraw];
}
- (void)destroyr {
	for (UIView* view in viewsInOriginalMenu) {
		[view setHidden:NO];
	}
	[toggleContainer setHidden:YES];
	state=2;
}
-(void) redraw {
	for (UIView* view in viewsInOriginalMenu) {
		[view setHidden:YES];
	}
	notify_post("com.qwerty.uisettings.reload");
	[toggleContainer setHidden:NO];
	state=1;
	
}
-(void)hookInBackground
{
	NSAutoreleasePool *pool;
	pool=[[NSAutoreleasePool alloc] init];
	if(!toggleContainer){
		//CGRect frame;
		toggleContainer = [[UIScrollView alloc] initWithFrame:CGRectMake(76, 0, 244, 94)];
		toggleContainer.bounces = YES;
		toggleContainer.contentSize = CGSizeMake(contentView.frame.size.width, contentView.frame.size.height);	
		[contentView addSubview:toggleContainer];
	}		
	UILabel* myLabel;
	myLabel = [[UILabel alloc] initWithFrame:label.frame];//CGRectMake(22, 16, 56, 56)];
	myLabel.text=@"Loading...";
	myLabel.backgroundColor = [UIColor clearColor];
	myLabel.font = [UIFont boldSystemFontOfSize:10.0];
	myLabel.textColor = [UIColor whiteColor];
	myLabel.textAlignment = UITextAlignmentCenter;	
	[toggleContainer addSubview:myLabel];
	if (state==0) {
		[self creatr];
	} else if (state==1) {
		[self destroyr];
	} else if (state==2) {
		[self redraw];
	} else {
		NSLog(@"[UICore]: This is a joke.");
	}
	[myLabel setHidden:YES];
	[pool drain];
}
-(void)hook:(id)sender {
	if ([self doIhazToggles]==YES) {
		[self performSelectorInBackground:@selector(hookInBackground) withObject:nil];
	}  else {
		[[[UIAlertView alloc] initWithTitle:@"UISettings - Simple Settings System in SpringBoard" message:@"Hello. You don't have any toggle. UISettings needs some toggles. Go grab them on Cydia." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] show];
	}
}
-(UISettingsCore*) init {
	[super init];
	state=0;
	Class Hook=objc_getClass("Hook");
	hook=[Hook sharedHook];
	contentView=MSHookIvar<UIView*>(hook, "contentView");
	label=MSHookIvar<SBIconLabel*>(hook, "label");
	triggerButton=MSHookIvar<UIButton*>(hook, "triggerButton");
	return self;
}
+ (UISettingsCore*)sharedSettings
{
	if (sharedInstance == nil) {
		sharedInstance = [[self alloc] init];
		//[sharedInstance load];
    }
    return sharedInstance;
}
@end
// vim:ft=objc

@implementation UIToggle

-(UIToggle*)initWithName:(NSString*)name
{
	[self init];
	NSString *fpath=[@"/Library/UISettings/" stringByAppendingString:name];
	lib_handle = dlopen([fpath UTF8String], RTLD_LAZY | RTLD_LOCAL);
	if (!lib_handle) {
		NSLog(@"[UICore]: Error: %s", dlerror());
		return nil;
	}
	return self;
}


@end



@implementation UISettingsToggleController
static UISettingsToggleController* sharedIInstance = nil;

+ (UISettingsToggleController*)sharedController
{
    @synchronized(self)
    {
        if (sharedIInstance == nil) {
			sharedIInstance = [[self alloc] init];
		}
    }
	NSLog(@"StillAlive here");
    return sharedIInstance;
}
#pragma mark coreDispatcher
-(void)coreDispatcher:(UIButton*)sender {
	NSEnumerator *e = [dispatcherArray objectEnumerator];
	NSArray* object;
	while ((object = [e nextObject])) {
		if ([object objectAtIndex:0]==sender) {
			NSLog(@"CoreDispatcher: found selector");
			if (sender.tag==0) {
				[[object objectAtIndex:2] performSelector:NSSelectorFromString([object objectAtIndex:1 ])];
				
			} else {
				[[object objectAtIndex:2] performSelector:NSSelectorFromString([object objectAtIndex:1 ]) withObject:[[NSNumber alloc ]initWithInt:sender.tag]];
			}
			
			break;
		}
	}	
}
#pragma mark AddStuff
-(UIButton*)createToggleWithAction:(SEL)action title:(NSString*)title target:(id)target { // FIXME: correct this shit
	id hokr = [UISettingsCore sharedSettings];
	toggleContainer=MSHookIvar<UIScrollView*>(hokr, "toggleContainer"); // b00m
	if(!toggleContainer)
	{
		NSLog(@"ToggleContainer is nil");
	}
	if(toggleArray==nil) {
		NSLog(@"Initializing Array");
		toggleArray = [[NSMutableArray alloc] init];  
	}
	if(dispatcherArray==nil) {
		NSLog(@"Initializing Array");
		dispatcherArray = [[NSMutableArray alloc] init];  
	}
	// Dispatcher
	UIButton *myButton;
	if(title==nil){
		myButton = [UIButton buttonWithType:UIButtonTypeCustom];
	} else {
		myButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
		myButton.titleLabel.adjustsFontSizeToFitWidth = TRUE;
		myButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
		myButton.titleLabel.numberOfLines = 3; // maximum: 3!
		myButton.titleLabel.textAlignment = UITextAlignmentCenter;
	}
	myButton.frame = [self autoRect];
	myButton.tag=0;
	[myButton setTitle:title forState:UIControlStateNormal];
	[myButton addTarget:self action:@selector(coreDispatcher:) forControlEvents:UIControlEventTouchUpInside];
	[toggleContainer addSubview:myButton];
	NSArray* dispatcherElement=[[NSArray alloc] initWithObjects:myButton,NSStringFromSelector(action), target, nil];
	[dispatcherArray addObject:dispatcherElement];
	[toggleArray addObject:myButton];  
	return myButton;
}
-(CGRect)autoRect {
	toggleContainer.contentSize = CGSizeMake((20+56)*([toggleArray count]+1)+22, toggleContainer.frame.size.height);
	return CGRectMake((20+56)*([toggleArray count])+22, 16, 56, 56);
}
@end