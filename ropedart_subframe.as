const string EMBED_rope = "rope.png";
const string EMBED_rope_straight = "rope_straight.png";
const string EMBED_dart = "dart.png";
const string EMBED_dart_straight = "dart_straight.png";

const string EMBED_thud = "thud.ogg";
const string EMBED_clink = "clink.ogg";
const string EMBED_swoosh = "swoosh.ogg";

class script : callback_base {
    scene@ g;
    dustman@ player;

    [text] float range = 480.0;
    [text] float pull_vel = 800.0;
    [text] float shot_height = 48.0;
    [text] int ext_time = 10;
    [text] int out_time = 5;
    [text] int ret_time = 30;
    [text] bool restrict_to_tile = true;
    [text] int sprite_set = 2;
    [text] int sprite_tile = 8;

    prop@ p;

    ropedart@ rd;

    sprites@ s;

    script() {
        @g = get_scene();
        @s = create_sprites();
        @rd = ropedart(this);
    }

    void build_sprites(message@ msg) {
        msg.set_string("rope", "rope");
        msg.set_int("rope|offsetx", 8);
        msg.set_int("rope|offsety", 12);
        msg.set_string("rope_straight", "rope_straight");
        msg.set_int("rope_straight|offsetx", 8);
        msg.set_int("rope_straight|offsety", 12);
        msg.set_string("dart", "dart");
        msg.set_int("dart|offsetx", 36);
        msg.set_int("dart|offsety", 12);
        msg.set_string("dart_straight", "dart_straight");
        msg.set_int("dart_straight|offsetx", 36);
        msg.set_int("dart_straight|offsety", 12);
    }

    void build_sounds(message@ msg) {
        msg.set_string("thud", "thud");
        msg.set_string("clink", "clink");
        msg.set_string("swoosh", "swoosh");
    }

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();
        player.on_subframe_end_callback(this, "on_subframe_end", 0);

        s.add_sprite_set("script");
    }

    void on_subframe_end(dustman@ dm, int) {
        if (player !is null) {
            rd.step();
            if (player.jump_intent() == 2) {
                player.jump_intent(0);
            }
        }
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();
        player.on_subframe_end_callback(this, "on_subframe_end", 0);
        rd.reset();
    }

    void draw(float sub_frame) {
        rd.draw();
    }
}

class ropedart {
    // 0 = Idle
    // 1 = Extending
    // 2 = Out
    // 3 = Retracting
    // 4 = Pulling
    int state = 0;
    int state_timer = 0;

    int dir = 0;

    float dart_x = 0;
    float dart_y = 0;

    // The number of air charges the player started with
    int air_charges = 0;
    int max_charges = 0;

    script@ s;

    ropedart(script@ sc) {
        @s = sc;
    }

    void reset() {
        state = 0;
    }

    void step() {
        if (state == 0 and not s.player.dead() and s.player.taunt_intent() > 0) shoot();
        if (state > 0 and state < 4) rope();
        if (state == 4) pull();
    }

    void shoot() {
        state = 1;
        state_timer = 5 * s.ext_time;
        dir = s.player.face();
        if (s.player.x_intent() != 0) dir = s.player.x_intent();
        s.g.play_script_stream("swoosh", 0, 0, 0, false, 0.3);
    }

    void rope() {
        // Update dart position
        float mul = 0;
        switch (state) {
            case 1:
                mul = 1 - float(state_timer) / (5 * s.ext_time);
                break;
            case 2:
                mul = 1;
                break;
            case 3:
                mul = float(state_timer) / (5 * s.ret_time);
                break;
        }
        dart_x = s.player.x() + dir * mul * s.range;
        dart_y = s.player.y() - s.shot_height;

        // Test if the dart hit
        raycast@ ray = s.g.ray_cast_tiles(
            s.player.x(),
            dart_y,
            dart_x,
            dart_y
        );
        if (ray.hit()) {
            // Check that we are allowed to attach to this tile
            tileinfo@ tile = s.g.get_tile(ray.tile_x(), ray.tile_y());
            if (not s.restrict_to_tile or (tile.sprite_set() == s.sprite_set and tile.sprite_tile() == s.sprite_tile)) {
                state = 4;
                dart_x = ray.hit_x();
                dart_y = ray.hit_y();
                air_charges = s.player.dash();
                max_charges = s.player.dash_max();
                // Allow us to check if they regain air charges
                s.player.dash_max(2);
                // Ensure that the player can dash/jump out
                s.player.dash(1);
                s.player.face(dir);
                if (dir * s.player.x_speed() < s.pull_vel) {
                    s.player.set_speed_xy(dir * s.pull_vel, 0);
                } else {
                    s.player.set_speed_xy(s.player.x_speed(), 0);
                }
                // If the player is falling, set state to hover
                if (s.player.state() == 5) {
                    s.player.state(7);
                }
                s.g.play_script_stream("thud", 0, 0, 0, false, 0.2);
                return;
            } else {
                // Start retracting from the point of impact
                float fract = abs(ray.hit_x() - s.player.x()) / s.range;
                state_timer = fract * 5 * s.ret_time;
                state = 3;
                s.g.play_script_stream("clink", 0, 0, 0, false, 0.2);
            }
        }

        // Update state
        --state_timer;
        if (state_timer <= 0) {
            switch (state) {
                case 1:
                    // Stay out
                    state = 2;
                    state_timer = 5 * s.out_time;
                    break;
                case 2:
                    // Start retracting
                    state = 3;
                    state_timer = 5 * s.ret_time;
                    break;
                case 3:
                    // Idle
                    state = 0;
                    break;
            }
        }
    }

    void pull() {
        // Test for regained air charges
        if (s.player.dash() == 2) {
            air_charges = max_charges;
        }

        // Jump/dash cancel
        if (
            s.player.fall_intent() == 2 or
            s.player.dash_intent() == 2 or
            s.player.jump_intent() == 2
        ) {
            cancel();
            return;
        }

        // Check for finished pull
        if ((dir > 0 and s.player.x()+24 > dart_x) or (dir < 0 and s.player.x()-24 < dart_x)) {
            cancel();
            return;
        }

        // Move player
        if (dir * s.player.x_speed() < s.pull_vel) {
            s.player.set_speed_xy(dir * s.pull_vel, 0);
        } else {
            s.player.set_speed_xy(s.player.x_speed(), 0);
        }
        s.player.y(dart_y+s.shot_height);
    }

    void cancel() {
        s.player.dash(air_charges);
        s.player.dash_max(max_charges);
        state = 0;
    }

    void draw() {
        if (state > 0) {
            draw_rope();
        }
    }

    void draw_rope() {
        const int dart_width = 35;
        const int rope_width = 15;

        const float x1 = s.player.x();
        const float x2 = dart_x;
        const float y = s.player.y() - s.shot_height;
        const string straight = state < 4 ? "" : "_straight";

        // If there is space, draw the dart
        if (dir * (x2 - x1) + rope_width > dart_width) {
            s.s.draw_world(18, 9, "dart"+straight, 1, 1, x2, y, 0, dir, 1, 0xFFFFFFFF);
        }

        // Draw the rope
        const int segments = floor((dir * (x2 - x1) - dart_width + rope_width / 2) / rope_width);
        const int x_start = x2 - dir * (dart_width + rope_width / 2);
        for (int i=0; i<segments; ++i) {
            const int x_scale = dir * ((i % 2) * 2 - 1);
            const int x_offset = -dir * i * rope_width;
            s.s.draw_world(18, 9, "rope"+straight, 1, 1, x_start + x_offset, y, 0, x_scale, 1, 0xFFFFFFFF);
        }
    }
}
