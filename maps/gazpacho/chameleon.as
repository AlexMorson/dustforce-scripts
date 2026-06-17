#include "lib/std.cpp"
#include "lib/math/math.cpp"
#include "lib/drawing/common.cpp"

const string EMBED_splat = "swat.ogg";

enum State {
    Idle,
    EatPlayer,
    EatPlayerRetract,
    Respawn
};

class script {
    [text] array<Place> places;

    [position,mode:world,layer:19,y:body_top] float body_left;
    [hidden] float body_top;
    [position,mode:world,layer:19,y:body_bottom] float body_right;
    [hidden] float body_bottom;

    [position,mode:world,layer:19,y:mouth_top] float mouth_left;
    [hidden] float mouth_top;
    [position,mode:world,layer:19,y:mouth_bottom] float mouth_right;
    [hidden] float mouth_bottom;

    [position,mode:world,layer:19,y:tongue_top] float tongue_left;
    [hidden] float tongue_top;
    [position,mode:world,layer:19,y:tongue_bottom] float tongue_right;
    [hidden] float tongue_bottom;

    [position,mode:world,layer:19,y:join_y] float join_x;
    [hidden] float join_y;

    [position,mode:world,layer:19,y:jaw_y] float jaw_x;
    [hidden] float jaw_y;

    [position,mode:world,layer:19,y:eye_y] float eye_x;
    [hidden] float eye_y;

    [position,mode:world,layer:19,y:socket_y] float socket_x;
    [hidden] float socket_y;

    [hidden] PropGroup body_props;
    [hidden] PropGroup mouth_props;
    [hidden] PropGroup eye_props;
    [hidden] Tongue tongue;

    scene@ g;
    controllable@ p;

    [hidden] int place_index = 0;
    [hidden] int state = State::Idle;
    [hidden] int state_timer = 0;

    script() {
        @g = get_scene();
    }

    void build_sounds(message@ msg) {
        msg.set_string("splat", "splat");
    }

    void on_level_start() {
        @p = controller_controllable(0);

        body_props.init(body_left, body_top, body_right, body_bottom);
        mouth_props.init(mouth_left, mouth_top, mouth_right, mouth_bottom, jaw_x, jaw_y);
        eye_props.init(eye_x, eye_y, eye_x, eye_y, eye_x, eye_y);
        tongue.init(tongue_left, tongue_top, tongue_right, tongue_bottom);

        move(0);
    }

    void checkpoint_load() {
        @p = controller_controllable(0);

        body_props.init(body_left, body_top, body_right, body_bottom);
        mouth_props.init(mouth_left, mouth_top, mouth_right, mouth_bottom, jaw_x, jaw_y);
        eye_props.init(eye_x, eye_y, eye_x, eye_y, eye_x, eye_y);
        tongue.init(tongue_left, tongue_top, tongue_right, tongue_bottom);
    }

    void clear_intents() {
        p.x_intent(0);
        p.y_intent(0);
        p.taunt_intent(0);
        p.heavy_intent(0);
        p.light_intent(0);
        p.fall_intent(0);
        p.jump_intent(0);
        p.dash_intent(0);
    }

    void step(int) {
        switch (state) {
            case State::Idle:
                break;
            case State::EatPlayer: {
                float tx = places[place_index].x + join_x - body_left;
                float ty = places[place_index].y + join_y - body_top;
                float dx = p.x() - tx;
                float dy = p.y() - 48 - ty;
                float angle = atan2(dy, dx);
                float len = max(0.0, sqrt(dx*dx+dy*dy) - 40);

                p.x(tx + len * cos(angle));
                p.y(ty + len * sin(angle) + 48);
                p.set_speed_xy(0, 0);
                clear_intents();
                if (len == 0) {
                    state = State::Respawn;
                    state_timer = 60;
                    close_mouth();
                }

                update_tongue(RAD2DEG * angle, len);
                break;
            }
            case State::Respawn:
                p.set_speed_xy(0, 0);
                clear_intents();
                if (--state_timer <= 0) {
                    dustman@ dm = p.as_dustman();
                    if (dm !is null) {
                        dm.kill(false);
                        g.combo_break_count(g.combo_break_count() + 1);
                    }
                }
                break;
        }
        update_eye();
    }

