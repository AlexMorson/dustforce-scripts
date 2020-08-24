mixin class GuiVisibility {
    protected bool mouse_in_toolbar = false;
    protected bool mouse_in_menu = false;
    protected float gui_visibility = 1.0;

    private int gui_visibility_timer = 19;

    void update_gui_visibility() {
        if (mouse_in_toolbar or mouse_in_menu) {
            gui_visibility_timer = int(min(19, gui_visibility_timer + 1));
            if (gui_visibility_timer > 10) gui_visibility_timer = 19;
        } else {
            gui_visibility_timer = int(max(0, gui_visibility_timer - 1));
        }
        gui_visibility = min(10, gui_visibility_timer) / 10.0;
    }
}
