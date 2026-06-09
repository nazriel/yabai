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
        snprintf(buffer, length, "%d. %s", index, label->label);
    } else {
        snprintf(buffer, length, "%d", index);
    }
}

static int status_bar_compare_display_order(const void *lhs, const void *rhs)
{
    uint32_t lhs_did = *(const uint32_t *) lhs;
    uint32_t rhs_did = *(const uint32_t *) rhs;

    int lhs_order = display_manager_display_id_arrangement(lhs_did);
    int rhs_order = display_manager_display_id_arrangement(rhs_did);

    if (lhs_order && rhs_order && lhs_order != rhs_order) {
        return lhs_order < rhs_order ? -1 : 1;
    }

    if (lhs_order != rhs_order) return lhs_order ? -1 : 1;
    if (lhs_did == rhs_did) return 0;
    return lhs_did < rhs_did ? -1 : 1;
}

static bool status_bar_append_pill(struct status_bar_snapshot *snapshot, int *capacity, uint32_t did, uint64_t sid, uint64_t active_sid)
{
    if (snapshot->pill_count == *capacity) {
        int new_capacity = *capacity ? *capacity * 2 : 4;
        struct status_bar_pill_info *pills = realloc(snapshot->pills,
                                                     sizeof(struct status_bar_pill_info) * new_capacity);
        if (!pills) return false;

        snapshot->pills = pills;
        *capacity = new_capacity;
    }

    struct status_bar_pill_info *pill = &snapshot->pills[snapshot->pill_count++];
    memset(pill, 0, sizeof(*pill));

    pill->did = did;
    pill->sid = sid;
    pill->is_active = sid == active_sid;
    status_bar_format_title(pill->title, sizeof(pill->title), sid);
    return true;
}

static bool status_bar_collect_pills(struct status_bar_snapshot *snapshot, uint32_t *display_list, int display_count, uint64_t active_sid)
{
    if (!display_list || display_count <= 0) return true;

    uint32_t *ordered_displays = malloc(sizeof(uint32_t) * display_count);
    if (ordered_displays) {
        memcpy(ordered_displays, display_list, sizeof(uint32_t) * display_count);
        if (display_count > 1) {
            qsort(ordered_displays, display_count, sizeof(uint32_t), status_bar_compare_display_order);
        }
    } else {
        ordered_displays = display_list;
    }

    int pill_capacity = 0;

    for (int i = 0; i < display_count; ++i) {
        uint32_t did = ordered_displays[i];
        uint64_t sid = display_space_id(did);
        if (!sid) continue;

        if (!status_bar_append_pill(snapshot, &pill_capacity, did, sid, active_sid)) {
            if (ordered_displays != display_list) free(ordered_displays);
            return false;
        }
    }

    if (ordered_displays != display_list) free(ordered_displays);
    return true;
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

static void status_bar_format_menu_parts(struct status_bar_space_info *info)
{
    if (info->label[0] != '\0') {
        snprintf(info->menu_primary, sizeof(info->menu_primary), "%d. %s", info->index, info->label);
    } else {
        snprintf(info->menu_primary, sizeof(info->menu_primary), "%d", info->index);
    }

    snprintf(info->menu_secondary, sizeof(info->menu_secondary), "%s", info->windows);
}

static void status_bar_format_clipboard(struct status_bar_snapshot *snapshot)
{
    size_t offset = 0;

    int written = snprintf(snapshot->clipboard + offset,
                           sizeof(snapshot->clipboard) - offset,
                           "%s\n\nWorkspaces:\n",
                           snapshot->version);
    if (written < 0) return;
    offset += (size_t) written;

    for (int i = 0; i < snapshot->space_count; ++i) {
        struct status_bar_space_info *info = &snapshot->spaces[i];
        char line[512];

        if (info->menu_secondary[0] != '\0') {
            snprintf(line, sizeof(line), "%s%s - %s",
                     info->is_active ? "✓ " : "  ",
                     info->menu_primary,
                     info->menu_secondary);
        } else {
            snprintf(line, sizeof(line), "%s%s",
                     info->is_active ? "✓ " : "  ",
                     info->menu_primary);
        }

        written = snprintf(snapshot->clipboard + offset,
                           sizeof(snapshot->clipboard) - offset,
                           "%s\n",
                           line);
        if (written < 0 || (size_t) written >= sizeof(snapshot->clipboard) - offset) break;
        offset += (size_t) written;
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

    if (!status_bar_collect_pills(snapshot, display_list, display_count, active_sid)) {
        status_bar_free_snapshot(snapshot);
        return false;
    }

    int capacity = 0;

    for (int i = 0; i < display_count; ++i) {
        int space_count = 0;
        uint64_t *space_list = display_space_list(display_list[i], &space_count);
        if (!space_list) continue;

        for (int j = 0; j < space_count; ++j) {
            uint64_t sid = space_list[j];
            if (!space_is_user(sid)) continue;

            if (snapshot->space_count == capacity) {
                int new_capacity = capacity ? capacity * 2 : 8;
                struct status_bar_space_info *spaces = realloc(snapshot->spaces,
                                                               sizeof(struct status_bar_space_info) * new_capacity);
                if (!spaces) {
                    status_bar_free_snapshot(snapshot);
                    return false;
                }

                snapshot->spaces = spaces;
                capacity = new_capacity;
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
            status_bar_format_menu_parts(info);
        }
    }

    status_bar_format_clipboard(snapshot);
    return true;
}

void status_bar_free_snapshot(struct status_bar_snapshot *snapshot)
{
    if (!snapshot) return;

    free(snapshot->pills);
    snapshot->pills = NULL;
    snapshot->pill_count = 0;

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

void status_bar_open_config(void)
{
    char config_path[sizeof(g_config_file)];

    if (g_config_file[0] != '\0') {
        snprintf(config_path, sizeof(config_path), "%s", g_config_file);
    } else if (!get_config_file("yabairc", config_path, sizeof(config_path))) {
        return;
    }

    if (!file_exists(config_path)) return;

    char *args[] = { "/usr/bin/open", config_path, NULL };
    posix_spawn(NULL, args[0], NULL, NULL, args, NULL);
}
