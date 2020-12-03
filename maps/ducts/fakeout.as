#include "lib/std.cpp"

class script : callback_base {
    [entity] int killed_enemy_id;
    [entity] int scientist_id;
    [entity] int cough_text_id;
    [entity] int angry_text_id;
    [entity] int sulky_text_id;

    scene@ g;
    controllable@ p;
    dustman@ d;
    camera@ c;
    fog_setting@ f;

    controllable@ killed_enemy;
    controllable@ scientist;
    array<entity@> particles;
    entity@ cough_text;
    entity@ angry_text;
    entity@ sulky_text;
    audio@ a1;
    audio@ a2;

    int ramp_down = 28;
    int slow = 120;
    int ramp_up = 30;
    int ground = 10;
    int victory = 50;
    float speed = 0.05;

    int state = 0;
    int timer = 0;
    int frame = 0;
    int last_damage = 0;

    script() {
        @g = get_scene();
        g.time_warp(1.0);
        g.disable_score_overlay(false);
    }

    void on_level_start() {
        @p = controller_controllable(0);
        @d = p.as_dustman();
        @c = get_camera(0);
        @f = c.get_fog();

        @killed_enemy = entity_by_id(killed_enemy_id).as_controllable();
        @scientist = entity_by_id(scientist_id).as_controllable();
        @cough_text = entity_by_id(cough_text_id);
        @angry_text = entity_by_id(angry_text_id);
        @sulky_text = entity_by_id(sulky_text_id);

        scientist.on_hurt_callback(this, "scientist_hit", 0);
        int particle_count = g.get_entity_collision(scientist.y()-10, scientist.y()+10, scientist.x()-10, scientist.x()+10, 13);
        for (int i=0; i<particle_count; ++i) {
            entity@ emitter = @g.get_entity_collision_index(i);
            particles.insertLast(@emitter);
        }
        move_particles(1000);
    }

    void move_particles(float dy) {
        for (int i=0; i<particles.length(); ++i) {
            entity@ emitter = particles[i];
            emitter.y(emitter.y() + dy);
        }
    }

    void scientist_hit(controllable@ attacked, controllable@ attacker, hitbox@ attack_hitbox, int arg) {
        if (state < 9) {
            sulky_text.y(sulky_text.y() - 400);
            angry_text.y(angry_text.y() + 200);
            cough_text.y(cough_text.y() + 200);

            move_particles(-1000);

            state = 9;
            timer = 80;
        }
    }

    void entity_on_add(entity@ x) {
        if (
            killed_enemy !is null and
            killed_enemy.life() <= 0 and
            state == 0 and
            x.type_name() == "filth_ball"
        ) {
            g.remove_entity(x);
        }

        if (x.type_name() == "hit_box_controller") {
            last_damage = x.as_hitbox().damage();
        }
    }

    void step(int) {
        // Do red alarm thing
        ++frame;
        int red = int( 255 * (0.5 + 0.5 * sin(0.05 * frame)) );
        f.colour(16, 19, 0xFF000000 + red << 16);
        c.change_fog(f, 0);

        // Handle fakeout ending state
        switch (state) {
            case 0: // Idle
                if (killed_enemy.life() <= 0) {
                    state = 1;
                    timer = ramp_down;
                    g.disable_score_overlay(true);
                    if (last_damage == 1) {
                        @a1 = g.play_sound("sfx_impact_light_1", 0, 0, 1, false, false);
                        @a2 = g.play_sound("sfx_slime_med", 0, 0, 1, false, false);
                    } else if (last_damage == 3) {
                        @a1 = g.play_sound("sfx_impact_heavy_1", 0, 0, 1, false, false);
                        @a2 = g.play_sound("sfx_slime_heavy", 0, 0, 1, false, false);
                    }
                    angry_text.y(angry_text.y() + 200);
                }
                break;
            case 1: // Ramp down speed
                g.time_warp( speed + (1 - speed) * (float(--timer) / ramp_down) );
                a1.time_scale( speed + (1 - speed) * (float(timer) / ramp_down) );
                a2.time_scale( speed + (1 - speed) * (float(timer) / ramp_down) );
                block_inputs();
                if (timer <= 0) {
                    state = 2;
                    timer = slow;
                }
                break;
            case 2: // Slow speed
                block_inputs();
                if (--timer <= 0) {
                    state = 3;
                    timer = ramp_up;
                    p.set_speed_xy(0, p.y_speed());
                }
                break;
            case 3: // Ramp up speed
                g.time_warp( 1 - (1 - speed) * float(--timer) / ramp_up );
                a1.time_scale( 1 - (1 - speed) * float(timer) / ramp_up );
                a2.time_scale( 1 - (1 - speed) * float(timer) / ramp_up );
                block_inputs();
                if (timer <= 0) {
                    state = 4;
                    timer = ground;
                }
                break;
            case 4: // Wait for ground
                d.combo_timer(1.0);
                block_inputs();
                if (p.ground() and --timer <= 0) {
                    state = 5;
                    timer = victory;
                    p.state(1);
                }
                break;
            case 5: // Wait for victory pose
                d.combo_timer(1.0);
                block_inputs();
                if (--timer <= 0) {
                    state = 6;
                    cough_text.y(cough_text.y() - 200);
                }
                break;
            case 6: // Wait for input
                d.combo_timer(1.0);
                if (
                    p.x_intent() != 0 or
                    p.jump_intent() != 0 or
                    p.dash_intent() != 0 or
                    p.light_intent() != 0 or
                    p.heavy_intent() != 0
                ) {
                    state = 7;
                    g.disable_score_overlay(false);
                }
                break;
            case 9: // Hit scientist (waiting so text is visible)
                block_inputs();
                if (--timer <= 0) {
                    g.end_level(0, 0);
                    state = 10;
                }
                break;
        }
    }

