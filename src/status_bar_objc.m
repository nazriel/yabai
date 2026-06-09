extern char g_config_file[4096];

@interface status_bar_pill_view : NSView
@property (copy, nonatomic) NSArray *titles;
@property (assign, nonatomic) NSInteger active_index;
@end

@implementation status_bar_pill_view

static CGFloat status_bar_pill_height(void)
{
    CGFloat height = [[NSStatusBar systemStatusBar] thickness];
    return height > 0.0f ? height : 22.0f;
}

static CGFloat status_bar_pill_horizontal_padding(void)
{
    return ceil(status_bar_pill_height() / 2.0f);
}

static CGFloat status_bar_pill_gap(void)
{
    return 4.0f;
}

static NSFont *status_bar_pill_font(void)
{
    return [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium];
}

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

static NSString *status_bar_pill_title_at_index(NSArray *titles, NSUInteger index)
{
    id title = [titles objectAtIndex:index];
    return [title isKindOfClass:[NSString class]] ? title : @"";
}

static CGFloat status_bar_pill_width_for_title(NSString *title)
{
    CGFloat horizontal_padding = status_bar_pill_horizontal_padding();
    if (!title.length) return horizontal_padding * 2.0f;

    NSDictionary *attributes = @{
        NSFontAttributeName: status_bar_pill_font()
    };

    NSSize text_size = [title sizeWithAttributes:attributes];
    return ceil(text_size.width + horizontal_padding * 2.0f);
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void) dirtyRect;

    NSArray *titles = self.titles;
    NSUInteger title_count = [titles count];
    if (!title_count) titles = @[@""];

    NSRect bounds = self.bounds;
    CGFloat radius = 5.0f;
    CGFloat x = 0.0f;

    bool is_dark = status_bar_is_dark_appearance([self effectiveAppearance]);
    NSColor *highlight_color = is_dark ? [NSColor whiteColor] : [NSColor blackColor];
    NSColor *highlight_text_color = is_dark ? [NSColor blackColor] : [NSColor whiteColor];
    NSColor *inactive_text_color = highlight_color;

    title_count = [titles count];
    for (NSUInteger i = 0; i < title_count; ++i) {
        NSString *title = status_bar_pill_title_at_index(titles, i);
        CGFloat width = status_bar_pill_width_for_title(title);
        NSRect pill_rect = NSMakeRect(x, 0.0f, width, bounds.size.height);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(pill_rect, 0.5f, 0.5f)
                                                             xRadius:radius
                                                             yRadius:radius];
        bool is_active = (NSInteger) i == self.active_index;
        NSColor *text_color = is_active ? highlight_text_color : inactive_text_color;

        if (is_active) {
            [highlight_color setFill];
            [path fill];
        } else {
            [highlight_color setStroke];
            [path setLineWidth:1.0f];
            [path stroke];
        }

        if (title.length) {
            NSDictionary *attributes = @{
                NSFontAttributeName: status_bar_pill_font(),
                NSForegroundColorAttributeName: text_color
            };
            NSSize text_size = [title sizeWithAttributes:attributes];
            NSPoint origin = NSMakePoint(pill_rect.origin.x + (pill_rect.size.width - text_size.width) / 2.0f,
                                         pill_rect.origin.y + (pill_rect.size.height - text_size.height) / 2.0f);
            [title drawAtPoint:origin withAttributes:attributes];
        }

        x += width + status_bar_pill_gap();
    }
}

- (NSSize)intrinsicContentSize
{
    NSArray *titles = self.titles;
    NSUInteger title_count = [titles count];
    CGFloat height = status_bar_pill_height();
    CGFloat width = 0.0f;

    if (!title_count) {
        return NSMakeSize(status_bar_pill_width_for_title(@""), height);
    }

    NSDictionary *attributes = @{
        NSFontAttributeName: status_bar_pill_font()
    };

    for (NSUInteger i = 0; i < title_count; ++i) {
        NSString *title = status_bar_pill_title_at_index(titles, i);
        width += status_bar_pill_width_for_title(title);

        if (title.length) {
            NSSize text_size = [title sizeWithAttributes:attributes];
            height = MAX(height, text_size.height + 4.0f);
        }

        if (i < title_count - 1) width += status_bar_pill_gap();
    }

    return NSMakeSize(ceil(width), height);
}

- (void)setTitles:(NSArray *)titles
{
    if (_titles != titles) {
        [_titles release];
        _titles = [titles copy];
    }

    [self invalidateIntrinsicContentSize];
    [self setNeedsDisplay:YES];
}

- (void)setActive_index:(NSInteger)active_index
{
    _active_index = active_index;
    [self setNeedsDisplay:YES];
}

- (void)viewDidChangeEffectiveAppearance
{
    [super viewDidChangeEffectiveAppearance];
    [self setNeedsDisplay:YES];
}

- (void)dealloc
{
    [_titles release];
    [super dealloc];
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

static NSString *status_bar_string_from_c(const char *string)
{
    if (!string) return @"";

    NSString *result = [NSString stringWithUTF8String:string];
    return result ? result : @"";
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

    NSMutableArray *pill_titles = [NSMutableArray arrayWithCapacity:snapshot.pill_count > 0 ? snapshot.pill_count : 1];
    NSInteger active_index = -1;
    if (snapshot.pill_count > 0) {
        for (int i = 0; i < snapshot.pill_count; ++i) {
            [pill_titles addObject:status_bar_string_from_c(snapshot.pills[i].title)];
            if (snapshot.pills[i].is_active) active_index = i;
        }
    } else {
        [pill_titles addObject:status_bar_string_from_c(snapshot.title)];
        active_index = 0;
    }

    if (active_index < 0 && [pill_titles count] == 1) active_index = 0;

    [g_pill_view setTitles:pill_titles];
    [g_pill_view setActive_index:active_index];

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

    g_pill_view = [[status_bar_pill_view alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 24.0f, status_bar_pill_height())];

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
