extern struct space_manager g_space_manager;
extern struct window_manager g_window_manager;
extern struct event_loop g_event_loop;
extern char g_config_file[4096];

#define STATUS_BAR_VERSION_MAJOR 7
#define STATUS_BAR_VERSION_MINOR 1
#define STATUS_BAR_VERSION_PATCH 25

static void status_bar_format_title(char *buffer, size_t length, uint64_t sid)
{
    int index = space_manager_mission_control_index(sid);
    struct space_label *label = space_manager_get_label_for_space(&g_space_manager, sid);

    if (label && label->label && label->label[0] != '\0') {
        snprintf(buffer, length, "%d.%s", index, label->label);
    } else {
        snprintf(buffer, length, "%d", index);
    }
}

static void status_bar_collect_window_apps(uint64_t sid, char *buffer, size_t length)
{
    int window_count = 0;
    uint32_t *window_list = space_window_list(sid, &window_count, false);

    buffer[0] = '\0';
    if (!window_list || window_count == 0) return;

    char *seen[32] = {0};
    int seen_count = 0;
    size_t offset = 0;
    bool first = true;

    for (int i = 0; i < window_count; ++i) {
        struct window *window = window_manager_find_window(&g_window_manager, window_list[i]);
        if (!window || !window->application || !window->application->name) continue;

        char *name = window->application->name;
        bool duplicate = false;

        for (int j = 0; j < seen_count; ++j) {
            if (string_equals(seen[j], name)) {
                duplicate = true;
                break;
            }
        }

        if (duplicate) continue;
        if (seen_count < 32) seen[seen_count++] = name;

        int written = snprintf(buffer + offset, length - offset, "%s%s", first ? "" : ", ", name);
        if (written < 0 || (size_t) written >= length - offset) break;

        offset += (size_t) written;
        first = false;
    }
}

static void status_bar_format_menu_title(struct status_bar_space_info *info, char *buffer, size_t length)
{
    if (info->label[0] != '\0' && info->windows[0] != '\0') {
        snprintf(buffer, length, "%d.%s - %s", info->index, info->label, info->windows);
    } else if (info->label[0] != '\0') {
        snprintf(buffer, length, "%d.%s", info->index, info->label);
    } else if (info->windows[0] != '\0') {
        snprintf(buffer, length, "%d - %s", info->index, info->windows);
    } else {
        snprintf(buffer, length, "%d", info->index);
    }
}

bool status_bar_collect_snapshot(struct status_bar_snapshot *snapshot)
{
    if (!snapshot) return false;

    memset(snapshot, 0, sizeof(*snapshot));

    snprintf(snapshot->version, sizeof(snapshot->version), "yabai v%d.%d.%d",
             STATUS_BAR_VERSION_MAJOR,
             STATUS_BAR_VERSION_MINOR,
             STATUS_BAR_VERSION_PATCH);

    uint64_t active_sid = g_space_manager.current_space_id;
    if (!active_sid) active_sid = space_manager_active_space();

    status_bar_format_title(snapshot->title, sizeof(snapshot->title), active_sid);

    int display_count = 0;
    uint32_t *display_list = display_manager_active_display_list(&display_count);
    if (!display_list) return true;

    int capacity = 0;

    for (int i = 0; i < display_count; ++i) {
        int space_count = 0;
        uint64_t *space_list = display_space_list(display_list[i], &space_count);
        if (!space_list) continue;

        for (int j = 0; j < space_count; ++j) {
            uint64_t sid = space_list[j];
            if (!space_is_user(sid)) continue;

            if (snapshot->space_count == capacity) {
                capacity = capacity ? capacity * 2 : 8;
                snapshot->spaces = realloc(snapshot->spaces, sizeof(struct status_bar_space_info) * capacity);
                if (!snapshot->spaces) {
                    snapshot->space_count = 0;
                    return false;
                }
            }

            struct status_bar_space_info *info = &snapshot->spaces[snapshot->space_count++];
            memset(info, 0, sizeof(*info));

            info->index = space_manager_mission_control_index(sid);
            info->sid = sid;
            info->is_active = sid == active_sid;

            struct space_label *label = space_manager_get_label_for_space(&g_space_manager, sid);
            if (label && label->label) {
                snprintf(info->label, sizeof(info->label), "%s", label->label);
            }

            status_bar_collect_window_apps(sid, info->windows, sizeof(info->windows));
            status_bar_format_menu_title(info, info->menu_title, sizeof(info->menu_title));
        }
    }

    return true;
}

void status_bar_free_snapshot(struct status_bar_snapshot *snapshot)
{
    if (!snapshot) return;

    free(snapshot->spaces);
    snapshot->spaces = NULL;
    snapshot->space_count = 0;
}

void status_bar_focus_space(uint64_t sid)
{
    event_loop_post(&g_event_loop, STATUS_BAR_FOCUS_SPACE, (void *)(uintptr_t) sid, 0);
}

void status_bar_reload_config(void)
{
    exec_config_file(g_config_file, sizeof(g_config_file));
}
