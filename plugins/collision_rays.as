#include "lib/std.cpp"

class script : callback_base {
    scene@ g;
    dustman@ dm;

    float x, y;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        @dm = controller_controllable(0).as_dustman();
        dm.on_subframe_end_callback(this, "subframe_end", 0);
    }

    void checkpoint_load() {
        @dm = controller_controllable(0).as_dustman();
        dm.on_subframe_end_callback(this, "subframe_end", 0);
    }

    void subframe_end(dustman@ dm, int) {
        x = dm.x() + dm.x_speed() / (60 * 5);
        y = dm.y() + dm.y_speed() / (60 * 5);
    }

    void draw_stuff() {
        // Wall collisions
        const float base_y = -48;
        const float change_y = 24;
        const float bottom = y < change_y ? -35 : -36;
        const int n_positive = y < change_y ? 9 : 8;

        // Collision area
        g.draw_quad_world(
            20, 0, false,
            x - 42 + 8 * 0.9, y + base_y - 12,
            x + 42 - 8 * 0.9, y + base_y - 12,
            x + 42, y + base_y,
            x - 42, y + base_y,
            0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF
        );
        g.draw_quad_world(
            20, 0, false,
            x - 42 + 8 * 0.9, y + bottom,
            x + 42 - 8 * 0.9, y + bottom,
            x + 42, y + bottom - 12,
            x - 42, y + bottom - 12,
            0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF
        );
        if (y < change_y)
            g.draw_quad_world(
                20, 0, false,
                x + 42, y + bottom - 12,
                x - 42, y + bottom - 12,
                x - 42, y + base_y,
                x + 42, y + base_y,
                0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF, 0x44FFFFFF
            );

        // Right
        for (int i=-8; i<=n_positive; ++i) {
            float offset_x = 22 - 0.9 * (abs(i) + (i > 0 and y < change_y ? -1 : 0));
            float offset_y = base_y + 1.5 * i + (i > 0 and y < change_y ? -0.5 : 0);
            raycast@ ray = g.ray_cast_tiles(x, y + offset_y, x + offset_x + 20, y + offset_y);
            if (ray.hit()) {
                if (ray.hit_x() < x + offset_x) { // Wall collision
                    g.draw_line_world(20, 0, x, y + offset_y, ray.hit_x(), y + offset_y, 1, 0xAA00FF00);
                } else { // Magnet effect
                    g.draw_line_world(20, 0, x, y + offset_y, x + offset_x, y + offset_y, 1, 0xAAFF0000);
                    g.draw_line_world(20, 0, x + offset_x, y + offset_y, ray.hit_x(), y + offset_y, 1, 0xAA000000);
                }
            } else {
                g.draw_line_world(20, 0, x, y + offset_y, x + offset_x + 20, y + offset_y, 1, 0xAAFF0000);
            }
        }

        // Left
        for (int i=-8; i<=n_positive; ++i) {
            float offset_x = 0.9 * (abs(i) + (i > 0 and y < change_y ? -1 : 0)) - 22;
            float offset_y = base_y + 1.5 * i + (i > 0 and y < change_y ? -0.5 : 0);
            raycast@ ray = g.ray_cast_tiles(x, y + offset_y, x + offset_x - 20, y + offset_y);
            if (ray.hit()) {
                if (x + offset_x < ray.hit_x()) { // Wall collision
                    g.draw_line_world(20, 0, ray.hit_x(), y + offset_y, x, y + offset_y, 1, 0xAA00FF00);
                } else {
                    g.draw_line_world(20, 0, x + offset_x, y + offset_y, x, y + offset_y, 1, 0xAAFF0000);
                    g.draw_line_world(20, 0, ray.hit_x(), y + offset_y, x + offset_x, y + offset_y, 1, 0xAA000000);
                }
            } else {
                g.draw_line_world(20, 0, x + offset_x - 20, y + offset_y, x, y + offset_y, 1, 0xAAFF0000);
            }
        }

        // Collision lines
        g.draw_line_world(20, 0, x - 22, y + base_y, x - 22 + 8 * 0.9, y + base_y - 12, 1, 0xAAFFFFFF);
        g.draw_line_world(20, 0, x - 22 + 8 * 0.9, y + bottom, x - 22, y + bottom - 12, 1, 0xAAFFFFFF);
        g.draw_line_world(20, 0, x + 22, y + base_y, x + 22 - 8 * 0.9, y + base_y - 12, 1, 0xAAFFFFFF);
        g.draw_line_world(20, 0, x + 22 - 8 * 0.9, y + bottom, x + 22, y + bottom - 12, 1, 0xAAFFFFFF);

        // Floor and Ceiling collisions
        const float w = 12;
        const float up_h = 48;
        const float down_h = 10;

        // Down
        g.draw_rectangle_world(20, 0, x - w, y - up_h, x+w, y+down_h, 0, 0x44FFFFFF);
        for (int i=-3; i<=3; ++i) {
            float offset = w * i / 3;
            raycast@ ray = g.ray_cast_tiles(x + offset, y - up_h, x + offset, y + down_h);
            if (ray.hit()) {
                g.draw_line_world(20, 0, x + offset, y - up_h, x + offset, ray.hit_y(), 1, 0xAA000000);
            } else {
                g.draw_line_world(20, 0, x + offset, y - up_h, x + offset, y + down_h, 1, 0xAAFF0000);
            }
        }

        // Draw the return value of collision_ground
        tilecollision@ down = g.collision_ground(x - w, y - up_h, x + w, y + down_h);
        if (down.hit()) {
            g.draw_rectangle_world(20, 0, x - 2, down.hit_y() - 2, x + 2, down.hit_y() + 2, 0, 0xBB000000);
            if (down.hit_y() > y) {
                g.draw_rectangle_world(20, 0, x - 1, down.hit_y() - 1, x + 1, down.hit_y() + 1, 0, 0xBBFF0000);
            } else {
                g.draw_rectangle_world(20, 0, x - 1, down.hit_y() - 1, x + 1, down.hit_y() + 1, 0, 0xBB00FF00);
            }
        }

        // The line that collision_ground needs to be above for a collision to occur
        g.draw_line_world(20, 0, x - w, y, x + w, y, 1, 0xAAFFFFFF);

        // Up
        g.draw_rectangle_world(20, 0, x - w, y - up_h, x + w, y - 2 * up_h - down_h, 0, 0x44FFFFFF);
        for (int i=-3; i<=3; ++i) {
            float offset = w * i / 3;
            raycast@ ray = g.ray_cast_tiles(x + offset, y - up_h, x + offset, y - 2 * up_h - down_h);
            if (ray.hit()) {
                g.draw_line_world(20, 0, x + offset, y - up_h, x + offset, ray.hit_y(), 1, 0xAA000000);
            } else {
                g.draw_line_world(20, 0, x + offset, y - up_h, x + offset, y - 2 * up_h - down_h, 1, 0xAAFF0000);
            }
        }

        // Draw the return value of collision_roof
        tilecollision@ up = g.collision_roof(x - w, y - up_h, x + w, y - 2 * up_h - down_h);
        if (up.hit()) {
            g.draw_rectangle_world(20, 0, x - 2, up.hit_y() - 2, x + 2, up.hit_y() + 2, 0, 0xBB000000);
            if (up.hit_y() < y - 2 * up_h) {
                g.draw_rectangle_world(20, 0, x - 1, up.hit_y() - 1, x + 1, up.hit_y() + 1, 0, 0xBBFF0000);
            } else {
                g.draw_rectangle_world(20, 0, x - 1, up.hit_y() - 1, x + 1, up.hit_y() + 1, 0, 0xBB00FF00);
            }
        }

        // The line that collision_roof needs to be below for a collision to occur
        g.draw_line_world(20, 0, x - w, y - 96, x + w, y - 96, 1, 0xAAFFFFFF);
    }

    void draw(float) {
        if (@dm !is null) {
            draw_stuff();
        }
    }

    void editor_draw(float) {
        x = g.mouse_x_world(0, 19);
        y = g.mouse_y_world(0, 19);
        draw_stuff();
    }
}

