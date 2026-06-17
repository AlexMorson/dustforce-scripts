#include "lib/drawing/common.cpp"
#include "clone2.as"

class script {
    [position,mode:world,y:screen_top] float screen_left;
    [hidden] float screen_top;
    [position,mode:world,y:screen_bottom] float screen_right;
    [hidden] float screen_bottom;

    [hidden] int tiles_left;
    [hidden] int tiles_top;
    [hidden] int tiles_right;
    [hidden] int tiles_bottom;

    [text] bool run_create_tiles = false;
    [text] bool run_remove_tiles = false;
    [hidden] bool last_create_tiles = false;
    [hidden] bool last_remove_tiles = false;

    scene@ g;
    camera@ c;

    clone@ d;
    array<tracked_enemy@> tracked_enemies;

    bool flipped = false;
    bool ground = true;

    script() {
        @g = get_scene();
        @c = get_camera(0);

        for (int layer=5; layer<=11; ++layer) {
            g.layer_scale(layer, 1.0);
        }

        if (g.get_layer_position(18) == 18) {
            g.swap_layer_order(5, 18);
        }
        g.default_collision_layer(6);
    }

    // Callbacks

    void on_level_start() {
        update_camera();
        find_enemies();
        @d = clone(g, controller_controllable(0), 14);
    }

    void on_level_end() {
        for (int i=0; i<tracked_enemies.length(); ++i) {
            tracked_enemies[i].delete_emitter(g);
        }
    }

    void checkpoint_load() {
        update_camera();
        @d = clone(g, controller_controllable(0), 14);
    }

    void step(int) {
        controllable@ p = controller_controllable(0);
        if (p is null) return;

        if (!p.ground()) {
            ground = false;
        } else if (!ground) {
            ground = true;

            // Make sure you can't fall out
            if (not g.get_tile(floor((p.x()-12) / 48.0), floor((p.y()+5) / 48.0), g.default_collision_layer()).solid()) {
                p.x(48.0 * floor((p.x()-12) / 48.0) + 48 + 12);
            }
            else if (not g.get_tile(floor((p.x()+12) / 48.0), floor((p.y()+5) / 48.0), g.default_collision_layer()).solid()) {
                p.x(48.0 * floor((p.x()+12) / 48.0) - 12);
            }

            flipped = not flipped;
            p.y(48*(tiles_top+tiles_bottom) - p.y());
            if (flipped) {
                g.default_collision_layer(7);
                d.set_offset(0, 48 * (tiles_top + tiles_bottom));
                d.set_scale(1, -1);
                d.layer = 15;
            } else {
                g.default_collision_layer(6);
                d.set_offset(0, 0);
                d.set_scale(1, 1);
                d.layer = 14;
            }

            for (int i=0; i<tracked_enemies.length(); ++i) {
                tracked_enemies[i].swap_team();
            }
        }
    }

    void step_post(int) {
        for (int i=0; i<tracked_enemies.length(); ++i) {
            tracked_enemies[i].step(g);
        }
        if (d !is null) d.step_post();
    }

    void editor_step() {
        if (run_create_tiles != last_create_tiles) {
            last_create_tiles = run_create_tiles;
            create_tiles();
        }

        if (run_remove_tiles != last_remove_tiles) {
            last_remove_tiles = run_remove_tiles;
            remove_tiles();
        }
    }

    void entity_on_add(entity@ e) {
        if (d !is null) d.entity_on_add(e);

        if (e.type_name() == "filth_ball") {
            g.remove_entity(e);
        }
    }

    void draw(float subframe) {
        if (d !is null) d.draw(subframe);

        for (int i=0; i<tracked_enemies.length(); ++i) {
            tracked_enemies[i].draw();
        }
    }

    void editor_draw(float subframe) {
        screen_left   = 48.0 * round(screen_left   / 48.0);
        screen_top    = 48.0 * round(screen_top    / 48.0);
        screen_right  = 48.0 * round(screen_right  / 48.0);
        screen_bottom = 48.0 * round(screen_bottom / 48.0);

        tiles_left   = round(screen_left   / 48.0);
        tiles_top    = round(screen_top    / 48.0);
        tiles_right  = round(screen_right  / 48.0);
        tiles_bottom = round(screen_bottom / 48.0);

        outline_rect(g, screen_left, screen_top, screen_right, screen_bottom, 22, 0, 2, 0x88FF0000);
    }

    // Non-callbacks

