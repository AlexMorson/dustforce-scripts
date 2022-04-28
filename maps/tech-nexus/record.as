#include "lib/math/math.cpp"

const array<string> STATES = {"idle", "victory", "run", "skid", "superskid", "fall", "land", "hover", "jump", "dash", "crouch_jump", "wall_run", "wall_grab", "wall_grab_idle", "wall_grab_release", "roof_grab", "roof_grab_idle", "roof_run", "slope_slide", "raise", "stun", "stun_wall", "stun_ground", "slope_run", "hop", "spawn", "fly", "thanks_cleansed", "idle_cleansed", "idle_cleansed_thanks", "fall_cleansed", "land_cleansed", "cleansed", "block", "wall_dash"};

const dictionary CHARACTER = {
    {"dustman", "dm"},
    {"vdustman", "vdm"},
    {"dustgirl", "dg"},
    {"vdustgirl", "vdg"},
    {"dustkid", "dk"},
    {"vdustkid", "vdk"},
    {"dustworth", "do"},
    {"vdustworth", "vdo"}
};

class script
{
    controllable@ p;

    player_state last_state;
    array<effect@> effects;
    array<hitbox@> attacks;

    void on_level_start()
    {
        @p = controller_controllable(0);
        puts("#########################################");
    }

    void entity_on_add(entity@ e) {
        hitbox@ h = e.as_hitbox();
        if (h !is null && h.owner().is_same(p)) {
            attacks.insertLast(@h);
        }
    }

    void step(int)
    {
        if (p.attack_state() == 0) {
            // State timer doesn't loop in fall
            int state_timer = int(floor(p.state_timer()));
            if (p.state() == 5) state_timer %= 4;

            puts(p.sprite_index() + " " + state_timer + " " + (p.x() + p.draw_offset_x()) + " " + (p.y() + p.draw_offset_y()) + " " + p.face() + " " + p.rotation());
        } else {
            puts(p.attack_sprite_index() + " " + p.attack_timer() + " " + (p.x() + p.draw_offset_x()) + " " + (p.y() + p.draw_offset_y()) + " " + p.attack_face() + " " + p.rotation());
        }
    }

    void step_post(int) { 
        compute_fx();
        compute_attacks();

        for (uint i=0; i<effects.size(); ++i)
        {
            effects[i].print();
        }
        effects.resize(0);
    }

    void compute_fx() {
        player_state new_state(p);
        dustman@ d = p.as_dustman();

        string c = string(CHARACTER[d.character()]);
        float x = new_state.x;
        float y = new_state.y;
        int face = new_state.face;

        if (
            (new_state.state == "jump" && last_state.state != "jump") ||
            (new_state.jump_intent == 2 && last_state.jump_intent != 2)
        ) {
            if (last_state.air_charges == new_state.air_charges) {
                if (last_state.ground) {
                    float direction = sign(new_state.x_speed);
                    if (direction == 0) {
                        effects.insertLast(@effect(c+"jump", x, y, face));
                    } else if (direction == new_state.face) {
                        effects.insertLast(@effect(c+"fjump", x, y, face));
                    } else {
                        effects.insertLast(@effect(c+"bjump", x, y, face));
                    }
                } else if (last_state.wall_left) {
                    effects.insertLast(@effect(c+"walljump", x, y+8, -1));
                } else if (last_state.wall_right) {
                    effects.insertLast(@effect(c+"walljump", x, y+8, 1));
                }
            } else {
                effects.insertLast(@effect(c+"dbljump", x, y, 1));
            }
        }

        if (new_state.dash_intent == 2) {
            if (last_state.air_charges <= new_state.air_charges && (last_state.ground || (!last_state.ground && new_state.ground))) {
                effects.insertLast(@effect(c+"dash", x, y, face));
            } else {
                if (last_state.state == "wall_dash" || last_state.state == "wall_run" || last_state.state == "wall_grab" || last_state.state == "wall_grab_idle") {
                    effects.insertLast(@effect(c+"airdash", x + 24*last_state.face, y, last_state.face));
                } else {
                    effects.insertLast(@effect(c+"airdash", x, y, face));
                }
            }
        }

        if (new_state.fall_intent == 2) {
            effects.insertLast(@effect(c+"fastfall", x, y, 1));
        }

        if (new_state.ground && !last_state.ground) {
            if (last_state.y_speed >= 1500.0) {
                effects.insertLast(@effect(c+"heavyland", x, y, 1));
            } else if (new_state.state != "dash" && new_state.state != "wall_grab" && new_state.state != "wall_grab_idle") {
                effects.insertLast(@effect(c+"land", x, y, 1));
            }
        }

        if (new_state.state == "roof_run" && last_state.state != "roof_run") {
            effects.insertLast(@effect(c+"dash", x, y-96, -face, 180));
        }

        if (new_state.state == "wall_run" && last_state.state != "wall_run") {
            effects.insertLast(@effect(c+"dash", x+20*face, y-32, face, -90*face));
        }

        last_state = new_state;
    }

