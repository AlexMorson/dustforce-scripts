#include "lib/std.cpp"
#include "lib/drawing/common.cpp"
#include "lib/emitters.cpp"
#include "clone2.as"
#include "custom_camera.as"
#include "moving_platform.as"

const string EMBED_rocks = "rocks.ogg";
const string EMBED_switch = "switch.ogg";
const string EMBED_clang = "clang.ogg";
const string EMBED_lift_hum = "lift_hum.ogg";

enum LiftState {
    IDLE,
    FAKE_UP,
    FAKE_DOWN,
    GOING_UP,
    GOING_DOWN
}

enum LeverState {
    LEVER_IDLE,
    LEVER_TO_UP,
    LEVER_TO_DOWN,
    LEVER_FROM_UP,
    LEVER_FROM_DOWN
}

class script : callback_base {

    scene@ g;
    controllable@ p;
    clone@ c;

    [text] bool reset_everything = false;
    [hidden] bool prev_reset = false;

    [text] Camera cam;
    [text] Lift lift;
    [text] Button button;
    [text] Rocks rocks;
    [text] Apples apples;

    bool ground_prev = false;
    float vy_prev = 0;

    script() {
        @g = @get_scene();
    }

    void build_sounds(message@ msg) {
        msg.set_string("rocks", "rocks");
        msg.set_string("switch", "switch");
        msg.set_string("clang", "clang");
        msg.set_string("lift_hum", "lift_hum");
    }

    void on_level_start() {
        g.disable_score_overlay(true);

        @p = controller_controllable(0);
        @c = @clone(g, p);
        c.visible = false;

        cam.init(p.x(), p.y() - 48);
        lift.init(p, c, apples, cam);
        button.init(p, c, apples);
        rocks.init(cam);
        apples.reset();

        p.as_dustman().on_subframe_end_callback(this, "subframe_end_callback", 0);
    }

    void checkpoint_load() {
        @p = controller_controllable(0);
        @c = @clone(g, p);
        c.visible = false;

        cam.init(p.x(), p.y() - 48);
        lift.init(p, c, apples, cam);
        button.init(p, c, apples);
        rocks.init(cam);
        apples.reset();

        p.as_dustman().on_subframe_end_callback(this, "subframe_end_callback", 0);
    }

    void move_cameras() {
        if (@p !is null) {
            if (c.visible) {
                float vy = p.y_speed();
                if (lift.inside) {
                    vy = 60 * lift.vel;
                } else if (button.inside) {
                    vy = 60 * button.vel;
                }
                cam.move_cameras(p.x() + c.offset_x, p.y() + c.offset_y - 48, p.x_speed(), vy);
            } else {
                cam.move_cameras(p.x(), p.y() - 48, p.x_speed(), p.y_speed());
            }

            if (p.ground() and not ground_prev and vy_prev >= 1500.0) {
                cam.shake_timer = max(15, cam.shake_timer);
            }
            ground_prev = p.ground();
            vy_prev = p.y_speed();
        }
    }

    void step(int entities) {
        dustman@ dm = p.as_dustman();
        if (dm !is null) dm.skill_combo(0);

        apples.step(entities);
        lift.step();
        button.step();
        rocks.step();
    }

    void step_post(int) {
        if (@c !is null) c.step_post();
    }

    void entity_on_add(entity@ e) {
        if (@c !is null) c.entity_on_add(e);
    }

    void editor_step() {
        if (prev_reset != reset_everything) {
            prev_reset = reset_everything;
            lift.reset();
            button.reset();
            rocks.reset();
        }

        lift.editor_step();
        button.editor_step();
        rocks.editor_step();
    }

    void editor_draw(float subframe) {
        lift.editor_draw(subframe);
        button.editor_draw(subframe);
        rocks.editor_draw(subframe);
    }

    void pre_draw(float subframe) {
        lift.pre_draw(subframe);
        button.pre_draw(subframe);
    }

