const string EMBED_target = "target.png";

class script {

    [position,mode:world,y:screen_top] float screen_left;
    [hidden] float screen_top;
    [position,mode:world,y:screen_bottom] float screen_right;
    [hidden] float screen_bottom;

    [text] int layer = 17;

    array<tracked_enemy@> tracked_enemies;

    scene@ g;
    sprites@ spr;

    script() {
        @g = get_scene();
        g.layer_visible(18, true);
    }

    void build_sprites(message@ msg) {
        msg.set_string("target", "target");
        msg.set_int("target|offsetx", 40);
        msg.set_int("target|offsety", 40);
    }

    void on_level_start() {
        g.layer_visible(18, false);
        g.layer_scale(14, 0.99);
        g.layer_scale(15, 0.99);
        g.layer_scale(16, 0.99);
        find_enemies();

        @spr = @create_sprites();
        spr.add_sprite_set("script");
    }

    void checkpoint_load() {
        find_enemies();

        @spr = @create_sprites();
        spr.add_sprite_set("script");
    }

    void step_post(int) {
        for (int i=0; i<tracked_enemies.length(); ++i) {
            tracked_enemies[i].step(g);
        }
    }

    void editor_draw(float subframe) {
        draw(subframe);
    }

    void draw(float subframe) {
        for (int i=0; i<tracked_enemies.length(); ++i) {
            tracked_enemies[i].draw(spr);
        }
    }

    void entity_on_add(entity@ e) {
        if (e.type_name() == "filth_ball") {
            g.remove_entity(e);
        }
    }

    void find_enemies() {
        tracked_enemies.resize(0);
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

                    tracked_enemies.insertLast(@tracked_enemy(c, layer));
                }
            }
        }
    }
}

class tracked_enemy {
    controllable@ c;
    bool dead = false;
    entity@ em1;
    entity@ em2;
    int layer;

    tracked_enemy(controllable@ c, int layer) {
        @this.c = c;
        this.layer = layer;
    }

    void step(scene@ g) {
        if (dead) {
            delete_emitter(g);
            @c = null;
        }

        if (not dead and entity_by_id(c.id()) is null) {
            dead = true;
            @em1 = create_emitter(81, c.x(), c.y(), 96, 96, layer, 0);
            @em2 = create_emitter(81, c.x(), c.y(), 96, 96, layer, 1);
            g.add_entity(em1);
            g.add_entity(em2);
        }
    }

    void delete_emitter(scene@ g) {
        if (em1 !is null) {
            g.remove_entity(em1);
            @em1 = null;
        }
        if (em2 !is null) {
            g.remove_entity(em2);
            @em2 = null;
        }
    }

    void draw(sprites@ spr) {
        if (not dead) {
            spr.draw_world(layer, 2, "target", c.state_timer() % 18, 1, c.x() + 3, c.y() + 3, 0, c.face(), 1, 0xFF555555);
            spr.draw_world(layer, 2, "target", c.state_timer() % 18, 1, c.x(), c.y(), 0, c.face(), 1, 0xFFFFFFFF);
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
