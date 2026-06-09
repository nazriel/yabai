@interface status_bar_delegate : NSObject
@end

@implementation status_bar_delegate

- (void)focusSpace:(id)sender
{
    NSNumber *sid_number = [sender representedObject];
    if (!sid_number) return;

    status_bar_focus_space([sid_number unsignedLongLongValue]);
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
static status_bar_delegate *g_status_delegate;
static bool g_status_bar_enabled;

static void status_bar_refresh_main(void)
{
    if (!g_status_bar_enabled || !g_status_item) return;

    struct status_bar_snapshot snapshot = {0};
    if (!status_bar_collect_snapshot(&snapshot)) return;

    NSStatusBarButton *button = [g_status_item button];
    [button setTitle:[NSString stringWithUTF8String:snapshot.title]];

    NSMenu *menu = [[NSMenu alloc] init];

    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8String:snapshot.version]
                                                    action:NULL
                                             keyEquivalent:@""];
    [header setEnabled:NO];
    [menu addItem:header];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *workspaces_header = [[NSMenuItem alloc] initWithTitle:@"Workspaces:"
                                                               action:NULL
                                                        keyEquivalent:@""];
    [workspaces_header setEnabled:NO];
    [menu addItem:workspaces_header];

    for (int i = 0; i < snapshot.space_count; ++i) {
        struct status_bar_space_info *info = &snapshot.spaces[i];

        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8String:info->menu_title]
                                                      action:@selector(focusSpace:)
                                               keyEquivalent:@""];
        [item setTarget:g_status_delegate];
        [item setRepresentedObject:[NSNumber numberWithUnsignedLongLong:info->sid]];
        [item setState:info->is_active ? NSControlStateValueOn : NSControlStateValueOff];
        [menu addItem:item];
    }

    [menu addItem:[NSMenuItem separatorItem]];

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