    void draw(float subframe) {
        cam.draw(subframe);
        if (@c !is null) c.draw(subframe);
    }

    void subframe_end_callback(dustman@, int) {
        lift.subframe_end_callback();
        button.subframe_end_callback();
    }
}

class Rocks : callback_base {
    [position,mode:world,layer:19,y:blocks_top] float blocks_left;
    [hidden] float blocks_top;
    [position,mode:world,layer:19,y:blocks_bottom] float blocks_right;
    [hidden] float blocks_bottom;

    [text] int shake_strength = 20;

    [hidden] int tile_top;
    [hidden] int tile_left;
    [hidden] int tile_bottom;
    [hidden] int tile_right;

    [hidden] int tile_width;
    [hidden] int tile_height;
    [hidden] int tile_count;

    [hidden] bool unlocked = false;
    [hidden] int unlock_timer = 0;

    [hidden] float rocks_volume = 1;
    audio@ rocks;

    scene@ g;
    Camera@ cam;
    entity@ emitter;

    Rocks() {
        @g = @get_scene();

        add_broadcast_receiver("button_pressed", this, "trigger");
    }

    void reset() {
        unlocked = false;
        unlock_timer = 0;
        rocks_volume = 1;
    }

    void init(Camera@ cam) {
        if (@rocks !is null and not unlocked and unlock_timer == 0) {
            rocks.stop();
            @rocks = null;
        }
        @this.cam = @cam;
    }

    void time_to_xy(int t, int &out x, int &out y) {
        x = t / tile_height;
        y = tile_height - t % tile_height;
        if (y % 2 == 0) {
            y = y / 2 - 1;
        } else {
            y = tile_height - 1 - y / 2;
        }
    }

    void trigger(string, message@) {
        unlocked = true;
        @rocks = @g.play_script_stream("rocks", 0, blocks_left, blocks_top, true, 0);
        rocks.positional(true);
    }

    void step() {
        if (@emitter !is null) g.remove_entity(emitter);

        if (unlocked and unlock_timer < tile_count + 5) {

            int tx, ty;

            time_to_xy(unlock_timer, tx, ty);
            @emitter = @create_emitter(42, blocks_left + 48 * tx, blocks_top + 48 * ty, 48, 48, 19, 9);
            g.add_entity(emitter);

            rocks.set_position(blocks_left + 48 * tx, blocks_top + 48 * ty);
            rocks.volume(1);

            if (unlock_timer >= 5) {
                time_to_xy(unlock_timer - 5, tx, ty);
                g.set_tile(tile_left + tx, tile_top + ty, 19, false, 0, 2, 3, 0);
            }

            cam.shake_timer = max(shake_strength, cam.shake_timer);

            ++unlock_timer;
        } else if (unlocked and @rocks !is null) {
            rocks_volume = (rocks_volume * 19 + 0.0) / 20;
            if (rocks_volume < 0.01) {
                rocks.stop();
                @rocks = null;
            } else {
                rocks.volume(rocks_volume);
            }
        }
        
    }

    void editor_step() {
        tile_top    = round(blocks_top    / 48.0);
        tile_left   = round(blocks_left   / 48.0);
        tile_bottom = round(blocks_bottom / 48.0);
        tile_right  = round(blocks_right  / 48.0);

        tile_width  = tile_right  - tile_left;
        tile_height = tile_bottom - tile_top;
        tile_count = tile_width * tile_height;

        blocks_top    = 48.0 * tile_top;
        blocks_left   = 48.0 * tile_left;
        blocks_bottom = 48.0 * tile_bottom;
        blocks_right  = 48.0 * tile_right;
    }

    void editor_draw(float) {
        outline_rect(g, 22, 0, blocks_left, blocks_top, blocks_right, blocks_bottom, 1, 0xDDCB0079);
    }
}

class Button : MovingPlatform {
    [position,mode:world,layer:19,y:button_y] float button_x;
    [hidden] float button_y;

