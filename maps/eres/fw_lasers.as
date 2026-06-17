#include "fw_base.as"

class script {
    [text] array<laser> lasers;
    [colour] uint background = 0xFF3A354C;

    scene@ g;
    dustman@ player;
    fog_setting@ fog;

    int frame = 0;
    bool player_dead = false;
    bool level_ended = false;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();
        reset_fog_trigger();
        for (int i=0; i<lasers.size(); ++i) {
            lasers[i].init(this);
        }
    }

    void on_level_end() {
        player_dead = false;
        level_ended = true;
        for (int i=0; i<lasers.size(); ++i) {
            lasers[i].disabled = false;
            lasers[i].murderer = false;
        }
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();
        reset_fog_trigger();
    }

    void reset_fog_trigger() {
        @fog = get_camera(0).get_fog();
        // Set background colour
        fog.bg_top(background);
        fog.bg_mid(background);
        fog.bg_bot(background);
        // Remove stars
        fog.stars_top(0);
        fog.stars_mid(0);
        fog.stars_bot(0);
        // Set layer colours
        for (uint layer=0; layer<21; ++layer) {
            fog.layer_percent(layer, 1);
            fog.layer_colour(layer, 0xFF000000);
        }
        fog.layer_colour(18, 0xFFFFFFFF);
        fog.layer_colour(19, background);
        get_camera(0).change_fog(fog, 0);
    }

    void step(int entities) {
        ++frame;
        if (not (player is null or player_dead or level_ended)) {
            // Check collision against the lasers
            for (int i=0; i<lasers.size(); ++i) {
                lasers[i].step(player);
                if (player.dead()) {
                    player_dead = true;
                    g.combo_break_count(g.combo_break_count() + 1);
                    break;
                }
            }

            // Make the player red if they are holding jump
            uint colour;
            if (player.jump_intent() > 0) {
                colour = 0xFFFF0000;
            } else {
                colour = 0xFFFFFFFF;
            }
            fog.layer_colour(18, player.dead() ? background : 0xFFFFFFFF);
            fog.colour(18, 10, colour);
            fog.colour(18, 14, colour);
            fog.colour(18, 15, colour);
            get_camera(0).change_fog(fog, 0);

        }
    }

    void editor_draw(float sub_frame) {
        canvas@ c = create_canvas(false, 20, 1);
        textfield@ t = create_textfield();
        for (int i=0; i<lasers.size(); ++i) {
            lasers[i].editor_draw(g, i, c, t);
        }
    }

    void draw(float sub_frame) {
        for (int i=0; i<lasers.size(); ++i) {
            lasers[i].draw(g, frame, player_dead);
        }
    }
}

class laser : wall_base {
    [option,0:White,1:Red,2:Pink] int type;

    void init(script@ s) {
        switch (type) {
            case 0:
                colour = 0xFFFFFF;
                break;
            case 1:
                colour = 0xFF0000;
                break;
            case 2:
                colour = 0xFF2277;
                break;
        }

        wall_base::init(s);
    }

    void step(dustman@ player) {
        bool jump_held = player.jump_intent() > 0;

        disabled = false;
        if (touching_player(player)) {
            switch (type) {
                case 0:
                    if (jump_held) {
                        kill_player(player);
                    } else {
                        disabled = true;
                    }
                    break;
                case 1:
                    if (jump_held) {
                        disabled = true;
                    } else {
                        kill_player(player);
                    }
                    break;
                case 2:
                    kill_player(player);
                    break;
            }
        }
    }

    bool touching_player(dustman@ player) {
        const int w = 14;
        const int h = 94;
        return (
            lines_intersect(player.x()-w, player.y()  , player.x()-w, player.y()-h, x1, y1, x2, y2) ||
            lines_intersect(player.x()+w, player.y()  , player.x()+w, player.y()-h, x1, y1, x2, y2) ||
            lines_intersect(player.x()-w, player.y()  , player.x()+w, player.y()  , x1, y1, x2, y2) ||
            lines_intersect(player.x()-w, player.y()-h, player.x()+w, player.y()-h, x1, y1, x2, y2)
        );
    }

    void kill_player(dustman@ player) {
        float to_prev_x = player.prev_x()-x1;
        float to_prev_y = player.prev_y()-y1;

        player.kill(false);
        murderer = true;

        if (dot(to_prev_x, to_prev_y, perp_x, perp_y) >= 0) {
            player.stun(300*perp_x, 300*perp_y);
        } else {
            player.stun(-300*perp_x, -300*perp_y);
        }
    }
}
