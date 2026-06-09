extern char g_config_file[4096];

@interface status_bar_pill_view : NSView
@property (copy, nonatomic) NSString *title;
@end

@implementation status_bar_pill_view

static bool status_bar_is_dark_appearance(NSAppearance *appearance)
{
    if (!appearance) appearance = [NSAppearance currentDrawingAppearance];

    NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[
        NSAppearanceNameAqua,
        NSAppearanceNameDarkAqua,
        NSAppearanceNameVibrantLight,
        NSAppearanceNameVibrantDark,
        NSAppearanceNameAccessibilityHighContrastAqua,
        NSAppearanceNameAccessibilityHighContrastDarkAqua,
        NSAppearanceNameAccessibilityHighContrastVibrantLight,
        NSAppearanceNameAccessibilityHighContrastVibrantDark
    ]];

    return [match containsString:@"Dark"];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void) dirtyRect;

    NSRect bounds = self.bounds;
    CGFloat radius = 5.0f;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 0.5f, 0.5f)
                                                         xRadius:radius
                                                         yRadius:radius];

    bool is_dark = status_bar_is_dark_appearance([self effectiveAppearance]);
    NSColor *fill_color = is_dark ? [NSColor whiteColor] : [NSColor blackColor];
    NSColor *text_color = is_dark ? [NSColor blackColor] : [NSColor whiteColor];

    [fill_color setFill];
    [path fill];

    if (!self.title.length) return;

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: text_color
    };

    NSSize text_size = [self.title sizeWithAttributes:attributes];
    NSPoint origin = NSMakePoint((bounds.size.width - text_size.width) / 2.0f,
                                 (bounds.size.height - text_size.height) / 2.0f);
    [self.title drawAtPoint:origin withAttributes:attributes];
}

- (NSSize)intrinsicContentSize
{
    if (!self.title.length) return NSMakeSize(24.0f, 18.0f);

    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium]
    };

    NSSize text_size = [self.title sizeWithAttributes:attributes];
    return NSMakeSize(text_size.width + 12.0f, MAX(text_size.height + 4.0f, 18.0f));
}

- (void)setTitle:(NSString *)title
{
    _title = [title copy];
    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay:YES];
}

- (void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    [self setNeedsDisplay:YES];
}

@end

@interface status_bar_delegate : NSObject
@property (copy, nonatomic) NSString *clipboard_text;
@end

@implementation status_bar_delegate

- (void)focusSpace:(id)sender
{
    NSNumber *sid_number = [sender representedObject];
    if (!sid_number) return;

    status_bar_focus_space([sid_number unsignedLongLongValue]);
}

- (void)copyToClipboard:(id)sender
{
    (void) sender;
    if (!self.clipboard_text.length) return;

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:self.clipboard_text forType:NSPasteboardTypeString];
}

- (void)openConfig:(id)sender
{
    (void) sender;
    status_bar_open_config();
}

- (void)reloadConfig:(id)sender
{
    (void) sender;
    status_bar_reload_config();
}

- (void)quit:(id)sender
{
    (void) sender;
    exit(EXIT_SUCCESS);
}

@end

static NSStatusItem *g_status_item;
static status_bar_pill_view *g_pill_view;
static status_bar_delegate *g_status_delegate;
static bool g_status_bar_enabled;

static NSAttributedString *status_bar_attributed_header(NSString *text)
{
    return [[NSAttributedString alloc] initWithString:text
                                           attributes:@{
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
        NSFontAttributeName: [NSFont systemFontOfSize:12.0]
    }];
}

static NSAttributedString *status_bar_attributed_workspace(NSString *primary, NSString *secondary)
{
    NSMutableAttributedString *title = [[NSMutableAttributedString alloc] init];

    [title appendAttributedString:[[NSAttributedString alloc] initWithString:primary
                                                                attributes:@{
        NSForegroundColorAttributeName: [NSColor labelColor],
        NSFontAttributeName: [NSFont systemFontOfSize:13.0]
    }]];

    if (secondary.length > 0) {
        NSString *suffix = [NSString stringWithFormat:@" - %@", secondary];
        [title appendAttributedString:[[NSAttributedString alloc] initWithString:suffix
                                                                    attributes:@{
            NSForegroundColorAttributeName: [NSColor secondaryLabelColor],
            NSFontAttributeName: [NSFont systemFontOfSize:13.0]
        }]];
    }

    return title;
}

