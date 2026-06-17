const string EMBED_swat = "swat.ogg";

class script {
    bool fly = false;
    scene@ g;
    int respawn_timer = 0;

    [position,mode:world,layer:19,y:helping_hand_y] float helping_hand_x;
    [hidden] float helping_hand_y;

    [entity] int text_1;
    [entity] int text_2;
    [entity] int text_3;
    [entity] int text_4;

    script() {
        @g = get_scene();
        g.layer_scale(7, 0.9);
        g.layer_visible(18, true);
        get_camera(0).script_camera(false);
    }

    void checkpoint_load() {
        g.layer_visible(18, true);
    }

    void build_sounds(message@ msg) {
        msg.set_string("swat", "swat");
    }

    void step(int) {
        controllable@ c = controller_controllable(0);
        if (c !is null) {
            dustman@ d = c.as_dustman();
            if (d !is null) {
                if (fly) {
                    d.dash(10);
                }

                if (respawn_timer > 0) {
                    d.set_speed_xy(0, 0);
                    d.light_intent(0);
                    d.heavy_intent(0);
                    d.dash_intent(0);
                    d.jump_intent(0);
                    d.fall_intent(0);
                    if (respawn_timer == 90) {
                        ouchie();
                        d.x(18000);
                    }
                    if (respawn_timer == 1) {
                        d.kill(false);
                    }
                    --respawn_timer;
                }
            }
        }
    }

    void move_text() {
        entity@ t1 = entity_by_id(text_1);
        entity@ t2 = entity_by_id(text_2);
        entity@ t3 = entity_by_id(text_3);
        entity@ t4 = entity_by_id(text_4);

        if (t1.y() < 1800) {
            t1.y(t1.y() + 600);
            t2.y(t2.y() + 600);
            t3.y(t3.y() + 600);
            t4.y(t4.y() + 600);
        }
    }

    void ouchie() {
        controllable@ c = controller_controllable(0);
        if (c !is null) {
            dustman@ d = c.as_dustman();
            if (d !is null) {
                if (respawn_timer == 0) {
                    float x = d.x();
                    float y = d.y();
                    create_splat(x, y-48);
                    g.combo_break_count(g.combo_break_count() + 1);
                    d.combo_timer(0.00001);
                    respawn_timer = 90;
                    d.x(13982);
                    d.y(1730);
                    move_text();
                    g.save_checkpoint(13982, 1730);
                    d.x(x);
                    d.y(y);
                } else {
                    float delta_x = d.x() - helping_hand_x + 10;
                    float delta_y = d.y() - 48 - helping_hand_y;

                    array<int> prop_ids = {};
                    int n = g.get_prop_collision(helping_hand_y - 100, helping_hand_y + 5000, helping_hand_x - 100, helping_hand_x + 100);
                    for (int i=0; i<n; ++i) {
                        prop@ p = g.get_prop_collision_index(i);
                        if (p !is null and p.prop_set() != 2) {
                            prop_ids.insertLast(p.id());
                        }
                    }
                    for (int i=0; i<prop_ids.size(); ++i) {
                        prop@ p = prop_by_id(prop_ids[i]);
                        if (p !is null) {
                            p.x(p.x() + delta_x);
                            p.y(p.y() + delta_y);
                        }
                    }

                    get_camera(0).script_camera(true);
                    g.play_script_stream("swat", 0, 0, 0, false, 1.0);
                }
            }
        }
    }

    void create_splat(float x, float y) {
        prop@ splat = create_prop();
        splat.x(x);
        splat.y(y);
        splat.rotation(rand() / 1000.0);
        splat.prop_set(2);
        splat.prop_group(5);
        splat.prop_index(18);
        splat.palette(1);
        splat.layer(7);
        splat.sub_layer(22);
        g.add_prop(splat);
    }
}

class gives_you_wings : trigger_base {
    script@ s;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
    }

    void activate(controllable@ p) {
        if (p.player_index() != -1) {
            s.fly = true;
        }
    }
}

class well_that_was_short_lived : trigger_base {
    script@ s;
    bool splatted = false;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
    }

    void activate(controllable@ p) {
        if (p.player_index() != -1 and not splatted) {
            splatted = true;
            s.ouchie();
        }
    }
}
