#include "lib/math/math.cpp"
#include "lib/emitters.cpp"

#include "hash_map.as"
#include "fog.as"

const string EMBED_particle0 = "bones/particle0.png";
const string EMBED_particle1 = "bones/particle1.png";
const string EMBED_particle2 = "bones/particle2.png";
const string EMBED_particle3 = "bones/particle3.png";
const string EMBED_particle4 = "bones/particle4.png";

const string EMBED_filth0 = "bones/filth0.png";
const string EMBED_filth1 = "bones/filth1.png";
const string EMBED_filth2 = "bones/filth2.png";
const string EMBED_filth3 = "bones/filth3.png";
const string EMBED_filth4 = "bones/filth4.png";
const string EMBED_filth5 = "bones/filth5.png";
const string EMBED_filth6 = "bones/filth6.png";

const string EMBED_full1 = "bones/full1.png";
const string EMBED_full2 = "bones/full2.png";
const string EMBED_full3 = "bones/full3.png";
const string EMBED_full4 = "bones/full4.png";
const string EMBED_full5 = "bones/full5.png";

const string EMBED_remains = "bones/remains.png";

const string EMBED_rattle0 = "bones/rattle0.ogg";
const string EMBED_rattle1 = "bones/rattle1.ogg";
const string EMBED_rattle2 = "bones/rattle2.ogg";
const string EMBED_rattle3 = "bones/rattle3.ogg";
const string EMBED_rattle4 = "bones/rattle4.ogg";
const string EMBED_rattle5 = "bones/rattle5.ogg";
const string EMBED_rattle6 = "bones/rattle6.ogg";

const string EMBED_rumble0 = "bones/rumble0.ogg";
const string EMBED_rumble1 = "bones/rumble1.ogg";
const string EMBED_rumble2 = "bones/rumble2.ogg";
const string EMBED_rumble3 = "bones/rumble3.ogg";

const string EMBED_thunder = "bones/thunder.ogg";
const string EMBED_rain = "bones/rain.ogg";
const string EMBED_zap = "bones/zap.ogg";

const array<array<int>> PARTICLE_OFFSETS = {{20, 13}, {24, 12}, {21, 14}, {23, 12}, {18, 9}};
const array<array<int>> FILTH_OFFSETS = {{48, 24}, {0, 24}, {0, 24}, {0, 24}, {0, 24}, {0, 24}, {0, 24}};

const int RATTLE_COUNT = 7;
const int RUMBLE_COUNT = 4;

const float SLOPE_ANGLE = 45;
const float SLANT_ANGLE = 30;

class script {
    [text] bool reset = false;
    [text] bool scan = false;

    [entity] int switch_id;

    [entity] int day_id;
    [entity] int bright_id;
    [entity] int night_id;
    [entity] int text_id;
    [entity] int dracula_id;
    [entity] int ambience_id;
    [entity] int music_id;
    [entity] int no_music_id;

    [position,mode:world,layer:19,y:orb_y] float orb_x;
    [hidden] float orb_y;
    [position,mode:world,layer:19,y:zap_y1] float zap_x1;
    [hidden] float zap_y1;
    [position,mode:world,layer:19,y:zap_y2] float zap_x2;
    [hidden] float zap_y2;
    [position,mode:world,layer:19,y:remains_y] float remains_x;
    [hidden] float remains_y;

    fog_setting@ day_fog, bright_fog, night_fog;
    entity@ text_trigger, dracula_trigger, ambience_trigger, music_trigger, no_music_trigger;

    entity@ dracula_apple;
    int dracula_apple_id = -1;
    float dracula_x, dracula_y;

    scene@ g;
    camera@ c;
    sprites@ spr;
    controllable@ p;

    ParticleController@ pc;
    [hidden] HashMap filth_map;
    [hidden] int tracked_filth;
    [hidden] bool active;
    int state_timer = 0;
    int zap_timer = 0;
    int rumble_timer = 0;
    float lightning_x, lightning_y;

    int filth, block, enemy;

    script() {
        @g = get_scene();
        @c = get_camera(0);
        @spr = create_sprites();

        for (int i=0; i<=20; ++i) g.layer_visible(i, true);
    }