    [text] float button_height = 192;
    [text] int steps = 5;

    [position,mode:world,layer:19,y:props_y] float props_x;
    [hidden] float props_y;

    [hidden] PropGroup platform_props;

    [hidden] float target_y;
    [hidden] bool pressed = false;

    array<IdFrames@> apple_frames;

    Button() {
        super();
    }

    void reset() {
        MovingPlatform::reset();

        platform_props.reset();
        pressed = false;
    }

    void init(controllable@ p, clone@ c, Apples@ apples) {
        MovingPlatform::init(p, c, apples);

        target_y = y;
        apple_frames.resize(0);

        platform_props.init(props_x, props_y, props_x + width, props_y + button_height);
        platform_props.update_offset_x(x - props_x);
        platform_props.update_offset_y(y - props_y);
    }

    void step() {
        platform_props.step();

        if (not pressed) {
            step_apple_frames();
            check_apples();

            int weight = apple_frames.size();
            if (inside and p.ground()) weight += 1;
            target_y = button_y - height + button_height * weight / steps;
            vel = (target_y - y) / 10;

            if (weight == steps and abs(y - target_y) < 1) {
                y = target_y;
                vel = 0;
                pressed = true;
                broadcast_message("button_pressed", create_message());
                g.play_script_stream("switch", 0, 0, 0, false, 0.5).time_scale(0.5);
            }
        }

        MovingPlatform::step();
    }

    void check_apples() {
        for (int i=0; i<apples.apples.size(); ++i) {
            if (@apples.apples[i] is null) continue;

            controllable@ apple = apples.apples[i].as_controllable();
            if (@apple is null) continue;

            if (apple.x() >= x-14 and apple.x() <= x+width+14) {
                if (apple.prev_y() < y + height - 28 and apple.y() > y + height - 38 and apple.y_speed() >= 0) {
                    reset_apple_frames(apple, 30);
                }
            }
        }
    }

    void step_apple_frames() {
        for (int i=apple_frames.size()-1; i>=0; --i) {
            --apple_frames[i].frames;
            if (apple_frames[i].frames == 0) {
                apple_frames.removeAt(i);
            }
        }
    }

    void reset_apple_frames(controllable@ apple, int frames) {
        for (int i=0; i<apple_frames.size(); ++i) {
            if (apple_frames[i].id == apple.id()) {
                apple_frames[i].frames = frames;
                return;
            }
        }
        IdFrames@ f = @IdFrames();
        f.id = apple.id();
        f.frames = frames;
        apple_frames.insertLast(@f);
    }

    void pre_draw(float subframe) {
        MovingPlatform::pre_draw(subframe);

        float subframe_y = y - vel * (1 - subframe);
        platform_props.update_offset_y(subframe_y - props_y + height);
    }

    void editor_step() {
        MovingPlatform::editor_step();

        button_x = 48.0 * round(button_x / 48.0);
        button_y = 48.0 * round((button_y + button_height) / 48.0) - button_height;

        x = button_x;
        y = button_y - height;

        props_x = 48.0 * round(props_x / 48.0);
        props_y = 48.0 * round(props_y / 48.0);
    }

    void editor_draw(float subframe) {
        MovingPlatform::editor_draw(subframe);

        outline_rect(g, 22, 0, button_x, button_y, button_x + width, button_y + button_height, 1, 0xDDCB0079);
        outline_rect(g, 22, 0, props_x, props_y, props_x + width, props_y + button_height, 1, 0xDDCB0079);
    }
}

class Lift : MovingPlatform {
    [entity] int scale_over_id;
    [entity] int scale_under_id;
    [text] float volume = 0.8;
    [text] array<Floor> floors;
    [hidden] int current_floor = 0;
    [hidden] int prev_box_index = -1;

    [position,mode:world,layer:19,y:lift_props_y] float lift_props_x;
    [hidden] float lift_props_y;

