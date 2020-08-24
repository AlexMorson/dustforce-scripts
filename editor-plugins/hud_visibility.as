mixin class HudVisibility {
    protected bool mouse_in_toolbar = false;
    protected bool mouse_in_menu = false;
    protected float hud_visibility = 1.0;

    private int hud_visibility_timer = 19;

    void update_hud_visibility() {
        if (mouse_in_toolbar or mouse_in_menu) {
            hud_visibility_timer = int(min(19, hud_visibility_timer + 1));
            if (hud_visibility_timer > 10) hud_visibility_timer = 19;
        } else {
            hud_visibility_timer = int(max(0, hud_visibility_timer - 1));
        }
        hud_visibility = min(10, hud_visibility_timer) / 10.0;
    }
}