    void on_level_start() {
        spr.add_sprite_set("script");
        @pc = ParticleController(spr, 20, 16);
        @p = controller_controllable(0);

        float fog_speed;
        int trigger_size;
        get_fog_setting(entity_by_id(day_id), day_fog, fog_speed, trigger_size);
        get_fog_setting(entity_by_id(bright_id), bright_fog, fog_speed, trigger_size);
        get_fog_setting(entity_by_id(night_id), night_fog, fog_speed, trigger_size);
        @text_trigger = entity_by_id(text_id);
        @dracula_trigger = entity_by_id(dracula_id);
        @ambience_trigger = entity_by_id(ambience_id);
        @music_trigger = entity_by_id(music_id);
        @no_music_trigger = entity_by_id(no_music_id);

        c.change_fog(day_fog, 0);

        g.get_filth_remaining(filth, block, enemy);

        g.layer_visible(13, false);
        g.layer_visible(15, false);
        g.layer_visible(17, false);
        g.layer_visible(20, false);
        active = false;
    }

    void checkpoint_load() {
        @p = controller_controllable(0);
        @text_trigger = entity_by_id(text_id);
        @dracula_trigger = entity_by_id(dracula_id);
        @ambience_trigger = entity_by_id(ambience_id);
        @music_trigger = entity_by_id(music_id);
        @no_music_trigger = entity_by_id(no_music_id);
        @dracula_apple = entity_by_id(dracula_apple_id);
    }

    void step(int) {
        if (active) {
            if (dracula_apple !is null and dracula_apple.x() != dracula_x) {
                g.remove_entity(dracula_apple);
                @dracula_apple = null;
                dracula_apple_id = -1;
                entity@ em = create_emitter(36, dracula_x, dracula_y-60, 100, 100, 20, 7);
                g.add_entity(em);
            }

            if (state_timer > 0) {
                if (--state_timer == 0) {
                    c.change_fog(night_fog, 1.0);
                }
            }

            if (--rumble_timer == 0) {
                g.play_script_stream("rumble" + rand() % RUMBLE_COUNT, 0, 0, 0, false, 1.0);
                rumble_timer = 60 * (15 + rand() % 10);
            }

        } else {

            if (zap_timer > 0) --zap_timer;
            if (point_rect_intersect(p.x(), p.y(), zap_x1, zap_y1, zap_x2, zap_y2)) {
                p.stun(6000, -300);
                g.play_script_stream("zap", 0, 0, 0, false, 1.0);
                zap_timer = 10;
            }

            hitbox@ h = p.hitbox();
            if (h !is null and h.hit_outcome() == 0 and h.state_timer() + 0.27 >= h.activate_time()) {
                entity@ e = entity_by_id(switch_id);
                if (e !is null) {
                    rectangle@ er = e.base_rectangle();
                    float ex = e.x();
                    float ey = e.y();

                    rectangle@ hr = h.base_rectangle();
                    float hx = h.x();
                    float hy = h.y();

                    if (rect_rect_intersect(
                        ex+er.left(), ey+er.top(), ex+er.right(), ey+er.bottom(),
                        hx+hr.left(), hy+hr.top(), hx+hr.right(), hy+hr.bottom(),
                        p.speed() / 60 + 1
                    )) {
                        lightning_x = ex;
                        lightning_y = ey;
                        g.remove_entity(e);
                        activate();
                    }
                }
            }
        }
    }

    void step_post(int) {
        pc.step();

        int px = int(floor(p.x() / 48));
        int py = int(floor(p.y() / 48));
        scan_rectangle(px - 3, py - 3, px + 3, py + 1, active);

        g.get_filth_remaining(filth, block, enemy);
        if (filth != tracked_filth) find_mismatches(px, py);
    }

    void draw(float) {
        if (active) {
            spr.draw_world(20, 20, "remains", 0, 0, remains_x, remains_y, 0, 0.8, 0.8, 0xFFFFFFFF);

            if (state_timer > 0) {
                for (int i=-5; i<5; ++i) {
                    draw_bolt(20, 0, lightning_x+200*i, lightning_y-1000, lightning_x-150*i, lightning_y+700, 4, 0xFFAADDDD, 0xFF448888, 100, 10);
                }
                draw_bolt(20, 0, lightning_x, lightning_y-1000, lightning_x, lightning_y+1000, 40, 0xFFAADDDD, 0xFF448888, 100, 15);
            }

            pc.draw();

            HashMapIterator iter(filth_map);
            Node@ next;
            while ((@next = iter.next()) !is null) {
                int x = next.key / 40009 - 20000;
                int y = next.key % 40009 - 20000;
                int shape = g.get_tile(x, y).type();
                draw_tile_filth(x, y, shape, next.value);
            }
        } else {
            if (zap_timer > 0) {
                draw_bolt(19, 0, orb_x, orb_y, p.x(), p.y()-48, 4, 0xFFAADDDD, 0xFF448888, 20, 20);
            }
        }
    }

