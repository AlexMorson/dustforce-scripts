abstract class EditorTool : callback_base {
    private bool first_frame = true;

    void register_tab() {}
    void on_select_tab() {}
    void on_deselect_tab() {}
    void on_mouse_enter_toolbar() {}
    void on_mouse_leave_toolbar() {}

    void editor_step() {
        if (first_frame) {
            register_tab();
            first_frame = false;
        }
    }

    protected void register_tab(int ix, string name, string icon = "") {
        message@ msg = create_message();
        msg.set_int("ix", ix);
        msg.set_string("name", name);
        msg.set_string("icon", icon);
        broadcast_message("Toolbar.RegisterTab", msg);

        add_broadcast_receiver("Toolbar.SelectTab.Prop Tool", this, "_on_select_tab");
        add_broadcast_receiver("Toolbar.DeselectTab.Prop Tool", this, "_on_deselect_tab");
        add_broadcast_receiver("Toolbar.MouseEnterToolbar", this, "_on_mouse_enter_toolbar");
        add_broadcast_receiver("Toolbar.MouseLeaveToolbar", this, "_on_mouse_leave_toolbar");
    }

    private void _on_select_tab(string, message@) { on_select_tab(); }
    private void _on_deselect_tab(string, message@) { on_deselect_tab(); }
    private void _on_mouse_enter_toolbar(string, message@) { on_mouse_enter_toolbar(); }
    private void _on_mouse_leave_toolbar(string, message@) { on_mouse_leave_toolbar(); }
}
