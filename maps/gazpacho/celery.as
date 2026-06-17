#include "lib/std.cpp"

class script {
    [hidden] array<Tile> dustblocks;
    array<controllable@> trash_balls;

    scene@ g;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        swap();
        init();
    }

    void checkpoint_load() {
        swap();
    }

    void swap() {
        // Draw layers 17 in front of layer 18 and 19
        g.reset_layer_order();
        g.swap_layer_order(19, 18);
        g.swap_layer_order(18, 17);

        g.layer_scale(9, 0.9); // from 0.85
        g.layer_scale(8, 0.85); // from 0.8
        g.layer_scale(7, 0.85); // from 0.75
    }

    void init() {
        // Place "cover" dustblocks
        for (uint i=0; i<dustblocks.size(); ++i) {
            g.set_tile(dustblocks[i].x, dustblocks[i].y, 17, true, 0, 3, 6, 1);
        }
    }

    void step(int entity_num) {
        // Update dustblocks
        for (uint i=0; i<dustblocks.size(); ++i) {
            tileinfo@ tile = g.get_tile(dustblocks[i].x, dustblocks[i].y, 19);
            // If the layer 19 dustblock has just been collected
            if (not tile.solid() or tile.sprite_tile() == 0) {
                // Delete the corresponding dustblock on layer 12
                g.set_tile(dustblocks[i].x, dustblocks[i].y, 17, false, 0, 0, 0, 0);
            }
        }

        // Update entities
        trash_balls.resize(0);
        for (int i=0; i<entity_num; ++i) {
            controllable@ c = entity_by_index(i).as_controllable();
            if (c !is null and c.life() > 0 and c.type_name() == "enemy_trash_ball") {
                trash_balls.insertLast(c);
            }
        }
    }

    void update_dustblocks(float x, float y) {
        int tx = int(floor(x / 48.0));
        int ty = int(floor(y / 48.0));
        tileinfo@ tile = g.get_tile(tx, ty);
        bool dustblock = tile.is_dustblock() and tile.solid();

        for (int i=int(dustblocks.size())-1; i>=0; --i) {
            if (dustblocks[i].x == tx and dustblocks[i].y == ty) {
                // If already tracking, but isn't dustblock, remove
                if (not dustblock) dustblocks.removeAt(i);
                return;
            }
        }

        // If not already tracking, but is dustsblock, add
        if (dustblock) dustblocks.insertLast(Tile(tx, ty));
    }

    void draw(float subframe) {
        for (uint i=0; i<trash_balls.size(); ++i) {
            controllable@ c = trash_balls[i];
            sprites@ spr = c.get_sprites();
            spr.draw_world(18, 7, c.sprite_index(), int(c.state_timer()), 0, c.x(), c.y() - 2, 0, 1.3, 1.3, 0xFFFFFFFF);
        }
    }

    void editor_step() {
        float x = g.mouse_x_world(0, 19);
        float y = g.mouse_y_world(0, 19);
        update_dustblocks(x, y);
    }

    void editor_draw(float subframe) {
        draw(subframe);
        return;
        for (uint i=0; i<dustblocks.size(); ++i) {
            float x = 48.0 * dustblocks[i].x;
            float y = 48.0 * dustblocks[i].y;
            g.draw_rectangle_world(22, 0, x-12, y-12, x+12, y+12, 0, 0x880000FF);
        }
    }
}

class Tile {
    [text] int x;
    [text] int y;

    Tile() {}
    Tile(int x, int y) {
        this.x = x;
        this.y = y;
    }
}
