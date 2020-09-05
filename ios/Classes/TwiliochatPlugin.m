#import "TwiliochatPlugin.h"
#import <twiliochat/twiliochat-Swift.h>

@implementation TwiliochatPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTwiliochatPlugin registerWithRegistrar:registrar];
}
@end
