#import "TwiliochatPlugin.h"
#if __has_include(<twiliochat/twiliochat-Swift.h>)
#import <twiliochat/twiliochat-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "twiliochat-Swift.h"
#endif

@implementation TwiliochatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTwiliochatPlugin registerWithRegistrar:registrar];
}
@end
