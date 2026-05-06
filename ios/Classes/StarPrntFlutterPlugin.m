#import "StarPrntFlutterPlugin.h"
#if __has_include(<star_prnt_flutter/star_prnt_flutter-Swift.h>)
#import <star_prnt_flutter/star_prnt_flutter-Swift.h>
#else
// Used for backwards compatibility with older build systems that don't
// generate the modular header.
#import "star_prnt_flutter-Swift.h"
#endif

@implementation StarPrntFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftStarPrntFlutterPlugin registerWithRegistrar:registrar];
}
@end
