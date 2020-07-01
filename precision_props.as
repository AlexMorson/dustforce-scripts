#include "lib/std.cpp"
#include "lib/props.cpp"

class script {
    [text] bool on = false;
    [text] bool draw_layer = true;
    [text] bool invert_scroll = true;
    [text] bool delete_mode = false;
    [text] int layer_filter = -1;

    scene@ g;

    textfield@ prop_layer_text;

    array<Prop@> close_props;
    Prop@ closest_prop;
    Prop@ selected_prop;

    float mouse_x, mouse_y, last_mouse_x, last_mouse_y;
    float smouse_x, smouse_y, last_smouse_x, last_smouse_y; // Scales with parallax layers
    bool right_held, middle_held, last_right_held;
    bool wheel_up, wheel_down;

    script() {
        @g = get_scene();
        @prop_layer_text = @create_textfield();
        prop_layer_text.align_horizontal(-1);
        prop_layer_text.align_vertical(1);
    }

    void update_mouse_vars() {
        mouse_x = g.mouse_x_world(0, 19);
        mouse_y = g.mouse_y_world(0, 19);

        last_smouse_x = smouse_x;
        last_smouse_y = smouse_y;
        if (@selected_prop !is null) {
            int layer = selected_prop.p.layer();
            smouse_x = g.mouse_x_world(0, layer);
            smouse_y = g.mouse_y_world(0, layer);
        } else if (@closest_prop !is null) {
            int layer = closest_prop.p.layer();
            smouse_x = g.mouse_x_world(0, layer);
            smouse_y = g.mouse_y_world(0, layer);
        }

        last_right_held = right_held;
        int mouse_state = g.mouse_state(0);
        if (invert_scroll) {
            wheel_up = (mouse_state & 0x1) > 0;
            wheel_down = (mouse_state & 0x2) > 0;
        } else {
            wheel_down = (mouse_state & 0x1) > 0;
            wheel_up = (mouse_state & 0x2) > 0;
        }
        right_held = (mouse_state & 0x8) > 0;
        middle_held = (mouse_state & 0x10) > 0;
    }

    void find_closest_prop() {
        close_props.resize(0);
        float closest_dist = 1e8;
        @closest_prop = null;
        int n = g.get_prop_collision(
            mouse_y - 100,
            mouse_y + 100,
            mouse_x - 100,
            mouse_x + 100
        );
        for (int i=0; i<n; ++i) {
            Prop@ p = Prop(@g.get_prop_collision_index(i));
            if (layer_filter == -1 or p.p.layer() == layer_filter) {
                close_props.insertLast(@p);
                float dx = mouse_x - p.anchor_x;
                float dy = mouse_y - p.anchor_y;
                float dist = sqrt(dx*dx + dy*dy);
                if (dist < closest_dist) {
                    closest_dist = dist;
                    @closest_prop = @p;
                }
            }
        }
    }

    void update_selected_prop() {
        if (@selected_prop !is null) {
            if (right_held) {
                float dx = smouse_x - last_smouse_x;
                float dy = smouse_y - last_smouse_y;
                selected_prop.p.x(selected_prop.p.x() + dx);
                selected_prop.p.y(selected_prop.p.y() + dy);
                selected_prop.anchor_x += dx;
                selected_prop.anchor_y += dy;
            } else if (middle_held) {
                float x1 = last_smouse_x - selected_prop.anchor_x;
                float y1 = last_smouse_y - selected_prop.anchor_y;
                float x2 = smouse_x - selected_prop.anchor_x;
                float y2 = smouse_y - selected_prop.anchor_y;
                float angle = RAD2DEG * atan2(x1*y2-y1*x2, x1*x2+y1*y2);
                selected_prop.rotation(selected_prop.p.rotation() + angle);
            }
        }
    }

    void remove_closest_prop() {
        if (@closest_prop !is null) {
            g.remove_prop(closest_prop.p);
            @closest_prop = null;
        }
    }

    void editor_step() {
        if (not on) return;

        update_mouse_vars();

        if (delete_mode) {
            if (right_held and not last_right_held) {
                remove_closest_prop();
            } else {
                find_closest_prop();
            }
        } else {
            if (wheel_up || wheel_down) {
                handle_scrolling();
            }

            if (right_held || middle_held) {
                if (@selected_prop !is null) {
                    update_selected_prop();
                } else {
                    @selected_prop = @closest_prop;
                }
            } else {
                @selected_prop = null;
                find_closest_prop();
            }
        }

        update_textfield();
    }

    void update_textfield() {
        Prop@ current_prop = @selected_prop;
        if (@current_prop is null) @current_prop = @closest_prop;
        if (@current_prop is null) {
            prop_layer_text.text("");
        } else {
            prop@ p = @current_prop.p;
            int current_sublayer = p.sub_layer();
            int current_layer = p.layer();

            prop_layer_text.text("(" + formatInt(current_layer) + "," + formatInt(current_sublayer) + ")");
        }
    }

    void handle_scrolling() {
        if (middle_held) return;

        Prop@ current_prop = @selected_prop;
        if (@current_prop is null) @current_prop = @closest_prop;
        if (@current_prop is null) return;

        prop@ p = @current_prop.p;
        int current_sublayer = p.sub_layer();
        int current_layer = p.layer();

        if (wheel_down) {
            if (current_sublayer == 0) {
                if (current_layer > 0) {
                    p.layer(current_layer - 1);
                    p.sub_layer(24);
                }
            } else {
                p.sub_layer(current_sublayer - 1);
            }
        }

        if (wheel_up) {
            if (current_sublayer == 24) {
                if (current_layer < 22) {
                    p.layer(current_layer + 1);
                    p.sub_layer(0);
                }
            } else {
                p.sub_layer(current_sublayer + 1);
            }
        }
    }

    void editor_draw(float) {
        if (not on) return;

        // Draw the boxes on layer 22 so that can always be seen;
        // requires some finagling to undo the parallax scaling

        camera@ c = @get_camera(0);
        float cam_x = c.x();
        float cam_y = c.y();

        for (int i=0; i<close_props.size(); ++i) {
            if (@close_props[i] !is null and @close_props[i] !is @closest_prop) {
                Prop@ p = close_props[i];
                float scale = g.layer_scale(p.p.layer());
                float ox = (1 - scale) * cam_x;
                float oy = (1 - scale) * cam_y;
                g.draw_rectangle_world(22, 0, ox + scale*p.anchor_x-10, oy+scale*p.anchor_y-10, ox+scale*p.anchor_x+10, oy+scale*p.anchor_y+10, 0, 0x55FF0000);
            }
        }

        if (@closest_prop !is null) {
            float scale = g.layer_scale(closest_prop.p.layer());
            float ox = (1 - scale) * cam_x;
            float oy = (1 - scale) * cam_y;
            g.draw_rectangle_world(22, 0, ox + scale*closest_prop.anchor_x-10, oy + scale*closest_prop.anchor_y-10, ox + scale*closest_prop.anchor_x+10, oy + scale*closest_prop.anchor_y+10, 0, 0x5500FF00);
        }

        if (draw_layer) {
            prop_layer_text.draw_world(22, 24, mouse_x, mouse_y, 1, 1, 0);
        }
    }
}