    [position,mode:world,layer:19,y:lever_props_y] float lever_props_x;
    [hidden] float lever_props_y;
    [position,mode:world,layer:19,y:lever_rot_y] float lever_rot_x;
    [hidden] float lever_rot_y;
    [text] float lever_dir = 1;
    [entity] int lever_entity_id;

    [position,mode:world,layer:19,y:door_y] float door_x;
    [hidden] float door_y;
    [hidden] bool doors_open = true;

    [hidden] int state = IDLE;
    [hidden] int state_timer = 0;

    [hidden] int lever_state = LEVER_IDLE;
    [hidden] int lever_timer = 0;

    [hidden] PropGroup lift_props;
    [hidden] PropGroup lever_props;
    [hidden] Entity lever_entity;

    audio@ hum;
    bool hum_fade = false;

    Camera@ cam;

    Lift() {
        super();

        add_broadcast_receiver("lever_hit_up", this, "lever_hit_up");
        add_broadcast_receiver("lever_hit_down", this, "lever_hit_down");
    }

    void reset() {
        MovingPlatform::reset();

        current_floor = 0;
        doors_open = true;
        state = IDLE;
        state_timer = 0;
        lever_state = LEVER_IDLE;
        lever_timer = 0;
        lift_props.reset();
        lever_props.reset();
        lever_entity.reset();
    }

    void init(controllable@ p, clone@ c, Apples@ apples, Camera@ cam) {
        MovingPlatform::init(p, c, apples);

        if (@hum !is null and state != GOING_UP and state != GOING_DOWN) {
            hum.stop();
            @hum = null;
        }

        lift_props.init(lift_props_x, lift_props_y, lift_props_x + width, lift_props_y + height);
        lift_props.update_offset_x(x - lift_props_x);

        lever_props.init(lever_props_x, lever_props_y, lever_props_x + width, lever_props_y + height, lever_rot_x, lever_rot_y);
        lever_props.update_offset_x(x - lever_props_x);

        lever_entity.init(@entity_by_id(lever_entity_id));

        @this.cam = @cam;
    }

    bool player_fully_inside() {
        return inside and p.x() > box_x and p.x() < box_x + width;
    }

    void lever_hit_up(string id, message@ msg) {
        if (state == IDLE) {
            g.play_script_stream("switch", 0, 0, 0, false, volume).time_scale(0.5);
            lever_state = LEVER_TO_UP;
            lever_timer = 5;
            if (current_floor == 0 or not player_fully_inside()) {
                state = FAKE_UP;
                state_timer = 5;
            } else {
                state = GOING_UP;
                close_doors();
            }
        } else if (state == GOING_DOWN) {
            g.play_script_stream("switch", 0, 0, 0, false, volume).time_scale(0.5);
            state = GOING_UP;
            current_floor += 1;
            lever_state = LEVER_TO_UP;
            lever_timer = 10;
        }
    }

    void lever_hit_down(string id, message@ msg) {
        if (state == IDLE) {
            g.play_script_stream("switch", 0, 0, 0, false, volume).time_scale(0.5);
            lever_state = LEVER_TO_DOWN;
            lever_timer = 5;
            if (current_floor == floors.size() - 1 or not player_fully_inside()) {
                state = FAKE_DOWN;
                state_timer = 5;
            } else {
                state = GOING_DOWN;
                close_doors();
                if (current_floor == 0) {
                    activate_scale_trigger(false);
                }
            }
        } else if (state == GOING_UP) {
            g.play_script_stream("switch", 0, 0, 0, false, volume).time_scale(0.5);
            state = GOING_DOWN;
            current_floor -= 1;
            lever_state = LEVER_TO_DOWN;
            lever_timer = 10;
        }
    }