    void find_enemies() {
        array<entity@> enemies = array<entity@>(0);
        int enemy_count = g.get_entity_collision(screen_top, screen_bottom, screen_left, screen_right, 1);
        for (int i=0; i<enemy_count; ++i) {
            enemies.insertLast(g.get_entity_collision_index(i));
        }

        for (int i=0; i<enemy_count; ++i) {
            entity@ e = enemies[i];
            if (e !is null) {
                controllable@ c = e.as_controllable();
                if (c !is null and c.type_name().substr(0, 6) == "enemy_") {

                    bool flipped = g.get_tile(floor(c.x() / 48.0), floor(c.y() / 48.0), 6).solid();
                    float draw_x = c.x();
                    float draw_y = c.y();
                    if (flipped) {
                        c.y(48*(tiles_top+tiles_bottom) - c.y());
                        c.team(1);
                    }
                    tracked_enemies.insertLast(@tracked_enemy(c, draw_x, draw_y, flipped));
                }
            }
        }
    }

    void update_camera() {
        float w = screen_right - screen_left;
        float h = screen_bottom - screen_top;
        float screen_height = max(h, w / 1920.0 * 1080.0);

        c.script_camera(true);
        c.x(screen_left + w / 2.0);
        c.y(screen_top  + h / 2.0);
        c.prev_x(c.x());
        c.prev_y(c.y());
        c.scale_x(1080 / screen_height);
        c.scale_y(1080 / screen_height);
        c.prev_scale_x(c.scale_x());
        c.prev_scale_y(c.scale_y());
    }

    void create_tiles() {
        for (int x=tiles_left-1; x<tiles_right+1; ++x) {
            for (int y=tiles_top-1; y<tiles_bottom+1; ++y) {
                tileinfo@ tile = g.get_tile(x, y, 6);

                if (tile.solid()) {
                    // Black tiles
                    g.set_tile(x, y,  8, true, 0, 2, 10, 1);
                    g.set_tile(x, y,  9, true, 0, 2, 10, 1);
                    g.set_tile(x, y, 10, true, 0, 2, 10, 1);
                } else {
                    // White tiles
                    g.set_tile(x, y, 11, true, 0, 2, 10, 1);
                    g.set_tile(x, y, 12, true, 0, 2, 10, 1);
                    g.set_tile(x, y, 13, true, 0, 2, 10, 1);

                    // Second collision layer
                    g.set_tile(x, tiles_top+tiles_bottom-y-1, 7, true, 0, 2, 10, 1);
                }
            }
        }
    }

    void remove_tiles() {
        for (int x=tiles_left-1; x<tiles_right+1; ++x) {
            for (int y=tiles_top-1; y<tiles_bottom+1; ++y) {
                // Black tiles
                g.set_tile(x, y,  8, false, 0, 2, 10, 1);
                g.set_tile(x, y,  9, false, 0, 2, 10, 1);
                g.set_tile(x, y, 10, false, 0, 2, 10, 1);

                // White tiles
                g.set_tile(x, y, 11, false, 0, 2, 10, 1);
                g.set_tile(x, y, 12, false, 0, 2, 10, 1);
                g.set_tile(x, y, 13, false, 0, 2, 10, 1);

                // Second collision layer
                g.set_tile(x, tiles_top+tiles_bottom-y-1, 7, false, 0, 2, 10, 1);
            }
        }
    }
}

class tracked_enemy {
    controllable@ c;
    float entity_x;
    float entity_y;
    float draw_x;
    float draw_y;
    bool flipped;
    int layer;
    bool dead = false;
    entity@ em;

    tracked_enemy(controllable@ c, float draw_x, float draw_y, bool flipped) {
        @this.c = c;
        this.draw_x = draw_x;
        this.draw_y = draw_y;
        this.flipped = flipped;
        layer = flipped ? 17 : 16;
        entity_x = c.x();
        entity_y = c.y();
    }

    void swap_team() {
        c.team(1 - c.team());
    }

    void step(scene@ g) {
        if (entity_by_id(c.id()) !is null) {
            c.x(entity_x);
            c.y(entity_y);
        } else if (not dead) {
            dead = true;
            @em = create_emitter(81, draw_x, draw_y, 96, 96, layer, 0);
            g.add_entity(em);
        }
    }

    void delete_emitter(scene@ g) {
        if (em !is null) {
            g.remove_entity(em);
            @em = null;
        }
    }

    void draw() {
        if (not dead) {
            sprites@ spr = c.get_sprites();
            int state_timer = c.state_timer() % 18;
            if (flipped) state_timer = 17 - state_timer;
            spr.draw_world(layer, 0, c.sprite_index(), state_timer, 1, draw_x, draw_y, 0, c.face(), 1, 0xFFFFFFFF);
        }
    }
}

entity@ create_emitter(int id, float x, float y, int width, int height, int layer, int sub_layer) {
	entity@ emitter = create_entity("entity_emitter");
	varstruct@ vars = emitter.vars();
	emitter.layer(layer);
	vars.get_var("emitter_id").set_int32(id);
	vars.get_var("width").set_int32(width);
	vars.get_var("height").set_int32(height);
	vars.get_var("draw_depth_sub").set_int32(sub_layer);
	vars.get_var("r_area").set_bool(true);
	emitter.set_xy(x, y);
	
	return emitter;
}
