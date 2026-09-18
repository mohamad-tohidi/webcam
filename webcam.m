// Floating always-on-top webcam widget for macOS.
// Single-file Objective-C: Cocoa window + AVFoundation capture.
//
// Build:  ./build.sh
// Run:    open Webcam.app        (or ./Webcam.app/Contents/MacOS/Webcam)

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

static CGFloat gWidth  = 340.0;   // default window width  (vertical rectangle)
static CGFloat gHeight = 620.0;   // default window height
static CGFloat const kCornerRadius = 22.0;

#pragma mark - Content view (holds the live preview, handles keys/resize)

@interface WebcamView : NSView
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

@implementation WebcamView
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder  { return YES; }

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.previewLayer.frame = self.bounds;
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) {                       // ESC
        [NSApp terminate:nil];
        return;
    }
    NSString *s = event.charactersIgnoringModifiers.lowercaseString;
    if ([s isEqualToString:@"q"]) {                  // q
        [NSApp terminate:nil];
        return;
    }
    [super keyDown:event];
}
@end

#pragma mark - Floating window subclass
// A borderless window must opt in to becoming key/main.
@interface FloatingWindow : NSWindow
@end
@implementation FloatingWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

#pragma mark - App delegate

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) WebcamView *view;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    [self buildMenu];
    [self buildWindow];
    [self requestCameraAndStart];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)buildMenu {
    NSMenu *menubar = [NSMenu new];
    NSMenuItem *appItem = [NSMenuItem new];
    [menubar addItem:appItem];
    NSApp.mainMenu = menubar;

    NSMenu *appMenu = [NSMenu new];
    [appMenu addItemWithTitle:@"Quit Webcam" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
}

- (void)buildWindow {
    NSScreen *screen = NSScreen.mainScreen;
    NSRect visible = screen.visibleFrame;

    // Keep the default rectangle inside the screen.
    CGFloat h = MIN(gHeight, visible.size.height - 40.0);
    CGFloat w = MIN(gWidth,  visible.size.width  - 40.0);

    // Top-right corner placement.
    NSRect frame = NSMakeRect(NSMaxX(visible) - w - 24.0,
                              NSMaxY(visible) - h - 24.0,
                              w, h);

    // BORDERLESS: deliberately no title bar at all.
    // Why: AeroSpace (the tiling WM) treats any window with an AX close
    // button as a normal window, binds it to the current workspace, and moves
    // it off-screen when you switch workspaces. A titled window exposes
    // AXCloseButton even with the Closable bit removed (macOS creates it
    // disabled), so the only reliable way to make AeroSpace ignore us is to
    // have no titlebar at all. With our .accessory activation policy,
    // AeroSpace's isWindowHeuristic classifies a borderless, close-button-less
    // window as a non-manageable "popup": it is never bound to a workspace
    // and never moved/hidden. macOS canJoinAllSpaces then keeps it visible on
    // every space and above everything.
    NSWindowStyleMask style = NSWindowStyleMaskBorderless | NSWindowStyleMaskResizable;

    NSWindow *win = [[FloatingWindow alloc] initWithContentRect:frame
                                                     styleMask:style
                                                       backing:NSBackingStoreBuffered
                                                         defer:NO];

    win.title = @"";
    win.movableByWindowBackground = YES;
    win.opaque = NO;
    win.backgroundColor = [NSColor clearColor];
    win.hasShadow = YES;
    win.level = NSFloatingWindowLevel;   // always on top of normal windows
    win.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                             NSWindowCollectionBehaviorFullScreenAuxiliary;
    win.minSize = NSMakeSize(120, 120);
    win.delegate = self;

    // Rounded, clipped content layer.
    NSView *content = win.contentView;
    content.wantsLayer = YES;
    content.layer.cornerRadius = kCornerRadius;
    content.layer.masksToBounds = YES;
    content.layer.backgroundColor = NSColor.blackColor.CGColor;
    content.layer.borderWidth = 1.0;
    content.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.10].CGColor;

    WebcamView *view = [[WebcamView alloc] initWithFrame:content.bounds];
    view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:view];

    self.window = win;
    self.view = view;

    [win makeKeyAndOrderFront:nil];
    [win makeFirstResponder:view];
}

#pragma mark Camera

- (void)requestCameraAndStart {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (device == nil) {
        [self fail:@"No camera found."];
        return;
    }

    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                             completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!granted) {
                [self fail:@"Camera access denied.\n\nAllow it in System Settings > Privacy & Security > Camera, then relaunch."];
                return;
            }
            [self startSessionWithDevice:device];
        });
    }];
}

- (void)startSessionWithDevice:(AVCaptureDevice *)device {
    NSError *err = nil;
    AVCaptureDeviceInput *input =
        [AVCaptureDeviceInput deviceInputWithDevice:device error:&err];

    if (input == nil) {
        [self fail:[NSString stringWithFormat:@"Could not open camera:\n%@", err.localizedDescription]];
        return;
    }

    AVCaptureSession *session = [AVCaptureSession new];
    session.sessionPreset = AVCaptureSessionPresetHigh;   // full-quality 1080p-class
    if ([session canAddInput:input]) {
        [session addInput:input];
    }

    AVCaptureVideoPreviewLayer *preview =
        [AVCaptureVideoPreviewLayer layerWithSession:session];
    preview.videoGravity = AVLayerVideoGravityResizeAspectFill; // fill the vertical box
    preview.frame = self.view.bounds;
    preview.cornerRadius = kCornerRadius;
    preview.masksToBounds = YES;

    [self.view.layer addSublayer:preview];
    self.view.previewLayer = preview;
    self.session = session;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [session startRunning];
    });
}

- (void)fail:(NSString *)message {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Webcam";
    alert.informativeText = message;
    [alert runModal];
    [NSApp terminate:nil];
}

#pragma mark Window / lifecycle

- (void)windowWillClose:(NSNotification *)note {
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)note {
    [self.session stopRunning];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

#pragma mark - Args + main

static void parseArgs(int argc, const char **argv) {
    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--width") == 0) && i + 1 < argc) {
            gWidth = atof(argv[++i]);
        } else if ((strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--height") == 0) && i + 1 < argc) {
            gHeight = atof(argv[++i]);
        } else if (strcmp(argv[i], "-H") == 0 || strcmp(argv[i], "--help") == 0) {
            printf("usage: Webcam [-w width] [-h height]\n"
                   "  vertical rectangle floating webcam window\n"
                   "  ESC or q quits, drag edges to resize\n");
            exit(0);
        }
    }
    if (gWidth  < 120.0) gWidth  = 120.0;
    if (gHeight < 120.0) gHeight = 120.0;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        parseArgs(argc, argv);
        NSApplication *app = [NSApplication sharedApplication];
        app.activationPolicy = NSApplicationActivationPolicyAccessory; // no Dock icon
        AppDelegate *delegate = [AppDelegate new];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