    void editor_step() {
        if (scan) {
            int mx = int(round(g.mouse_x_world(0, 19) / 48));
            int my = int(round(g.mouse_y_world(0, 19) / 48));
            scan_rectangle(mx - 5, my - 5, mx + 5, my + 5, false);
        }

        if (reset) {
            filth_map.clear();
            tracked_filth = 0;
        }
    }

    void editor_draw(float) {
        if (scan) {
            int mx = int(round(g.mouse_x_world(0, 19) / 48));
            int my = int(round(g.mouse_y_world(0, 19) / 48));
            g.draw_rectangle_world(20, 0, 48 * (mx - 5), 48 * (my - 5), 48 * (mx + 5), 48 * (my + 5), 0, 0x88444444);
        }
    }

    void build_sprites(message@ msg) {
        for (uint i=0; i<PARTICLE_OFFSETS.size(); ++i) {
            string name = "particle" + i;
            msg.set_string(name, name);
            msg.set_int(name + "|offsetx", PARTICLE_OFFSETS[i][0]);
            msg.set_int(name + "|offsety", PARTICLE_OFFSETS[i][1]);
        }

        for (uint i=0; i<FILTH_OFFSETS.size(); ++i) {
            string name = "filth" + i;
            msg.set_string(name, name);
            msg.set_int(name + "|offsetx", FILTH_OFFSETS[i][0]);
            msg.set_int(name + "|offsety", FILTH_OFFSETS[i][1]);
        }

        for (uint i=0; i<FILTH_OFFSETS.size(); ++i) {
            string name = "full" + i;
            msg.set_string(name, name);
            msg.set_int(name + "|offsetx", FILTH_OFFSETS[i][0] + 48);
            msg.set_int(name + "|offsety", FILTH_OFFSETS[i][1]);
        }

        msg.set_string("remains", "remains");
    }

    void build_sounds(message@ msg) {
        for (int i=0; i<RATTLE_COUNT; ++i) {
            string name = "rattle" + i;
            msg.set_string(name, name);
        }

        for (int i=0; i<RUMBLE_COUNT; ++i) {
            string name = "rumble" + i;
            msg.set_string(name, name);
        }

        msg.set_string("thunder", "thunder");
        msg.set_string("rain", "rain");
        msg.set_string("zap", "zap");
    }

    void activate() {
        g.remove_entity(text_trigger);
        dracula_trigger.y(dracula_trigger.y() + 800);
        @dracula_apple = create_entity("hittable_apple");
        dracula_apple.x(dracula_trigger.x() + 80);
        dracula_apple.y(dracula_trigger.y() + 400);
        dracula_x = dracula_apple.x();
        dracula_y = dracula_apple.y();
        g.add_entity(dracula_apple);
        dracula_apple_id = dracula_apple.id();
        g.remove_entity(ambience_trigger);
        g.remove_entity(music_trigger);
        no_music_trigger.x(p.x());
        no_music_trigger.y(p.y());
        c.change_fog(bright_fog, 0);
        c.add_screen_shake(p.x(), p.y(), 0, 70);
        g.play_script_stream("thunder", 0, 0, 0, false, 0.8);
        g.play_script_stream("rain", 0, 0, 0, true, 0.5);
        g.layer_visible(12, false);
        g.layer_visible(13, true);
        g.layer_visible(14, false);
        g.layer_visible(15, true);
        g.layer_visible(16, false);
        g.layer_visible(17, true);
        g.layer_visible(19, false);
        g.layer_visible(20, true);
        active = true;
        state_timer = 3;
        rumble_timer = 60 * (10 + rand() % 5);
    }

    void draw_line_glow(int layer, int sublayer, float x1, float y1, float x2, float y2, int width, uint c1, uint c2) {
        g.draw_line_world(layer, sublayer, x1, y1, x2, y2, 2 * width, c2);
        g.draw_line_world(layer, sublayer, x1, y1, x2, y2, width, c1);
    }

