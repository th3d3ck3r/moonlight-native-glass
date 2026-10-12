#pragma once
#import <AppKit/AppKit.h>
static NSView* titlebarFindView(NSView* view, NSString* identifier) {
    if ([view.identifier isEqual:identifier]) return view;
    for (NSView* child in view.subviews) if (NSView* found=titlebarFindView(child,identifier)) return found;
    return nil;
}
static NSView* titlebarRoot(NSWindow* window) {
    if (!(window.styleMask & NSWindowStyleMaskTitled)) {
        NSView* root=titlebarFindView(window.contentView.superview,@"NativeStreamTitlebar");
        return root.hiddenOrHasHiddenAncestor ? nil : root;
    }
    for (NSTitlebarAccessoryViewController* accessory in window.titlebarAccessoryViewControllers)
        if ([accessory.view.identifier isEqual:@"NativeStreamTitlebar"]) return accessory.view;
    return nil;
}
static NSButton* titlebarButton(NSWindow* window, NSString* identifier) {
    NSView* view=titlebarFindView(titlebarRoot(window),identifier);
    return [view isKindOfClass:NSButton.class] ? (NSButton*)view : nil;
}
