#include "lib/drawing/common.cpp"

class script {}

class copier : trigger_base, callback_base {
    [position,mode:world,layer:19,y:src_y1] float src_x1;
    [position,mode:world,layer:19,y:src_y2] float src_x2;
    [hidden] float src_y1;
    [hidden] float src_y2;

    [position,mode:world,layer:19,y:dest_y] float dest_x;
    [hidden] float dest_y;

    [text] int src_layer = 19;
    [text] int dest_layer = 19;

    [text] bool swap = false;
    [text] bool single_use = true;
    [text] bool update_edges = true;
    [text] bool move_props = false;

    scene@ g;
    scripttrigger@ self;

    int sx1, sx2, sy1, sy2, dx, dy;
    int delta_x, delta_y, diff_x, diff_y;
    bool used = false;
    int cooldown = 0;

    void calc_values() {
        sx1 = int(round(src_x1 / 48));
        sx2 = int(round(src_x2 / 48));
        sy1 = int(round(src_y1 / 48));
        sy2 = int(round(src_y2 / 48));

        // Ensure sx/y1 is the smaller value
        if (sx1 > sx2) {
            int t = sx2;
            sx2 = sx1;
            sx1 = t;
        }

        if (sy1 > sy2) {
            int t = sy2;
            sy2 = sy1;
            sy1 = t;
        }

        dx = int(floor(dest_x / 48));
        dy = int(floor(dest_y / 48));

        delta_x = dx - sx1;
        delta_y = dy - sy1;
        diff_x = sx2 - sx1;
        diff_y = sy2 - sy1;
    }

    void init(script@ s, scripttrigger@ self) {
        @g = get_scene();
        @this.self = self;
        calc_values();
    }

    void step() {
        if (cooldown > 0) if (--cooldown == 0) used = false;
    }

    void editor_step() {
        calc_values();
    }

    void editor_draw(float sub_frame) {
        // Draw source
        g.draw_rectangle_world(22, 22, 48*sx1, 48*sy1, 48*sx2, 48*sy2, 0, 0x22FF0000);
        outline_rect(g, 22, 22, 48*sx1, 48*sy1, 48*sx2, 48*sy2, 1, 0x88FF0000);
        g.draw_line_world(22, 22, 48*sx1, 48*sy1, self.x(), self.y(), 2, 0x88FF0000);

        // Draw destination
        g.draw_rectangle_world(22, 22, 48*dx, 48*dy, 48*(dx+diff_x), 48*(dy+diff_y), 0, 0x2200FF00);
        outline_rect(g, 22, 22, 48*dx, 48*dy, 48*(dx+diff_x), 48*(dy+diff_y), 1, 0x8800FF00);
        g.draw_line_world(22, 22, 48*dx, 48*dy, self.x(), self.y(), 2, 0x8800FF00);
    }

    void copy() {
        used = true;

        // Move tiles
        for (int y=sy1; y<sy2; ++y) {
            for (int x=sx1; x<sx2; ++x) {
                tileinfo@  src_tile = g.get_tile(x, y, src_layer);
                tileinfo@ dest_tile = g.get_tile(x + delta_x, y + delta_y, dest_layer);

                tilefilth@  src_filth = g.get_tile_filth(x, y);
                tilefilth@ dest_filth = g.get_tile_filth(x + delta_x, y + delta_y);

                if (swap) {
                    // Copy dest to source
                    g.set_tile(x, y, src_layer, dest_tile, update_edges);
                    if (src_layer == 19 && dest_layer == 19) {
                        g.set_tile_filth(x, y, dest_filth);
                    }
                }
                // Copy source to dest
                g.set_tile(x + delta_x, y + delta_y, dest_layer, src_tile, update_edges);
                if (src_layer == 19 && dest_layer == 19) {
                    g.set_tile_filth(x + delta_x, y + delta_y, src_filth);
                }
            }
        }

        if (move_props) {
            // Compute arrays of props at source and destination
            uint src_prop_count = g.get_prop_collision(48*sy1, 48*sy2, 48*sx1, 48*sx2);
            array<prop@> src_props;
            for (uint i=0; i<src_prop_count; ++i) {
                prop@ p = @g.get_prop_collision_index(i);
                if (p.layer() > 11) {
                    src_props.insertLast(@p);
                }
            }

            uint dest_prop_count = g.get_prop_collision(48*dy, 48*(dy+diff_y), 48*dx, 48*(dx+diff_x));
            array<prop@> dest_props;
            for (uint i=0; i<dest_prop_count; ++i) {
                prop@ p = @g.get_prop_collision_index(i);
                if (p.layer() > 11) {
                    dest_props.insertLast(@p);
                }
            }

            if (swap) {
                // Move dest to src
                for (uint i=0; i<dest_props.length(); ++i ) {
                    dest_props[i].x(dest_props[i].x() - 48*delta_x);
                    dest_props[i].y(dest_props[i].y() - 48*delta_y);
                }
            } else {
                // Duplicate props in place
                // TODO
            }
            // Move src to dest
            for (uint i=0; i<src_props.length(); ++i ) {
                src_props[i].x(src_props[i].x() + 48*delta_x);
                src_props[i].y(src_props[i].y() + 48*delta_y);
            }
        }
    }

    void activate(controllable@ c) {
        if (c.player_index() != -1) {
            if (cooldown == 0 and not used) {
                copy();
            }
            if (not single_use) cooldown = 4;
        }
    }
}