    void draw_bolt(int layer, int sublayer, float x1, float y1, float x2, float y2, int width, uint c1, uint c2, float zig, int segments) {
        const float dx = (x2 - x1) / segments;
        const float dy = (y2 - y1) / segments;

        float x = x1 + rand_float(-zig, zig);
        float y = y1 + rand_float(-zig, zig);

        for (int i=1; i<=segments; ++i) {
            float nx = x1 + i * dx + rand_float(-zig, zig);
            float ny = y1 + i * dy + rand_float(-zig, zig);
            g.draw_rectangle_world(layer, sublayer, nx-0.8*width, ny-0.8*width, nx+0.8*width, ny+0.8*width, 0, c2);
            draw_line_glow(layer, sublayer, x, y, nx, ny, width, c1, c2);
            g.draw_rectangle_world(layer, sublayer, nx-0.4*width, ny-0.4*width, nx+0.4*width, ny+0.4*width, 0, c1);
            x = nx;
            y = ny;
        }
    }

    void find_mismatches(int px, int py) {
        int c=0;
        int x = px;
        int y = py;
        int radius = 1;
        int leg = 0;

        while (radius < 20) {
            ++c;
            scan_tile(x, y, active);

            if (tracked_filth == filth) return;

            switch (leg) {
                case 0:
                    if (++x == px+radius) ++leg;
                    break;
                case 1:
                    if (++y == py+radius) ++leg;
                    break;
                case 2:
                    if (--x == px-radius) ++leg;
                    break;
                case 3:
                    if (--y == py-radius) {
                        leg = 0;
                        ++radius;
                    }
                    break;
            }
        }

        if (tracked_filth < filth) puts("We lost some dust :/");
        else puts("We gained some dust :\\");

        tracked_filth = filth;
    }

    void scan_rectangle(int x1, int y1, int x2, int y2, bool fx=true) {
        for (int x=x1; x<=x2; ++x) {
            for (int y=y1; y<=y2; ++y) {
                scan_tile(x, y, fx);
            }
        }
    }

    void scan_tile(int x, int y, bool fx=true) {
        // This will be unique for every tile in a 40,000 tile box around the origin
        int key = 40009 * (20000 + x) + (20000 + y);

        TileFilth cur(g.get_tile_filth(x, y));
        TileFilth@ old = filth_map.get(key);

        if (fx) spawn_fx(x, y, old, cur);

        tracked_filth += cur.count;
        if (old !is null) {
            tracked_filth -= old.count;
        }

        if (cur.count == 0) {
            filth_map.remove(key);
        } else {
            filth_map.add(key, cur);
        }
    }

    void spawn_fx(int x, int y, TileFilth@ old, TileFilth@ cur) {
        int shape = g.get_tile(x, y).type();
        if (old is null) {
            if (cur.top) {
                spawn_particles(2, x, y, shape, 0);
                play_rattle(x, y);
            }
            if (cur.bottom) {
                spawn_particles(2, x, y, shape, 1);
                play_rattle(x, y);
            }
            if (cur.left) {
                spawn_particles(2, x, y, shape, 2);
                play_rattle(x, y);
            }
            if (cur.right) {
                spawn_particles(2, x, y, shape, 3);
                play_rattle(x, y);
            }
            return;
        }

        if (old.top and not cur.top) {
            spawn_particles(2, x, y, shape, 0);
            play_rattle(x, y);
        }
        if (old.bottom and not cur.bottom) {
            spawn_particles(2, x, y, shape, 1);
            play_rattle(x, y);
        }
        if (old.left and not cur.left) {
            spawn_particles(2, x, y, shape, 2);
            play_rattle(x, y);
        }
        if (old.right and not cur.right) {
            spawn_particles(2, x, y, shape, 3);
            play_rattle(x, y);
        }
    }

    void play_rattle(int x, int y) {
        g.play_script_stream("rattle" + rand() % RATTLE_COUNT, 0, 48 * x, 48 * y, false, 0.7);
    }