    void move(int i) {
        place_index = i;

        float ox = places[i].x - body_left;
        float oy = places[i].y - body_top;

        body_props.update_offset_x(ox);
        body_props.update_offset_y(oy);

        mouth_props.update_offset_x(ox + join_x - mouth_left);
        mouth_props.update_offset_y(oy + join_y - mouth_top);

        eye_props.update_offset_x(ox + socket_x - eye_x);
        eye_props.update_offset_y(oy + socket_y - eye_y);

        tongue.update_offset_x(ox + join_x - tongue_left);
        tongue.update_offset_y(oy + join_y - tongue_top);
    }

    void update_eye() {
        float dx = p.x() - (places[place_index].x + socket_x - body_left);
        float dy = p.y() - (places[place_index].y + socket_y - body_top);
        float angle = atan2(dy, dx);
        eye_props.set_rotation(RAD2DEG * angle);
    }

    void update_tongue(float angle, float len) {
        tongue.update_length(len);
        tongue.set_rotation(angle);
    }

    void open_mouth() {
        mouth_props.set_rotation(45);
    }

    void close_mouth() {
        mouth_props.set_rotation(0);
    }

    void editor_draw(float sub_frame) {
        outline_rect(g, 22, 0, body_left, body_top, body_right, body_bottom, 1, 0xAAFF0000);
        outline_rect(g, 22, 0, mouth_left, mouth_top, mouth_right, mouth_bottom, 1, 0xAAFF0000);
        outline_rect(g, 22, 0, tongue_left, tongue_top, tongue_right, tongue_bottom, 1, 0xAAFF0000);
        outline_rect(g, 22, 0, join_x, join_y, join_x+mouth_right-mouth_left, join_y+mouth_bottom-mouth_top, 1, 0xAAFF0000);
        g.draw_rectangle_world(22, 0, jaw_x-3, jaw_y-3, jaw_x+3, jaw_y+3, 0, 0xAAFF0000);
        g.draw_rectangle_world(22, 0, eye_x-3, eye_y-3, eye_x+3, eye_y+3, 0, 0xAAFF0000);
        g.draw_rectangle_world(22, 0, socket_x-3, socket_y-3, socket_x+3, socket_y+3, 0, 0xAAFF0000);

        for (uint i=0; i<places.size(); ++i) {
            float x = places[i].x;
            float y = places[i].y;
            outline_rect(g, 22, 0, x, y, x+body_right-body_left, y+body_bottom-body_top, 1, 0xAAFF0000);
        }
    }
}

class PropGroup {
    [hidden] array<Prop> props;
    [hidden] float anchor_x;
    [hidden] float anchor_y;
    [hidden] float offset_x = 0;
    [hidden] float offset_y = 0;
    [hidden] float rot = 0;
    [hidden] bool initialised = false;

    void init(float x1, float y1, float x2, float y2, float anchor_x = 0, float anchor_y = 0) {
        if (initialised) {
            requery_props();
        } else {
            initialised = true;
            scene@ g = get_scene();
            this.anchor_x = anchor_x;
            this.anchor_y = anchor_y;
            int n = g.get_prop_collision(y1, y2, x1, x2);
            props.resize(0);
            for (int i=0; i<n; ++i) {
                prop@ p = g.get_prop_collision_index(i);
                if (p.layer() == 20) {
                    props.insertLast(Prop(p));
                }
            }
            update_offset_x(offset_x);
            update_offset_y(offset_y);
        }
    }

    void requery_props() {
        for (uint i=0; i<props.size(); ++i) {
            props[i].requery_prop();
        }
    }

    void update_offset_x(float x) {
        this.offset_x = x;
        if (rot == 0) {
            for (uint i=0; i<props.size(); ++i) {
                if (props[i].p !is null) {
                    props[i].p.x(props[i].initial_x + x);
                }
            }
        } else {
            set_rotation(rot);
        }
    }

    void update_offset_y(float y) {
        this.offset_y = y;
        if (rot == 0) {
            for (uint i=0; i<props.size(); ++i) {
                if (props[i].p !is null) {
                    props[i].p.y(props[i].initial_y + y);
                }
            }
        } else {
            set_rotation(rot);
        }
    }

