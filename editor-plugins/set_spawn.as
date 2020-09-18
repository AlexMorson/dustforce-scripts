#include "editor_tool.as"

#include "../lib/enums/GVB.cpp"
#include "../lib/enums/VK.cpp"

const string EMBED_setspawnicon = "editor-plugins/setspawnicon.png";

class script : EditorTool {
    controllable@ p;
    sprites@ spr;

    bool enabled = false;
    int mx, my;

    script() {
        @p = controller_controllable(0);
        @spr = create_sprites();
        spr.add_sprite_set("editor");
    }

    void build_sprites(message@ msg) {
        msg.set_string("Toolbar.setspawnicon", "setspawnicon");
    }

    void register_tab() override {
        register_tab(3, "Set Spawn", "Toolbar.setspawnicon");
    }

    void on_select_tab() override {
        enabled = true;
    }

    void on_deselect_tab() override {
        enabled = false;
    }

    void toggle() {
        message@ msg = create_message();
        msg.set_string("name", enabled ? "Entities" : "Set Spawn");
        broadcast_message("Toolbar.SelectTab", msg);
    }

    void editor_step() {
        EditorTool::editor_step();

        if (e.key_check_pressed_vk(VK::E)) {
            toggle();
        }

        if (not enabled or mouse_in_toolbar) return;

        mx = int(g.mouse_x_world(0, 19));
        my = int(g.mouse_y_world(0, 19));

        if (p !is null) {
            if (e.key_check_pressed_gvb(GVB::LeftClick) and not e.key_check_gvb(GVB::Space)) {
                p.x(mx);
                p.y(my);
                g.save_checkpoint(0, 0);
            }
        }
    }

    void editor_draw(float sub_frame) {
        if (not enabled or mouse_in_toolbar) return;

        int opacity = e.key_check_gvb(GVB::Space) ? 0x28 : 0x99;
        spr.draw_world(22, 0, "playerstart1", 0, 0, mx, my, 0, 1, 1, (opacity << 24) + 0xFFFFFF);
    }
}