    void spawn_particles(int count, int tx, int ty, int shape, int side) {
        float x = 48*tx;
        float y = 48*ty;
        for (int i=0; i<count; ++i) {
            float r = rand_float(0, 48);
            switch (side) {
                case 0: // Top
                    switch (shape) {
                        case 0: case 3: case 5: case 6: case 11: case 13: case 14: case 18: case 19:
                            pc.spawn_particle(x+r, y, 0);
                            break;
                        case 1:
                            pc.spawn_particle(x+r, y+r/2, SLANT_ANGLE);
                            break;
                        case 2:
                            pc.spawn_particle(x+r, y+24+r/2, SLANT_ANGLE);
                            break;
                        case 9:
                            pc.spawn_particle(x+r, y+24-r/2, -SLANT_ANGLE);
                            break;
                        case 10:
                            pc.spawn_particle(x+r, y+48-r/2, -SLANT_ANGLE);
                            break;
                        case 17:
                            pc.spawn_particle(x+r, y+r, SLOPE_ANGLE);
                            break;
                        case 20:
                            pc.spawn_particle(x+r, y+48-r, -SLOPE_ANGLE);
                            break;
                    }
                    break;

                case 1: // Bottom
                    switch (shape) {
                        case 0: case 1: case 2: case 7: case 9: case 10: case 15: case 17: case 20:
                            pc.spawn_particle(x+r, y+48, 180);
                            break;
                        case 5:
                            pc.spawn_particle(x+r, y+24+r/2, 180+SLANT_ANGLE);
                            break;
                        case 6:
                            pc.spawn_particle(x+r, y+r/2, 180+SLANT_ANGLE);
                            break;
                        case 13:
                            pc.spawn_particle(x+r, y+48-r/2, 180-SLANT_ANGLE);
                            break;
                        case 14:
                            pc.spawn_particle(x+r, y+24-r/2, 180-SLANT_ANGLE);
                            break;
                        case 18:
                            pc.spawn_particle(x+r, y+48-r, 180-SLOPE_ANGLE);
                            break;
                        case 19:
                            pc.spawn_particle(x+r, y+r, 180+SLOPE_ANGLE);
                            break;
                    }
                    break;

                case 2: // Left
                    switch (shape) {
                        case 0: case 1: case 3: case 4: case 13: case 15: case 16: case 17: case 18:
                            pc.spawn_particle(x, y+r, 270);
                            break;
                        case 7:
                            pc.spawn_particle(x+r/2, y+48-r, 270+SLANT_ANGLE);
                            break;
                        case 8:
                            pc.spawn_particle(x+24+r/2, y+48-r, 270+SLANT_ANGLE);
                            break;
                        case 11:
                            pc.spawn_particle(x+24-r/2, y+48-r, 270-SLANT_ANGLE);
                            break;
                        case 12:
                            pc.spawn_particle(x+48-r/2, y+48-r, 270-SLANT_ANGLE);
                            break;
                    }
                    break;

                case 3: // Right
                    switch (shape) {
                        case 0: case 5: case 7: case 8: case 9: case 11: case 12: case 19: case 20:
                            pc.spawn_particle(x+48, y+r, 90);
                            break;
                        case 3:
                            pc.spawn_particle(x+48-r/2, y+r, 90+SLANT_ANGLE);
                            break;
                        case 4:
                            pc.spawn_particle(x+24-r/2, y+r, 90+SLANT_ANGLE);
                            break;
                        case 15:
                            pc.spawn_particle(x+24+r/2, y+r, 90-SLANT_ANGLE);
                            break;
                        case 16:
                            pc.spawn_particle(x+r/2, y+r, 90-SLANT_ANGLE);
                            break;
                    }
                    break;

            }
        }
    }

    void draw_tile_filth(int x, int y, int shape, TileFilth@ f) {
        int key = (40009 * (20000 + x) + (20000 + y));
        if (f.top) {
            string sprite = "full" + (key % 5 + 1);
            switch (shape) {
                case 0: case 3: case 5: case 6: case 11: case 13: case 14: case 18: case 19:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x, 48*y, 0, 1, 1, 0xFFFFFFFF);
                    break;
                case 1:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+2, 48*y+1, SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 2:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+2, 48*y+25, SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 9:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+2, 48*y+23, -SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 10:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+2, 48*y+47, -SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 17:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+7, 48*y+7, SLOPE_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 20:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+7, 48*y+41, -SLOPE_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
            }
        }

