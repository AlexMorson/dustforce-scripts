#include "lib/std.cpp"
#include "clone2.as"
#include "moving_platform.as"

const string EMBED_rocks = "rocks.ogg";
const string EMBED_switch = "switch.ogg";

class script : callback_base {

    scene@ g;
    controllable@ p;
    clone@ c;

    [text] bool reset_everything = false;
    [hidden] bool prev_reset = false;

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
    }

    void on_level_start() {
        @p = controller_controllable(0);
        @c = @clone(g, p);
        c.visible = false;

        button.init(p, c, apples);
        rocks.init();
        apples.reset();

        p.as_dustman().on_subframe_end_callback(this, "subframe_end_callback", 0);
    }

    void checkpoint_load() {
        @p = controller_controllable(0);
        @c = @clone(g, p);
        c.visible = false;

        button.init(p, c, apples);
        rocks.init();
        apples.reset();

        p.as_dustman().on_subframe_end_callback(this, "subframe_end_callback", 0);
    }

    void step(int entities) {
        apples.step(entities);
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
            button.reset();
            rocks.reset();
        }

        button.editor_step();
        rocks.editor_step();
    }

    void editor_draw(float subframe) {
        button.editor_draw(subframe);
        rocks.editor_draw(subframe);
    }

    void pre_draw(float subframe) {
        button.pre_draw(subframe);
    }

    void draw(float subframe) {
        if (@c !is null) c.draw(subframe);
    }

    void subframe_end_callback(dustman@, int) {
        button.subframe_end_callback();
    }
}

class Rocks : callback_base {
    [position,mode:world,layer:19,y:blocks_top] float blocks_left;
    [hidden] float blocks_top;
    [position,mode:world,layer:19,y:blocks_bottom] float blocks_right;
    [hidden] float blocks_bottom;

    [text] int shake_strength = 10;
    [text] array<Layer> layers;

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
    entity@ emitter;
    camera@ c;

    Rocks() {
        @g = @get_scene();
        @c = get_camera(0);

        add_broadcast_receiver("button_pressed", this, "trigger");
    }

    void reset() {
        unlocked = false;
        unlock_timer = 0;
        rocks_volume = 1;
    }

    void init() {
        if (@rocks !is null and not unlocked and unlock_timer == 0) {
            rocks.stop();
            @rocks = null;
        }
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
                for (uint i=0; i<layers.size(); ++i) {
                    int layer = layers[i].layer;
                    g.set_tile(tile_left + tx, tile_top + ty, layer, false, 0, 2, 3, 0);
                }
            }

            c.add_screen_shake(48*tx, 48*ty, rand()%360, shake_strength);

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

class IdFrames {
    int id;
    int frames;
}

entity@ create_emitter(const int id, const float x, const float y, const int width, const int height, const int layer, const int sub_layer, const int rotation=0) {
    entity@ emitter = create_entity("entity_emitter");
    varstruct@ vars = emitter.vars();
    emitter.layer(layer);
    vars.get_var("emitter_id").set_int32(id);
    vars.get_var("width").set_int32(width);
    vars.get_var("height").set_int32(height);
    vars.get_var("draw_depth_sub").set_int32(sub_layer);
    vars.get_var("r_area").set_bool(true);
    vars.get_var("e_rotation").set_int32(rotation);
    emitter.set_xy(x, y);
    
    return emitter;
}

void outline_rect(scene@ g, uint layer, uint sub_layer, float x1, float y1, float x2, float y2, float thickness=2, uint colour=0xFFFFFFFF) {
    // Top
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y1 - thickness,
        x2 + thickness, y1 + thickness,
        0, colour);
    // Bottom
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y2 - thickness,
        x2 + thickness, y2 + thickness,
        0, colour);
    // Left
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y1 - thickness,
        x1 + thickness, y2 + thickness,
        0, colour);
    // Right
    g.draw_rectangle_world(layer, sub_layer,
        x2 - thickness, y1 - thickness,
        x2 + thickness, y2 + thickness,
        0, colour);
}

class Layer {
    [text] int layer;
}
