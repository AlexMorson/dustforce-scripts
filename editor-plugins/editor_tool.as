#include "hud_visibility.as"
#include "hud_scale.as"

const uint MENU_OPACITY = 0xAA;
const uint MENU_COLOUR = 0x28251F;

abstract class EditorTool : callback_base, HudVisibility, HudScale {
    scene@ g;
    editor_api@ e;

    private bool first_frame = true;

    EditorTool() {
        @g = get_scene();
        @e = get_editor_api();
    }

    void register_tab() {}
    void on_select_tab() {}
    void on_deselect_tab() {}
    void on_mouse_enter_toolbar() {}
    void on_mouse_leave_toolbar() {}

    void draw_menu_background(float x1, float y1, float x2, float y2) {
        const uint opacity = uint(MENU_OPACITY * hud_visibility) << 24;
        g.draw_rectangle_hud(10, 0, x1, y1, x2, y2, 0, opacity + MENU_COLOUR);
        g.draw_glass_hud(8, 0, x1, y1, x2, y2, 0, 0);
    }

    void editor_step() {
        if (first_frame) {
            register_tab();
            first_frame = false;
        }

        update_hud_visibility();
        update_hud_scale();
    }

    protected void register_tab(int ix, string name, string icon = "") {
        message@ msg = create_message();
        msg.set_int("ix", ix);
        msg.set_string("name", name);
        msg.set_string("icon", icon);
        broadcast_message("Toolbar.RegisterTab", msg);

        add_broadcast_receiver("Toolbar.SelectTab." + name, this, "_on_select_tab");
        add_broadcast_receiver("Toolbar.DeselectTab." + name, this, "_on_deselect_tab");
        add_broadcast_receiver("Toolbar.MouseEnterToolbar", this, "_on_mouse_enter_toolbar");
        add_broadcast_receiver("Toolbar.MouseLeaveToolbar", this, "_on_mouse_leave_toolbar");
    }

    private void _on_select_tab(string, message@) { on_select_tab(); }
    private void _on_deselect_tab(string, message@) { on_deselect_tab(); }
    private void _on_mouse_enter_toolbar(string, message@) {
        mouse_in_toolbar = true;
        on_mouse_enter_toolbar();
    }
    private void _on_mouse_leave_toolbar(string, message@) {
        mouse_in_toolbar = false;
        on_mouse_leave_toolbar();
    }
}
