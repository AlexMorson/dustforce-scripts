#include "lib/enums/GVB.cpp"
#include "hud_visibility.as"
#include "hud_scale.as"

const int TOOLBAR_BG_COLOUR = 0x35302A;
const int TOOLBAR_ITEM_WIDTH = 60;

class script {
    Toolbar toolbar;

    void editor_step() {
        toolbar.editor_step();
    }

    void editor_draw(float sub_frame) {
        toolbar.editor_draw(sub_frame);
    }
}

class Toolbar : callback_base, HudVisibility, HudScale {
    scene@ g;
    editor_api@ e;

    sprites@ spr;

    array<ToolbarColumn@> columns;

    int selected_ix, selected_iy;
    string selected_tab_name;
    int mouse_ix, mouse_iy;

    Toolbar() {
        @g = get_scene();
        @e = get_editor_api();
        e.hide_gui(false);

        @spr = create_sprites();

        for (int ix=0; ix<10; ++ix) {
            columns.insertLast(ToolbarColumn(spr, ix));
        }

        add_tab(0, "Select", "editor", "selecticon");
        add_tab(1, "Tiles", "editor", "tilesicon");
        add_tab(2, "Props", "editor", "propsicon");
        add_tab(3, "Entities", "editor", "entityicon");
        add_tab(4, "Triggers", "editor", "triggersicon");
        add_tab(5, "Camera", "editor", "cameraicon");
        add_tab(6, "Emitters", "editor", "emittericon");
        add_tab(7, "Level Settings", "editor", "settingsicon");
        add_tab(8, "Scripts", "dustmod", "scripticon");
        add_tab(9, "Help", "editor", "helpicon");

        add_broadcast_receiver("Toolbar.RegisterTab", this, "register_tab");
        add_broadcast_receiver("Toolbar.SelectTab", this, "select_tab");
        add_broadcast_receiver("Toolbar.MouseEnterMenu", this, "mouse_enter_menu");
        add_broadcast_receiver("Toolbar.MouseLeaveMenu", this, "mouse_leave_menu");
    }

    void register_tab(string, message@ msg) {
        string error = "";

        string name;
        if (not msg.has_string("name") or msg.get_string("name") == "") {
            error += "\nNo tab name";
        } else {
            name = msg.get_string("name");
        }

        int ix;
        if (not msg.has_int("ix")) {
            error += "\nNo column index";
        } else {
            ix = msg.get_int("ix");
            if (ix < 0 or int(columns.size()) <= ix) {
                error += "\nInvalid column index";
            }
        }

        string icon = msg.has_string("icon") ? msg.get_string("icon") : "";

        if (error == "") {
            add_tab(ix, name, "script", icon);
        } else {
            puts("Failed to add editor toolbar tab:" + error);
        }
    }

    void select_tab(string, message@ msg) {
        string error = "";

        string name;
        if (not msg.has_string("name") or msg.get_string("name") == "") {
            error += "\nNo tab name";
        } else {
            name = msg.get_string("name");
        }

        int ix, iy;
        if (error == "") {
            get_tab_coords(name, ix, iy);
            if (ix == -1 or iy == -1) {
                error += "\nNo tab with name " + name;
            }
        }

        if (error == "") {
            select_tab(ix, iy, true);
        } else {
            puts("Failed to select editor toolbar tab:" + error);
        }
    }

    void mouse_enter_menu(string, message@) {
        mouse_in_menu = true;
    }

    void mouse_leave_menu(string, message@) {
        mouse_in_menu = false;
    }

    void add_tab(int ix, string name, string sprite_set, string sprite_name) {
        spr.add_sprite_set(sprite_set);
        columns[ix].add_tab(name, sprite_name);
    }

    void editor_step() {
        update_hud_scale();
        mouse_ix = int(floor(g.mouse_x_hud(0, false) / TOOLBAR_ITEM_WIDTH) + 5);
        mouse_iy = int(floor((g.mouse_y_hud(0, true) + HUD_HEIGHT_HALF) / hud_scale / TOOLBAR_ITEM_WIDTH));

        for (int ix=0; ix<int(columns.size()); ++ix) {
            columns[ix].step(mouse_ix, mouse_iy);
        }

        if (e.key_check_pressed_gvb(GVB::LeftClick)) {
            select_tab(mouse_ix, mouse_iy);
        }

        if (e.mouse_in_gui() or check_mouse_in_toolbar()) {
            if (not mouse_in_toolbar) {
                mouse_in_toolbar = true;
                broadcast_message("Toolbar.MouseEnterToolbar", create_message());
            }
        } else {
            if (mouse_in_toolbar) {
                mouse_in_toolbar = false;
                broadcast_message("Toolbar.MouseLeaveToolbar", create_message());
            }
        }

        update_hud_visibility();
    }

    bool check_mouse_in_toolbar() {
        return 0 <= mouse_ix and mouse_ix < int(columns.size()) and columns[mouse_ix].check_mouse_in_column(mouse_iy);
    }