    void compute_attacks() {
        for (int i=attacks.length()-1; i>=0; --i) {
            if (@attacks[i] is null || attacks[i].hit_outcome() == 4) {
                attacks.removeAt(i);
                continue;
            }

            if (attacks[i].hit_outcome() == 1 || attacks[i].hit_outcome() == 2 || attacks[i].hit_outcome() == 3) {
                effect@ e;
                dustman@ d = p.as_dustman();
                string c = string(CHARACTER[d.character()]);
                int damage = attacks[i].damage();
                int direction = int(abs(attacks[i].attack_dir()));
                float x = p.x();
                float y = p.y();
                int face = p.attack_face();
                int freeze = attacks[i].hit_outcome() == 2 ? 0 : (damage == 1 ? 2 : 7);
                if (damage == 1) {
                    if (direction == 30) {
                        @e = @effect(c+"groundstrikeu1", x, y, face, 0, freeze);
                    } else if (direction == 85) {
                        @e = @effect(c+"groundstrike1", x, y, face, 0, freeze);
                    } else if (direction == 150) {
                        @e = @effect(c+"airstriked1", x, y, face, 0, freeze);
                    } else if (direction == 151) {
                        @e = @effect(c+"groundstriked", x, y, face, 0, freeze);
                    }
                } else if (damage == 3) {
                    if (direction == 30) {
                        @e = @effect(c+"heavyu", x, y, face, 0, freeze);
                    } else if (direction == 85) {
                        @e = @effect(c+"heavyf", x, y, face, 0, freeze);
                    } else if (direction == 150) {
                        if (p.ground()) {
                            @e = @effect(c+"heavyd", x, y, face, 0, freeze);
                        } else {
                            @e = @effect(c+"airheavyd", x, y, face, 0, freeze);
                        }
                    }
                }
                effects.insertLast(@e);
                attacks.removeAt(i);
            }
        }
    }
}

class player_state {
    bool ground = true;
    bool wall_left = false;
    bool wall_right = false;
    int air_charges = 0;
    string state = "idle";
    float x_speed = 0.0;
    float y_speed = 0.0;
    float x = 0.0;
    float y = 0.0;
    int jump_intent = 0;
    int dash_intent = 0;
    int fall_intent = 0;
    int face = 1;

    player_state() {}
    player_state(controllable@ p) {
        dustman@ d = p.as_dustman();

        ground = p.ground();
        wall_left = p.wall_left();
        wall_right = p.wall_right();
        air_charges = d.dash();
        state = STATES[p.state()];
        x_speed = p.x_speed();
        y_speed = p.y_speed();
        x = p.x();
        y = p.y();
        jump_intent = p.jump_intent();
        dash_intent = p.dash_intent();
        fall_intent = p.fall_intent();
        face = p.face();
    }
}

class effect {
    string sprite_name;
    int face;
    float x;
    float y;
    float rotation;
    int freeze;

    effect(string sprite_name, float x, float y, int face, float rotation=0, int freeze=0) {
        this.sprite_name = sprite_name;
        this.x = x;
        this.y = y;
        this.face = face;
        this.rotation = rotation;
        this.freeze = freeze;
    }

    void print() {
        puts(sprite_name + " " + x + " " + y + " " + face + " " + rotation + " " + freeze);
    }
}
