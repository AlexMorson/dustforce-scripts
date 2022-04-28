#include "lib/props/common.cpp"


class script {
    sprites@ spr;
    bool up_held = false;

    Cutscene cutscene;
    controllable@ p;

    [text|tooltip:"For when you save at a bad time..."] bool reset = false;
    [hidden] array<int> triggers;

    script()
    {
        @spr = create_sprites();
        spr.add_sprite_set("props4");
    }
    
    void on_level_start()
    {
        @p = controller_controllable(0);
    }

    void checkpoint_load()
    {
        @p = controller_controllable(0);
    }

    void teleport(float src_x, float src_y, float dst_x, float dst_y)
    {
        cutscene.start(src_x, src_y, dst_x, dst_y);
        up_held = true;
    }

    void editor_step()
    {
        if (reset)
        {
            reset = false;
            editor_sync_vars_menu();
            triggers.resize(0);
        }
    }

    void step(int)
    {
        cutscene.step();
    }

    void draw(float sub_frame)
    {
        cutscene.draw(sub_frame);
    }

    void step_post(int)
    {
        if (p is null) return;

        if (p.y_intent() != -1) up_held = false;
    }

    void add(scripttrigger@ t)
    {
        if (not is_playing()) return;

        if (triggers.find(t.id()) < 0)
        {
            cast<Telepad>(t.get_object()).setup();
        }
        triggers.insertLast(t.id());
    }
}


class Cutscene
{
    scene@ g;

    int frame = 0;
    int state = 0;

    controllable@ p;
    float src_x, src_y, dst_x, dst_y;

    Cutscene()
    {
        @g = get_scene();
    }

    void start(float src_x, float src_y, float dst_x, float dst_y)
    {
        if (state != 0) return;

        @p = controller_controllable(0);
        this.src_x = src_x;
        this.src_y = src_y;
        this.dst_x = dst_x;
        this.dst_y = dst_y;
        state = 1;

        p.state(0);
        p.attack_state(0);
        p.set_speed_xy(0, 0);

        scene@ g = get_scene();
        entity@ emitter = create_emitter(81, p.x(), p.y() - 48, 48, 96, 19, 2);
        g.add_entity(emitter, false);
        @emitter = create_emitter(81, p.x(), p.y() - 48, 48, 96, 19, 3);
        g.add_entity(emitter, false);
    }

    private void teleport()
    {
        camera@ c = get_camera(0);
        c.x(dst_x);
        c.y(dst_y);

        if (p is null) return;
        p.x(dst_x);
        p.y(dst_y);
        p.set_speed_xy(0, 0);
        p.attack_state(0);
    }

    private void clear_intents()
    {
        if (p is null) return;
        p.x_intent(0);
        p.y_intent(0);
        p.taunt_intent(0);
        p.heavy_intent(0);
        p.light_intent(0);
        p.fall_intent(0);
        p.jump_intent(0);
        p.dash_intent(0);
    }

    void step()
    {
        switch (state)
        {
            case 0:
                break;

            case 1:
                clear_intents();
                if (++frame == 30)
                {
                    frame = 0;
                    state = 2;
                    teleport();
                }
                break;

            case 2:
                clear_intents();
                if (++frame == 3)
                {
                    frame = 0;
                    state = 3;
                    reset_camera(0);
                }
                break;

            case 3:
                if (++frame == 20)
                {
                    frame = 0;
                    state = 0;
                }
                break;
        }
    }

    void draw(float sub_frame)
    {
        if (state == 0) return;

        float frac;
        int opacity;

        switch (state)
        {
            case 0:
                break;

            case 1:
                frac = (frame + sub_frame) / 30;
                opacity = int(floor(0xFF * frac));
                g.draw_rectangle_hud(12, 0, -800, -450, 800, 450, 0, opacity << 24);
                break;

            case 2:
                g.draw_rectangle_hud(12, 0, -800, -450, 800, 450, 0, 0xFF000000);
                break;

            case 3:
                frac = (frame + sub_frame) / 20;
                opacity = 0xFF - int(floor(0xFF * frac));
                g.draw_rectangle_hud(12, 0, -800, -450, 800, 450, 0, opacity << 24);
        }
    }
}


class Telepad : trigger_base
{
    [entity] int target;
    [text] string name;
    [text] string difficulty;

    scene@ g;
    script@ s;
    scripttrigger@ self;

    void init(script@ s, scripttrigger@ self) {
        @g = get_scene();
        @this.s = @s;
        @this.self = @self;

        self.radius(48);
        self.square(true);

        s.add(self);
    }

    void setup()
    {
        prop@ p = create_prop(4, 28, 12, self.x() - 200, self.y() - 219, 19, 19, 0);
        g.add_prop(p);

        string text = name;
        if (difficulty != "") text += "\nDifficulty: " + difficulty;

        entity@ e = create_text_trigger(self.x(), self.y(), 72, text);
        g.add_entity(e);
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1)
        {
            // Idle and holding up
            if (not s.up_held and c.state() == 0 and c.y_intent() == -1)
            {
                entity@ e = entity_by_id(target);
                if (e is null) return;

                s.teleport(self.x(), self.y(), e.x(), e.y());
            }
        }
    }

    void editor_step()
    {
        self.x(48 * round(self.x() / 48));
        self.y(48 * round(self.y() / 48));
    }

    void editor_draw(float)
    {
        s.spr.draw_world(19, 19, "machinery_12", 0, 0, self.x() - 200, self.y() - 219, 0, 1, 1, 0xFFFFFFFF);
    }
}


entity@ create_text_trigger(float x, float y, int radius, string text)
{
    entity@ e = create_entity("text_trigger");
    e.x(x);
    e.y(y);
    varstruct@ vars = e.vars();
    vars.get_var("width").set_int32(radius);
    vars.get_var("text_string").set_string(text);
    return e;
}

entity@ create_emitter(const int id, const float x, const float y, const int width, const int height, const int layer, const int sub_layer, const int rotation=0)
{
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