        if (f.bottom) {
            string sprite = "full" + ((key + 1) % 5 + 1);
            switch (shape) {
                case 0: case 1: case 2: case 7: case 9: case 10: case 15: case 17: case 20:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+48, 48*y+48, 180, 1, 1, 0xFFFFFFFF);
                    break;
                case 5:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+46, 48*y+47, 180+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 6:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+46, 48*y+23, 180+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 13:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+46, 48*y+25, 180-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 14:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+46, 48*y+1, 180-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 18:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+41, 48*y+7, 180-SLOPE_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 19:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+41, 48*y+41, 180+SLOPE_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
            }
        }

        if (f.left) {
            string sprite = "full" + ((key + 2) % 5 + 1);
            switch (shape) {
                case 0: case 1: case 3: case 4: case 13: case 15: case 16: case 17: case 18:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x, 48*y+48, 270, 1, 1, 0xFFFFFFFF);
                    break;
                case 7:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+1, 48*y+46, 270+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 8:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+25, 48*y+46, 270+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 11:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+23, 48*y+46, 270-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 12:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+47, 48*y+46, 270-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
            }
        }

        if (f.right) {
            string sprite = "full" + ((key + 3) % 5 + 1);
            switch (shape) {
                case 0: case 5: case 7: case 8: case 9: case 11: case 12: case 19: case 20:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+48, 48*y, 90, 1, 1, 0xFFFFFFFF);
                    break;
                case 3:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+47, 48*y+2, 90+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 4:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+23, 48*y+2, 90+SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 15:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+25, 48*y+2, 90-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
                case 16:
                    spr.draw_world(20, 14, sprite, 0, 0, 48*x+1, 48*y+2, 90-SLANT_ANGLE, 1, 1, 0xFFFFFFFF);
                    break;
            }
        }
    }
}


class ParticleController {
    sprites@ spr;
    int layer, sublayer;
    array<Particle@> particles;

    ParticleController(sprites@ spr, int layer, int sublayer) {
        @this.spr = spr;
        this.layer = layer;
        this.sublayer = sublayer;
    }

    void reset() {
        particles.resize(0);
    }

    void spawn_particle(float x, float y, float r) {
        r += rand_float(-15, 15);
        string sprite = "particle" + rand() % PARTICLE_OFFSETS.size();

        float vel = 2;
        float vx =  vel * cos(DEG2RAD * (90 - r));
        float vy = -vel * sin(DEG2RAD * (90 - r));
        float vr = rand_float(-5, 5);

        particles.insertLast(@Particle(sprite, 0.98, 0.1, x, y, r, vx, vy, vr, 30));
    }

    void step() {
        for (int i=int(particles.size())-1; i>=0; --i) {
            particles[i].step();

            if (particles[i].age >= particles[i].life) {
                particles.removeAt(i);
            }
        }
    }

    void draw() {
        for (uint i=0; i<particles.size(); ++i) {
            particles[i].draw(spr, layer, sublayer);
        }
    }
}


class Particle {
    string sprite;
    float friction, gravity;
    float x, y, r, vx, vy, vr;
    int age, life;

    Particle(
        string sprite, float friction, float gravity,
        float x, float y, float r,
        float vx, float vy, float vr,
        int life
    ) {
        this.sprite = sprite;
        this.friction = friction;
        this.gravity = gravity;
        this.x = x;
        this.y = y;
        this.r = r;
        this.vx = vx;
        this.vy = vy;
        this.vr = vr;
        this.life = life;
    }

    void step() {
        vy += gravity;

        vx *= friction;
        vy *= friction;
        // vr *= friction;

        x += vx;
        y += vy;
        r += vr;

        ++age;
    }

    void draw(sprites@ spr, int layer, int sublayer) {
        int opacity = 255 - int(floor(255.0 * age / life));
        spr.draw_world(layer, sublayer, sprite, 0, 0, x, y, r, 1, 1, (opacity << 24) + 0xFFFFFF);
    }
}

float rand_float(float a, float b) {
    return rand() / 1073741824.0 * (b - a) + a;
}

bool rect_rect_intersect(
    float al, float at, float ar, float ab,
    float bl, float bt, float br, float bb,
    float lenience=0
) {
    return (
        al < br + lenience and 
        ar > bl - lenience and
        at < bb + lenience and
        ab > bt - lenience
    );
}

bool point_rect_intersect(
    float x, float y,
    float l, float t, float r, float b
) {
    return l <= x and x <= r and t <= y and y <= b;
}
