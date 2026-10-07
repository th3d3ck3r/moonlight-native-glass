#import <AppKit/AppKit.h>

// Only the windowless adapter calls this. The stock Session/SDL process keeps
// its ordinary activation policy, menu bar and keyboard focus.
void configureNativeBackgroundApplication()
{
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}
