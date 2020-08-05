#include "clone2.as"
#include "lib/drawing/common.cpp"
#include "lib/easing/easing_in_out_quad.cpp"
#include "lib/math/math.cpp"

const string EMBED_platform_left = "platform_left.png";
const string EMBED_platform_right = "platform_right.png";
const string EMBED_platform_middle = "platform_middle.png";

class script {
    scene@ g;
    controllable@ p;
    sprites@ spr;

    [text] array<platform> ps;

    clone@ c;

    script() {
        @g = @get_scene();
        @spr = create_sprites();
    }

    void build_sprites(message@ msg) {
        msg.set_string("platform_left", "platform_left");
        msg.set_int("platform_left|offsetx", 2);
        msg.set_string("platform_right", "platform_right");
        msg.set_int("platform_right|offsetx", 2);
        msg.set_string("platform_middle", "platform_middle");
        msg.set_int("platform_middle|offsetx", 2);
    }

    void on_level_start() {
        spr.add_sprite_set("script");
        @p = @controller_controllable(0);
        @c = @clone(g, p, 17, 14, 15);
        step(0);
    }

    void checkpoint_load() {
        @p = @controller_controllable(0);
        @c.p = @p;
    }

    void step(int e) {
        for (int i=0; i<ps.length(); ++i) {
            ps[i].step(p, c, g);
        }
    }

    void step_post(int e) { 
        c.step_post();
    }

    void entity_on_add(entity@ e) {
        if (@c !is null) {
            c.entity_on_add(e);
        }
    }

    void draw(float subframe) {
        for (int i=0; i<ps.length(); ++i) {
            ps[i].draw(subframe, spr, c);
        }
        c.draw(subframe);
    }

    void editor_step() {
        for (int i=0; i<ps.length(); ++i) {
            ps[i].editor_step();
        }
    }

    void editor_draw(float subframe) {
        for (int i=0; i<ps.length(); ++i) {
            ps[i].editor_draw(g);
        }
    }
}

class platform {
    [position,mode:world,layer:19,y:y1] float x1;
    [hidden] float y1;
    [position,mode:world,layer:19,y:y2] float x2;
    [hidden] float y2;
    [text] float w = 240;
    [text] float h = 48;
    [text] float delay = 3;
    [text] bool smooth = true;

    float x;
    float y;
    float old_x;
    float old_y;
    float f = 0;

    bool player_on = false;
    array<tile> tiles;

    void step(controllable@ p, clone@ c, scene@ g) {
        f += 1.0 / 60.0 / delay;

        float t;
        if (smooth) {
            t = easing_in_out_quad(1.0-abs(f%2.0-1.0));
        } else {
            t = f % 2.0 / 2.0;
            t = t < 0.2 ? 0 : (t < 0.5 ? (t-0.2)/0.3 : 2-2*t);
        }

        old_x = x;
        old_y = y;

        x = lerp(x1, x2, t) - w / 2.0;
        y = lerp(y1, y2, t) - h / 2.0;

        if (player_on) {
            p.x(p.x() + x - old_x);
        }

        // Remove old tiles
        for (int i=0; i<tiles.length(); ++i) {
            tiles[i].update(g, false);
        }
        tiles.resize(0);

        bool in_bounds = p.x() >= x-14 && p.x() <= x+w+14;
        int tile_y = int(ceil(y / 48.0));

        // If the player is currently on this platform
        if (player_on) {
            // Check if the player has left the platform
            if (not in_bounds or not p.ground()) {
                player_on = false;
                // Move the player to the level of the platform
                p.y(y);
                // Reset the clone to the player's position
                c.offset_x = 0;
                c.offset_y = 0;
            }
        } else {
            // Check if the player is now on the platform
            if (in_bounds && p.prev_y() <= old_y && p.y() >= y) {
                player_on = true;
            }
        }

        if (player_on) {
            // Place new invisible tiles to stand on
            int l = int(floor(x/48.0));
            int r = int(ceil((x+w)/48.0));
            for (int i=l; i<r; ++i) {
                if (!g.get_tile(i, tile_y).solid()) {
                    tile t;
                    t.x = i;
                    t.y = tile_y;
                    t.update(g, true);
                    tiles.insertLast(t);
                }
            }

            // Move the player down onto the invisible tiles
            p.y(48.0 * tile_y);

            // Move the clone to the position of the platform
            c.offset_y = y - 48.0 * tile_y;
        }
    }

    void draw(float subframe, sprites@ spr, clone@ c) {
        // g.draw_rectangle_world(19, 10, x, y, x+w, y+h, 0, 0x44CB0079);
        // outline_rect(g, 19, 10, x, y, x+w, y+h, 1, 0xDDCB0079);

        float draw_x = subframe * (x - old_x) + old_x;
        float draw_y = subframe * (y - old_y) + old_y;

        int tile_count = round(w / 48.0);
        for (int tile_num = 0; tile_num < tile_count; ++tile_num) {
            string tile_name = "platform_middle";
            if (tile_num == 0) {
                tile_name = "platform_left";
            } else if (tile_num == tile_count - 1) {
                tile_name = "platform_right";
            }
            spr.draw_world(16, 7, tile_name, 1, 1, draw_x + 48 * tile_num, draw_y, 0, 1.1, 1.1, 0xFFAAAAAA);
            spr.draw_world(19, 8, tile_name, 1, 1, draw_x + 48 * tile_num, draw_y, 0, 1, 1, 0xFFFFFFFF);
        }

        if (player_on) {
            int tile_y = int(ceil(y / 48.0));
            c.offset_x = draw_x - old_x;
            c.offset_y = draw_y - 48.0 * tile_y;
        }
    }

    void editor_step() {
        x1 = round(x1 / 24.0) * 24.0;
        x2 = round(x2 / 24.0) * 24.0;
        y1 = round(y1 / 24.0) * 24.0;
        y2 = round(y2 / 24.0) * 24.0;
    }

    void editor_draw(scene@ g) {
        outline_rect(g, 20, 10, x1-w/2.0, y1-h/2.0, x1+w/2.0, y1+h/2.0, 2, 0xFF00FF00);
        outline_rect(g, 20, 10, x2-w/2.0, y2-h/2.0, x2+w/2.0, y2+h/2.0, 2, 0xFFFF0000);
        g.draw_line_world(20, 10, x1, y1, x2, y2, 3, 0xFF000000);
    }
}

class tile {
    int x, y;
    tileinfo@ t;

    tile() {
        @t = @create_tileinfo();
        // Make the tile invisible
        t.sprite_tile(0);
        // Make the tile square
        t.type(0);
        // Keep only the top edge
        t.edge_top(15);
        t.edge_bottom(0);
        t.edge_left(0);
        t.edge_right(0);
    }

    void update(scene@ g, bool solid) {
        t.solid(solid);
        g.set_tile(x, y, 19, t, false);
    }
}