    void activate_scale_trigger(bool over) {
        entity@ scale_over = @entity_by_id(scale_over_id);
        entity@ scale_under = @entity_by_id(scale_under_id);

        if (over) {
            scale_over.x(boxes[0].x + width / 2);
            scale_over.y(boxes[0].y + height / 2);
            scale_under.x(boxes[0].x + 2000);
            scale_under.y(boxes[0].y - 1000);
        } else {
            scale_under.x(boxes[0].x + width / 2);
            scale_under.y(boxes[0].y + height / 2);
            scale_over.x(boxes[0].x + 2000);
            scale_over.y(boxes[0].y - 1000);

        }
    }

    void step() {
        MovingPlatform::step();

        lift_props.step();
        lever_props.step();

        if (@hum !is null and hum_fade) {
            hum.volume(hum.volume() - 0.02);
            if (hum.volume() <= 0.02) {
                hum_fade = false;
                hum.stop();
                @hum = null;
            }
        }

        if (prev_box_index != box_index) {
            prev_box_index = box_index;
            update_box_doors();
        }

        switch (state) {
            case IDLE:
                break;
            case FAKE_UP:
                if (--state_timer == 0) {
                    state = IDLE;
                    lever_state = LEVER_FROM_UP;
                    lever_timer = 5;
                }
                break;
            case FAKE_DOWN:
                if (--state_timer == 0) {
                    state = IDLE;
                    lever_state = LEVER_FROM_DOWN;
                    lever_timer = 5;
                }
                break;
            case GOING_UP:
                cam.shake_timer = max(cam.shake_timer, 2);
                vel = (29 * vel - 8) / 30;
                if (y > floors[current_floor].y) {
                    y = floors[current_floor].y;
                    vel = 0;
                }
                if (y <= floors[current_floor - 1].y) {
                    move_to_floor(current_floor - 1);
                }
                break;
            case GOING_DOWN:
                cam.shake_timer = max(cam.shake_timer, 2);
                vel = (29 * vel + 8) / 30;
                if (y < floors[current_floor].y) {
                    y = floors[current_floor].y;
                    vel = 0;
                }
                if (y >= floors[current_floor + 1].y) {
                    move_to_floor(current_floor + 1);
                }
                break;
        }

        lever_anim();
    }

    void lever_anim() {
        if (lever_state == LEVER_IDLE) return;

        --lever_timer;

        float t = lever_timer / 5.0;
        lever_props_anim(t);

        if (lever_timer == 0) {
            lever_state = LEVER_IDLE;
        }
    }

    void lever_props_anim(float t) {
        switch (lever_state) {
            case LEVER_TO_UP:
                lever_props.set_rotation(lever_dir * (-15 - 30 * (1 - t)));
                break;
            case LEVER_TO_DOWN:
                lever_props.set_rotation(lever_dir * (15 + 30 * (1 - t)));
                break;
            case LEVER_FROM_UP:
                lever_props.set_rotation(lever_dir * (-45 * t));
                break;
            case LEVER_FROM_DOWN:
                lever_props.set_rotation(lever_dir * (45 * t));
                break;
        }
    }

    void move_to_floor(int f, bool fx = true) {
        if (f == 0 and fx) {
            activate_scale_trigger(true);
        }

        y = floors[f].y;
        vel = 0;
        current_floor = f;
        state = IDLE;

        if (fx) {
            if (state == GOING_UP) {
                lever_state = LEVER_FROM_UP;
            } else {
                lever_state = LEVER_FROM_DOWN;
            }
            lever_timer = 5;
        }
        open_doors(fx);
    }

