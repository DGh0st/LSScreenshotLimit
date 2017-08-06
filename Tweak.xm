@interface SBScreenFlash : NSObject
+(id)mainScreenFlasher;
-(void)flashColor:(id)arg1 withCompletion:(id)arg2;
@end

@interface SpringBoard : UIApplication
-(BOOL)isLocked;
@end

#define kIdentifier @"com.dgh0st.lsscreenshotlimit"
#define kSettingsPath @"/var/mobile/Library/Preferences/com.dgh0st.lsscreenshotlimit.plist"
#define kSettingsChangedNotification (CFStringRef)@"com.dgh0st.lsscreenshotlimit/settingschanged"

typedef enum DisabledAction{
	kFakeFlash = 0,
	kRedFlash,
	kAlert,
	kShakeLockscreen
} DisabledAction;

BOOL isEnabled = YES;
NSInteger screenshotLimit = 10;
DisabledAction disabledAction = kFakeFlash;
NSString *customAlertMessage = @"Really? You thought this would work? Well you thought wrong.";
NSString *customAlertButton = @"Sorry";

NSInteger currentSessionCount = 0;

static void reloadPrefs() {
	CFPreferencesAppSynchronize((CFStringRef)kIdentifier);

	NSDictionary *prefs = nil;
	if ([NSHomeDirectory() isEqualToString:@"/var/mobile"]) {
		CFArrayRef keyList = CFPreferencesCopyKeyList((CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		if (keyList != nil) {
			prefs = (NSDictionary *)CFPreferencesCopyMultiple(keyList, (CFStringRef)kIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
			if (prefs == nil)
				prefs = [NSDictionary new];
			CFRelease(keyList);
		}
	} else {
		prefs = [NSDictionary dictionaryWithContentsOfFile:kSettingsPath];
	}

	isEnabled = [prefs objectForKey:@"isEnabled"] ? [[prefs objectForKey:@"isEnabled"] boolValue] : YES;
	screenshotLimit = [prefs objectForKey:@"screenshotLimit"] ? [[prefs objectForKey:@"screenshotLimit"] intValue] : 10;
	disabledAction = [prefs objectForKey:@"disabledAction"] ? (DisabledAction)[[prefs objectForKey:@"disabledAction"] intValue] : kFakeFlash;
	customAlertMessage = [prefs objectForKey:@"customAlertMessage"] ?: @"Really? You thought this would work? Well you thought wrong.";
	customAlertButton = [prefs objectForKey:@"customAlertButton"] ?: @"Sorry";

	[prefs release];
}

%hook SBScreenshotManager
-(void)saveScreenshotsWithCompletion:(id)arg1 {
	if (isEnabled && [(SpringBoard *)[%c(SpringBoard) sharedApplication] isLocked]) {
		if (currentSessionCount >= screenshotLimit) {
			if (disabledAction == kFakeFlash) {
				[[%c(SBScreenFlash) mainScreenFlasher] flashColor:[UIColor whiteColor] withCompletion:nil];
			} else if (disabledAction == kRedFlash) {
				[[%c(SBScreenFlash) mainScreenFlasher] flashColor:[UIColor redColor] withCompletion:nil];
			} else if (disabledAction == kAlert) {
				UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Screenshot" message:customAlertMessage preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction *cancel = [UIAlertAction actionWithTitle:customAlertButton style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
					[alert dismissViewControllerAnimated:YES completion:nil];
				}];
				[alert addAction:cancel];
				[[[UIApplication sharedApplication].keyWindow rootViewController] presentViewController:alert animated:YES completion:nil];
			} else if (disabledAction == kShakeLockscreen) {
				CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
				animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
				animation.duration = 0.15;
				animation.values = @[ @(-15), @(15), @(-15), @(15), @(-7.5), @(7.5), @(-3), @(3), @(0) ];
				[[[UIApplication sharedApplication].keyWindow rootViewController].view.layer addAnimation:animation forKey:@"shake"];
			}
			return;
		}

		currentSessionCount++;
		%orig(arg1);
	} else {
		%orig(arg1);
	}
}
%end

%hook SBScreenShotter
-(void)saveScreenshotsShowingFlash:(BOOL)arg1 completion:(id)arg2 {
	if (isEnabled && [(SpringBoard *)[%c(SpringBoard) sharedApplication] isLocked]) {
		if (currentSessionCount >= screenshotLimit) {
			if (disabledAction == kFakeFlash) {
				[[%c(SBScreenFlash) mainScreenFlasher] flashColor:[UIColor whiteColor] withCompletion:nil];
			} else if (disabledAction == kRedFlash) {
				[[%c(SBScreenFlash) mainScreenFlasher] flashColor:[UIColor redColor] withCompletion:nil];
			} else if (disabledAction == kAlert) {
				UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Screenshot" message:customAlertMessage preferredStyle:UIAlertControllerStyleAlert];
				UIAlertAction *cancel = [UIAlertAction actionWithTitle:customAlertButton style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
					[alert dismissViewControllerAnimated:YES completion:nil];
				}];
				[alert addAction:cancel];
				[[[UIApplication sharedApplication].keyWindow rootViewController] presentViewController:alert animated:YES completion:nil];
			}
			return;
		}

		currentSessionCount++;
		%orig(arg1, arg2);
	} else {
		%orig(arg1, arg2);
	}
}
%end

%hook SpringBoard
-(void)frontDisplayDidChange:(id)arg1 {
	%orig(arg1);

	if (([arg1 isKindOfClass:%c(SBLockScreenViewController)] || [arg1 isKindOfClass:%c(SBDashBoardViewController)]))
		currentSessionCount = 0;
}
%end

%dtor {
	CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, kSettingsChangedNotification, NULL);
}

%ctor {
	reloadPrefs();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reloadPrefs, kSettingsChangedNotification, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}