static NSMenuItem *status_bar_disabled_item(NSString *title)
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                  action:NULL
                                           keyEquivalent:@""];
    [item setEnabled:NO];
    [item setAttributedTitle:status_bar_attributed_header(title)];
    return item;
}

static NSString *status_bar_config_editor_name(void)
{
    char config_path[4096];

    if (g_config_file[0] != '\0') {
        snprintf(config_path, sizeof(config_path), "%s", g_config_file);
    } else if (!get_config_file("yabairc", config_path, sizeof(config_path))) {
        return @"editor";
    }

    NSURL *config_url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:config_path]];
    NSURL *app_url = [[NSWorkspace sharedWorkspace] URLForApplicationToOpenURL:config_url];
    if (!app_url) return @"editor";

    NSString *app_name = [[NSFileManager defaultManager] displayNameAtPath:[app_url path]];
    if (!app_name.length) return @"editor";

    return app_name;
}

static void status_bar_refresh_main(void)
{
    if (!g_status_bar_enabled || !g_status_item || !g_pill_view) return;

    struct status_bar_snapshot snapshot = {0};
    if (!status_bar_collect_snapshot(&snapshot)) return;

    NSString *title = [NSString stringWithUTF8String:snapshot.title];
    [g_pill_view setTitle:title];

    NSStatusBarButton *button = [g_status_item button];
    NSSize pill_size = [g_pill_view intrinsicContentSize];
    [g_pill_view setFrame:NSMakeRect(0.0f, 0.0f, pill_size.width, pill_size.height)];
    [button setFrameSize:pill_size];
    [g_status_item setLength:pill_size.width];

    g_status_delegate.clipboard_text = [NSString stringWithUTF8String:snapshot.clipboard];

    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *version_item = status_bar_disabled_item([NSString stringWithUTF8String:snapshot.version]);
    [menu addItem:version_item];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *copy_item = [[NSMenuItem alloc] initWithTitle:@"Copy to clipboard"
                                                       action:@selector(copyToClipboard:)
                                                keyEquivalent:@"c"];
    [copy_item setTarget:g_status_delegate];
    [menu addItem:copy_item];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:status_bar_disabled_item(@"Workspaces:")];

    for (int i = 0; i < snapshot.space_count; ++i) {
        struct status_bar_space_info *info = &snapshot.spaces[i];

        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                      action:@selector(focusSpace:)
                                               keyEquivalent:@""];
        [item setTarget:g_status_delegate];
        [item setRepresentedObject:[NSNumber numberWithUnsignedLongLong:info->sid]];
        [item setAttributedTitle:status_bar_attributed_workspace(
            [NSString stringWithUTF8String:info->menu_primary],
            [NSString stringWithUTF8String:info->menu_secondary])];
        [item setState:info->is_active ? NSControlStateValueOn : NSControlStateValueOff];
        [menu addItem:item];
    }

    [menu addItem:[NSMenuItem separatorItem]];

    NSString *open_config_title = [NSString stringWithFormat:@"Open config in '%@'", status_bar_config_editor_name()];
    NSMenuItem *open_config_item = [[NSMenuItem alloc] initWithTitle:open_config_title
                                                              action:@selector(openConfig:)
                                                       keyEquivalent:@","];
    [open_config_item setTarget:g_status_delegate];
    [menu addItem:open_config_item];

    NSMenuItem *reload_item = [[NSMenuItem alloc] initWithTitle:@"Reload config"
                                                         action:@selector(reloadConfig:)
                                                  keyEquivalent:@"r"];
    [reload_item setTarget:g_status_delegate];
    [menu addItem:reload_item];

    NSMenuItem *quit_item = [[NSMenuItem alloc] initWithTitle:@"Quit yabai"
                                                       action:@selector(quit:)
                                                keyEquivalent:@"q"];
    [quit_item setTarget:g_status_delegate];
    [menu addItem:quit_item];

    [g_status_item setMenu:menu];
    status_bar_free_snapshot(&snapshot);
}

bool status_bar_begin(void)
{
    if (g_status_bar_enabled) return true;

    g_status_delegate = [[status_bar_delegate alloc] init];
    g_status_item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    if (!g_status_item) return false;

    g_pill_view = [[status_bar_pill_view alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 24.0f, 18.0f)];

    NSStatusBarButton *button = [g_status_item button];
    [button setTitle:@""];
    [button setImage:nil];
    [button addSubview:g_pill_view];

    g_status_bar_enabled = true;
    status_bar_refresh_main();
    return true;
}

void status_bar_refresh(void)
{
    if (!g_status_bar_enabled) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        status_bar_refresh_main();
    });
}