    void close_doors(bool fx = true) {
        if (doors_open) {
            if (fx) {
                if (@hum is null) {
                    @hum = g.play_script_stream("lift_hum", 0, 0, 0, true, volume);
                } else {
                    hum.volume(volume);
                }
                hum_fade = false;
                cam.shake_timer = max(cam.shake_timer, 10);
            }
            doors_open = false;
            int door_tx = round(door_x / 48.0);
            int door_ty = round(door_y / 48.0);
            int lift_tx = round(x / 48.0);
            for (int i=0; i<floors.size(); ++i) {
                int floor_ty = round(floors[i].y / 48.0);
                for (int ty=0; ty<tile_height; ++ty) {
                    tileinfo@ tile = g.get_tile(door_tx, door_ty + ty, 19);
                    if (floors[i].door_left ) g.set_tile(lift_tx - 1, floor_ty + ty, 19, tile, true);
                    if (floors[i].door_right) g.set_tile(lift_tx + tile_width, floor_ty + ty, 19, tile, true);
                }
            }
            update_box_doors();
        }
    }

    void open_doors(bool fx = true) {
        if (not doors_open) {
            if (@hum !is null) {
                hum_fade = true;
            }
            if (fx) {
                g.play_script_stream("clang", 0, 0, 0, false, volume).time_scale(0.5);
                cam.shake_timer = max(cam.shake_timer, 20);
            }
            doors_open = true;
            int lift_tx = round(x / 48.0);
            for (int i=0; i<floors.size(); ++i) {
                int floor_ty = round(floors[i].y / 48.0);
                for (int ty=0; ty<tile_height; ++ty) {
                    if (floors[i].door_left ) g.set_tile(lift_tx - 1, floor_ty + ty, 19, false, 0, 1, 1, 1);
                    if (floors[i].door_right) g.set_tile(lift_tx + tile_width, floor_ty + ty, 19, false, 0, 1, 1, 1);
                }
            }
            update_box_doors();
        }
    }

    void update_box_doors() {
        int box_tx = round(box_x / 48.0);
        int box_ty = round(box_y / 48.0);
        for (int ty=0; ty<tile_height; ++ty) {
            if (doors_open and floors[current_floor].door_left) {
                g.set_tile(box_tx - 1, box_ty + ty, 19, false, 0, 1, 1, 1);
            } else {
                g.set_tile(box_tx - 1, box_ty + ty, 19, true, 0, 1, 1, 1);
            }
            if (doors_open and floors[current_floor].door_right) {
                g.set_tile(box_tx + tile_width, box_ty + ty, 19, false, 0, 1, 1, 1);
            } else {
                g.set_tile(box_tx + tile_width, box_ty + ty, 19, true, 0, 1, 1, 1);
            }
        }
    }

    void pre_draw(float subframe) {
        MovingPlatform::pre_draw(subframe);

        float subframe_y = y - vel * (1 - subframe);
        if (lever_state != LEVER_IDLE) lever_props_anim((lever_timer - subframe) / 5.0);
        lift_props.update_offset_y(subframe_y - lift_props_y);
        lever_props.update_offset_y(subframe_y - lever_props_y);
        lever_entity.offset_x(x - lever_props_x);
        lever_entity.offset_y(subframe_y - lever_props_y);
    }

    void editor_step() {
        MovingPlatform::editor_step();

        for (int i=0; i<floors.size(); ++i) {
            floors[i].x = 48.0 * round(floors[i].x / 48.0);
            floors[i].y = 48.0 * round(floors[i].y / 48.0);
        }

        if (floors.size() > 0) {
            x = floors[0].x;
            y = floors[0].y;
        }

        lift_props_x = 48.0 * round(lift_props_x / 48.0);
        lift_props_y = 48.0 * round(lift_props_y / 48.0);

        lever_props_x = 48.0 * round(lever_props_x / 48.0);
        lever_props_y = 48.0 * round(lever_props_y / 48.0);

        door_x = 48.0 * round(door_x / 48.0);
        door_y = 48.0 * round(door_y / 48.0);
    }

