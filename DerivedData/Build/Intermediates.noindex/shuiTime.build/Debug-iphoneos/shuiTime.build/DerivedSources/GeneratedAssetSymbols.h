#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "LaunchIcon" asset catalog image resource.
static NSString * const ACImageNameLaunchIcon AC_SWIFT_PRIVATE = @"LaunchIcon";

/// The "xiaoshui" asset catalog image resource.
static NSString * const ACImageNameXiaoshui AC_SWIFT_PRIVATE = @"xiaoshui";

#undef AC_SWIFT_PRIVATE