    void set_rotation(float rot) {
        this.rot = rot;
        for (uint i=0; i<props.size(); ++i) {
            if (props[i].p !is null) {
                float rot_x, rot_y;
                rotate(props[i].initial_x - anchor_x, props[i].initial_y - anchor_y, PI / 180 * rot, rot_x, rot_y);
                props[i].p.x(anchor_x + rot_x + offset_x);
                props[i].p.y(anchor_y + rot_y + offset_y);
                props[i].p.rotation(props[i].initial_rot + rot);
            }
        }
    }
}

class Prop {
    [hidden] int prop_id;
    [hidden] float initial_x;
    [hidden] float initial_y;
    [hidden] float initial_rot;

    prop@ p;

    Prop() {}

    Prop(prop@ p) {
        @this.p = @p;
        prop_id = p.id();
        initial_x = p.x();
        initial_y = p.y();
        initial_rot = p.rotation();
    }

    void requery_prop() {
        @p = prop_by_id(prop_id);
    }
}

class Tongue : PropGroup {
    [hidden] float x2;
    [hidden] float w;
    [hidden] float initial_anchor_x;
    [hidden] float len = 0;

    void init(float x1, float y1, float x2, float y2, float anchor_x = 0, float anchor_y = 0) {
        PropGroup::init(x1, y1, x2, y2, anchor_x, anchor_y);
        this.x2 = x2;
        this.w = x2 - x1;
        this.anchor_x = x2;
        this.anchor_y = y1 + (y2 - y1) / 2.0;
        this.initial_anchor_x = this.anchor_x;
    }

    void update_length(float len) {
        this.len = len;
        this.anchor_x = this.initial_anchor_x - len + 60;
    }

    void update_offset_x(float x) {
        this.offset_x = x;
        if (rot == 0) {
            for (uint i=0; i<props.size(); ++i) {
                if (props[i].p !is null) {
                    if (props[i].initial_x < x2 - len) {
                        props[i].p.x(props[i].initial_x);
                    } else {
                        props[i].p.x(props[i].initial_x - (w - len) + x);
                    }
                }
            }
        } else {
            set_rotation(rot);
        }
    }

    void update_offset_y(float y) {
        PropGroup::update_offset_y(y);
        for (uint i=0; i<props.size(); ++i) {
            if (props[i].p !is null and props[i].initial_x < x2 - len) {
                props[i].p.y(props[i].initial_y);
            }
        }
    }

    void set_rotation(float rot) {
        this.rot = rot;
        for (uint i=0; i<props.size(); ++i) {
            if (props[i].p !is null) {
                if (props[i].initial_x < x2 - len) {
                    props[i].p.x(props[i].initial_x);
                    props[i].p.y(props[i].initial_y);
                    props[i].p.rotation(props[i].initial_rot);
                } else {
                    float rot_x, rot_y;
                    rotate(props[i].initial_x - anchor_x, props[i].initial_y - anchor_y, PI / 180 * rot, rot_x, rot_y);
                    float off_x, off_y;
                    rotate(-(w - len), 0, PI / 180 * rot, off_x, off_y);
                    props[i].p.x(anchor_x + rot_x + offset_x - (w - len));
                    props[i].p.y(anchor_y + rot_y + offset_y);
                    props[i].p.rotation(props[i].initial_rot + rot);
                }
            }
        }
    }
}

class Place {
    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;


}

class EatTrigger : trigger_base {
    script@ s;
    scripttrigger@ self;
    scene@ g;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @this.self = @self;
        @g = get_scene();
    }

    void activate(controllable@ c) {
        if (c.player_index() != -1) {
            if (s.state == State::Idle) {
                s.open_mouth();
                s.state = State::EatPlayer;
                g.play_script_stream("splat", 0, 0, 0, false, 1.0);
            }
        }
    }
}

class MoveTrigger : trigger_base {
    [text] int index = 0;

    script@ s;
    scripttrigger@ self;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @this.self = @self;
    }

    void activate(controllable@ c) {
        if (c.player_index() != -1) {
            if (s.place_index != index) {
                s.move(index);
            }
        }
    }
}