    void editor_draw(float subframe) {
        MovingPlatform::editor_draw(subframe);

        for (int i=0; i<floors.size(); ++i) {
            outline_rect(g, 22, 0, x, floors[i].y, x + width, floors[i].y + height, 1, 0xDDCB0079);
            if (floors[i].door_left) {
                outline_rect(g, 22, 0, x - 48, floors[i].y, x, floors[i].y + height, 1, 0xDDCB0079);
            }
            if (floors[i].door_right) {
                outline_rect(g, 22, 0, x + width, floors[i].y, x + width + 48, floors[i].y + height, 1, 0xDDCB0079);
            }
        }

        outline_rect(g, 22, 0, lift_props_x, lift_props_y, lift_props_x + width, lift_props_y + height, 1, 0xDDCB0079);
        outline_rect(g, 22, 0, lever_props_x, lever_props_y, lever_props_x + width, lever_props_y + height, 1, 0xDDCB0079);
        outline_rect(g, 22, 0, door_x, door_y, door_x + 48, door_y + height, 1, 0xDDCB0079);
    }
}

class Lever : enemy_base, callback_base {

    void init(script@ s, scriptenemy@ self) {
        self.on_hurt_callback(this, "on_hurt_callback", 0);
    }

    void on_hurt_callback(
        controllable@ attacker,
        controllable@ attacked,
        hitbox@ attack_hitbox,
        int arg
    ) {
        int dir = abs(attack_hitbox.attack_dir());
        if (dir < 80) {
            hit_up();
        } else if (dir > 90) {
            hit_down();
        }
    }

    void hit_up() {
        message@ msg = create_message();
        broadcast_message("lever_hit_up", msg);
    }

    void hit_down() {
        message@ msg = create_message();
        broadcast_message("lever_hit_down", msg);
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

    bool loaded = false;

    void reset() {
        initialised = false;
        offset_x = 0;
        offset_y = 0;
        rot = 0;
    }

    void init(float x1, float y1, float x2, float y2, float anchor_x = 0, float anchor_y = 0) {
        loaded = false;
        if (initialised) {
            requery_props(true);
        } else {
            initialised = true;
            scene@ g = get_scene();
            this.anchor_x = anchor_x;
            this.anchor_y = anchor_y;
            int n = g.get_prop_collision(y1, y2, x1, x2);
            props.resize(0);
            for (int i=0; i<n; ++i) {
                prop@ p = g.get_prop_collision_index(i);
                props.insertLast(Prop(p));
            }
            update_offset_x(offset_x);
            update_offset_y(offset_y);
        }
    }

    void step() {
        if (not loaded) requery_props(false);

        // Past updates didn't change the actual props, so update them now
        if (loaded) set_rotation(rot);
    }

    void requery_props(bool force) {
        loaded = true;
        for (int i=0; i<props.size(); ++i) {
            if (force or props[i].p is null) props[i].requery_prop();
            if (props[i].p is null) loaded = false;
        }
    }

    void update_offset_x(float x) {
        this.offset_x = x;
        if (rot == 0) {
            for (int i=0; i<props.size(); ++i) {
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
            for (int i=0; i<props.size(); ++i) {
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
        for (int i=0; i<props.size(); ++i) {
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

class Entity {
    [hidden] float initial_x;
    [hidden] float initial_y;
    [hidden] bool initialised = false;

    entity@ e;

    void reset() {
        initialised = false;
    }

    void init(entity@ e) {
        if (not initialised) {
            initialised = true;
            initial_x = e.x();
            initial_y = e.y();
        }
        @this.e = @e;
    }

    void offset_x(float x) {
        e.x(initial_x + x);
    }

    void offset_y(float y) {
        e.y(initial_y + y);
    }
}

class Floor {
    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;
    [text] bool door_left;
    [text] bool door_right;
}

class IdFrames {
    int id;
    int frames;
}

class ChangeFloor : trigger_base {
    [text] int floor_index = 0;

    script@ s;
    scripttrigger@ self;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @this.self = @self;
    }
    void activate(controllable@ p) {
        if (p.player_index() != -1) {
            if (s.lift.state == IDLE and s.lift.current_floor != floor_index) {
                s.lift.move_to_floor(floor_index, false);
            }
        }
    }
}