    void block_inputs() {
        p.x_intent(0);
        p.y_intent(0);
        p.jump_intent(0);
        p.dash_intent(0);
        p.fall_intent(0);
        p.light_intent(0);
        p.heavy_intent(0);
    }
}

class block_spread : trigger_base {
    scripttrigger@ self;
    scene@ g;

    int tx;
    int ty;
    int r;

    void init(script@ s, scripttrigger@ self) {
        @this.self = @self;
        self.square(true);
        self.editor_show_radius(true);

        @g = get_scene();

        tx = round(self.x() / 48.0);
        ty = round(self.y() / 48.0);
        r = round(self.radius() / 48.0);
    }

    void step() {
        for (int y=ty-r; y<ty+r; ++y) {
            for (int x=tx-r; x<tx+r; ++x) {
                tilefilth@ f = g.get_tile_filth(x, y);
                if (f.top()    > 0 and f.top()    < 9) f.top(0);
                if (f.bottom() > 0 and f.bottom() < 9) f.bottom(0);
                if (f.left()   > 0 and f.left()   < 9) f.left(0);
                if (f.right()  > 0 and f.right()  < 9) f.right(0);
                g.set_tile_filth(x, y, f);
            }
        }
    }

    void editor_step() {
        tx = round(self.x() / 48.0);
        ty = round(self.y() / 48.0);
        r = round(self.radius() / 48.0);
    }

    void editor_draw(float sub) {
        for (int y=ty-r; y<ty+r; ++y) {
            for (int x=tx-r; x<tx+r; ++x) {
                g.draw_rectangle_world(20, 0, 48*x, 48*y, 48*x+48, 48*y+48, 0, 0x33FF0000);
            }
        }
    }
}

class temp_deathdone : trigger_base {
    script@ s;
    scene@ g;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @g = get_scene();
    }

    void activate(controllable@ p) {
        if (p.player_index() != -1) {
            dustman@ d = p.as_dustman();
            if (not d.dead() and s.state == 0) {
                d.kill(false);
                g.combo_break_count(g.combo_break_count() + 1);
            }
        }
    }
}

class gradient : trigger_base {
    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;

    scripttrigger@ self;
    scene@ g;

    void init(script@ s, scripttrigger@ self) {
        @this.self = @self;
        self.square(true);
        @g = get_scene();
    }

    void draw(float subframe) {
        g.draw_gradient_world(20, 19, self.x(), self.y(), x, y, 0xFF000000, 0xFF000000, 0x00000000, 0x00000000);
    }
    void editor_draw(float subframe) {
        draw(subframe);
    }
}

class detector : trigger_base {
    script@ s;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
    }

    void activate(controllable@ p) {
        if (p.player_index() != -1 and s.state == 0) {
            s.state = 7;
        }
    }
}

class radiation : trigger_base {
    void activate(controllable@ p) {
        if (p.player_index() != -1) {
            p.x_intent(-p.x_intent());
        }
    }
}