    void select_tab(int ix, int iy, bool force=false) {
        if (selected_ix == ix and selected_iy == iy) return;

        const string new_selected_tab_name = get_tab_name(ix, iy);
        if (new_selected_tab_name != "" and (columns[ix].expanded or force)) {
            if (selected_tab_name != "") {
                columns[selected_ix].deselect_tab(selected_iy);
                broadcast_message("Toolbar.DeselectTab." + selected_tab_name, create_message());
            }

            mouse_in_menu = false;
            e.hide_gui(iy != 0);
            e.editor_tab(columns[ix].items[0].name);
            columns[ix].select_tab(iy);
            selected_ix = ix;
            selected_iy = iy;
            selected_tab_name = new_selected_tab_name;
            broadcast_message("Toolbar.SelectTab." + new_selected_tab_name, create_message());
        }
    }

    string get_tab_name(int ix, int iy) {
        if (ix < 0 or int(columns.size()) <= ix) return "";
        return columns[ix].get_tab_name(iy);
    }

    void get_tab_coords(string tab_name, int &out ix, int &out iy) {
        for (ix=0; ix<int(columns.size()); ++ix) {
            ToolbarColumn@ column  = @columns[ix];
            for (iy=0; iy<int(column.items.size()); ++iy) {
                if (column.items[iy].name == tab_name) {
                    return;
                }
            }
        }
        ix = -1;
        iy = -1;
    }

    void editor_draw(float sub_frame) {
        for (int ix=0; ix<int(columns.size()); ++ix) {
            columns[ix].draw(selected_iy != 0, hud_visibility, hud_scale);
        }
    }
}

class ToolbarColumn {
    sprites@ spr;

    int ix;
    bool expanded = false;
    bool selected = false;
    array<ToolbarItem@> items;

    ToolbarColumn(sprites@ spr, int ix) {
        @this.spr = spr;
        this.ix = ix;
    }

    void add_tab(string name, string sprite_name) {
        items.insertLast(ToolbarItem(spr, name, sprite_name));
    }

    bool check_mouse_in_column(int mouse_iy) {
        return (expanded and 0 <= mouse_iy and mouse_iy < int(items.size())) or mouse_iy == 0;
    }

    string get_tab_name(int iy) {
        if (iy < 0 or int(items.size()) <= iy) return "";
        return items[iy].name;
    }

    void select_tab(int iy) {
        items[iy].selected = true;
        selected = true;
    }

    void deselect_tab(int iy) {
        items[iy].selected = false;
        selected = false;
    }

    void step(int mouse_ix, int mouse_iy) {
       expanded = mouse_ix == ix and check_mouse_in_column(mouse_iy);
        for (uint iy=0; iy<items.size(); ++iy) {
            items[iy].draw_tooltip = mouse_ix == int(ix) and mouse_iy == int(iy) and (iy == 0 or expanded);
        }
    }

    void draw(bool draw_first, float visibility, float hud_scale) {
        int draw_iy = draw_first ? 0 : 1;
        for (int iy=draw_iy; iy<int(items.size()); ++iy) {
            if ((not selected and iy == 0) or expanded or items[iy].selected) {
                items[iy].draw(ix, draw_iy, visibility, hud_scale);
                ++draw_iy;
            }
        }
    }
}

class ToolbarItem {
    scene@ g;
    sprites@ spr;
    textfield@ tooltip;

    string name;
    string sprite_name;

    bool draw_tooltip = false;
    bool selected = false;

    ToolbarItem(sprites@ spr, string name, string sprite_name) {
        @g = get_scene();
        @this.spr = spr;
        this.name = name;
        this.sprite_name = sprite_name;

        @tooltip = @create_textfield();
        tooltip.set_font("envy_bold", 20);
        tooltip.text(name);
        tooltip.align_vertical(-1);
    }

    void draw(int ix, int iy, float visibility, float hud_scale) {
        const float w = TOOLBAR_ITEM_WIDTH * hud_scale;
        const float h = w;
        const float x = (ix-5) * w;
        const float y = iy * h - HUD_HEIGHT_HALF;

        if (selected) {
            float border = 0.1 * w;
            g.draw_rectangle_hud(
                6, 0,
                x + border, y + border,
                x + w - border, y + h - border,
                0, 0x88FFFFFF
            );
        }
        int toolbar_bg_opacity = int(floor(0xAA * visibility));
        g.draw_rectangle_hud(
            10, 0,
            x, y,
            x + w, y + h,
            0, (toolbar_bg_opacity << 24) + TOOLBAR_BG_COLOUR
        );
        g.draw_glass_hud(
            8, 0,
            x, y,
            x + w, y + h,
            0, 0
        );

        float padding = 5 * hud_scale;
        int icon_opacity = selected ? 0xFF : int(floor(0x99 * visibility)) + 0x22;
        spr.draw_hud(
            10, 0,
            sprite_name, 0, 1,
            x + padding, y + padding,
            0, hud_scale, hud_scale,
            (icon_opacity << 24) + 0xFFFFFF
        );

        if (draw_tooltip) {
            float border = 5 * hud_scale;
            float tw = tooltip.text_width() * hud_scale;
            float th = tooltip.text_height() * hud_scale;
            g.draw_glass_hud(
                10, 1,
                x + w / 2 - tw / 2 - border, y + h,
                x + w / 2 + tw / 2 + border, y + h + th + 3 * border,
                0, 0
            );
            g.draw_rectangle_hud(
                10, 1,
                x + w / 2 - tw / 2 - border, y + h,
                x + w / 2 + tw / 2 + border, y + h + th + 3 * border,
                0, 0xFF000000
            );
            tooltip.draw_hud(10, 1, x + w / 2, y + h + border, hud_scale, hud_scale, 0);
        }
    }
}
