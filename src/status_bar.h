#ifndef STATUS_BAR_H
#define STATUS_BAR_H

#define STATUS_BAR_SPACE_LABEL_LEN   64
#define STATUS_BAR_SPACE_WINDOWS_LEN 256

struct status_bar_space_info {
    int index;
    uint64_t sid;
    bool is_active;
    char label[STATUS_BAR_SPACE_LABEL_LEN];
    char windows[STATUS_BAR_SPACE_WINDOWS_LEN];
    char menu_title[512];
};

struct status_bar_snapshot {
    char title[128];
    char version[64];
    struct status_bar_space_info *spaces;
    int space_count;
};

bool status_bar_begin(void);
void status_bar_refresh(void);
void status_bar_focus_space(uint64_t sid);
void status_bar_reload_config(void);
bool status_bar_collect_snapshot(struct status_bar_snapshot *snapshot);
void status_bar_free_snapshot(struct status_bar_snapshot *snapshot);

#endif
