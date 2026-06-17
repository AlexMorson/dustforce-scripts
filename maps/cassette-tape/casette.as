#include "lib/std.cpp"


const string EMBED_casette = "casette_clicks.ogg";

const int FRAMES_PER_BEAT = 20;
const int FRAMES_PER_CYCLE = FRAMES_PER_BEAT * 4;

const int TICK_ACTIVE_LAYER = 20;
const int TOCK_ACTIVE_LAYER = 19;

const int TICK_INACTIVE_LAYER = 17;
const int TOCK_INACTIVE_LAYER = 16;

const int CONSTANT_LAYER = 15; // Always solid


class script
{
    [text] bool fixup;

    scene@ g;
    controllable@ p;

    int timer = FRAMES_PER_CYCLE;
    bool tick = true;

    float respawn_x = 0;
    float respawn_y = 0;
    int respawn_face = 1;
    int respawn_state = 0;
    int respawn_timer = 0;

    script()
    {
        @g = get_scene();

        g.layer_visible(TICK_ACTIVE_LAYER, true);
        g.layer_visible(TICK_INACTIVE_LAYER, true);
        g.layer_visible(TOCK_ACTIVE_LAYER, true);
        g.layer_visible(TOCK_INACTIVE_LAYER, true);

        g.reset_layer_order();

        // Move layer 13 above layer 20
        g.swap_layer_order(19, 20);
        g.swap_layer_order(18, 19);
        g.swap_layer_order(17, 18);
        g.swap_layer_order(16, 17);
        g.swap_layer_order(15, 16);
        g.swap_layer_order(14, 15);
        g.swap_layer_order(13, 14);

        // Move layer 15 above layer 20 (but not layer 13)
        g.swap_layer_order(19, 20);
        g.swap_layer_order(18, 19);
        g.swap_layer_order(17, 18);
        g.swap_layer_order(16, 17);
        g.swap_layer_order(15, 16);
    }

    void build_sounds(message@ msg)
    {
        msg.set_string("casette", "casette");
        msg.set_int("casette|loop", 55164);
    }

    void on_level_start()
    {
        @p = controller_controllable(0);
        g.play_script_stream("casette", 0, 0, 0, true, 1.0);
        
        update_layers();
    }

    void die()
    {
        if (respawn_state > 0)
            return;

        if (respawn_x == 0 and respawn_y == 0)
        {
            g.load_checkpoint();
            return;
        }

        g.combo_break_count(g.combo_break_count() + 1);
        respawn_state = 1;
        respawn_timer = 30;
    }

    void step(int entities)
    {
        if (--timer <= 0)
        {
            tick = not tick;
            timer = FRAMES_PER_CYCLE;

            update_layers();
        }

        switch (respawn_state)
        {
            case 1: // Fade out
                p.set_speed_xy(0, 0);
                if (--respawn_timer <= 0)
                {
                    respawn_timer = 30;
                    respawn_state = 2;
                    p.x(respawn_x);
                    p.y(respawn_y);
                    p.face(respawn_face);
                    p.set_speed_xy(0, 0);
                    reset_camera(0);
                }
                break;
            case 2: // Fade in
                if (--respawn_timer <= 0)
                    respawn_state = 0;
                break;

        }
    }

    void draw(float sub_frame)
    {
        if (respawn_state == 0)
            return;

        const float l = 1700;

        float offset;
        if (respawn_state == 1)
            offset = (30 - respawn_timer + sub_frame) * 1700.0 / 30 - 1700 - 450;
        else if (respawn_state == 2)
            offset = (30 - respawn_timer + sub_frame) * 1700.0 / 30 - 450;

        const uint colour = 0xFF << 24;
        g.draw_quad_hud(10, 0, false, -l, offset - l, 0, offset, 0, offset + l, -l, offset, colour, colour, colour, colour);
        g.draw_quad_hud(10, 0, false,  l, offset - l, 0, offset, 0, offset + l,  l, offset, colour, colour, colour, colour);
    }

    void editor_step()
    {
        if (not fixup) return;

        float mx = g.mouse_x_world(0, 19);
        float my = g.mouse_y_world(0, 19);
        int mtx = int(round(mx / 48));
        int mty = int(round(my / 48));

        for (int tx = mtx - 5; tx < mtx + 5; ++tx)
        {
            for (int ty = mty - 5; ty < mty + 5; ++ty)
            {
                tileinfo@ constant = g.get_tile(tx, ty, CONSTANT_LAYER);
                if (constant.solid())
                {
                    g.set_tile(tx, ty, TICK_ACTIVE_LAYER, true, constant.type(), 2, 10, 1);
                    g.set_tile(tx, ty, TOCK_ACTIVE_LAYER, true, constant.type(), 2, 10, 1);
                    continue;
                }

                bool tick_solid = g.get_tile(tx, ty, TICK_ACTIVE_LAYER).solid();
                g.set_tile(tx, ty, TICK_ACTIVE_LAYER, tick_solid, 0, 4, 6, 1);
                g.set_tile(tx, ty, TICK_INACTIVE_LAYER, tick_solid, 0, 4, 6, 1);

                bool tock_solid = g.get_tile(tx, ty, TOCK_ACTIVE_LAYER).solid();
                g.set_tile(tx, ty, TOCK_ACTIVE_LAYER, tock_solid, 0, 4, 6, 1);
                g.set_tile(tx, ty, TOCK_INACTIVE_LAYER, tock_solid, 0, 4, 6, 1);
            }
        }

        /*
        int n = g.get_prop_collision(my - 100, my + 100, mx - 100, mx + 100);
        for (int i = 0; i < n; ++i)
        {
            prop@ p = g.get_prop_collision_index(i);
            if (p.prop_set() == 1 and p.prop_group() == 11 and p.prop_index() == 4)
            {
                const int spacing = 8;
                const int x_offset = 3;
                const int y_offset = 3;
                p.x(spacing * floor((p.x() - x_offset) / spacing) + x_offset);
                p.y(spacing * floor((p.y() - y_offset) / spacing) + y_offset);
            }
        }
        */
    }

    private void update_layers()
    {
        g.layer_visible(TICK_ACTIVE_LAYER, tick);
        g.layer_visible(TICK_INACTIVE_LAYER, not tick);
        g.layer_visible(TOCK_ACTIVE_LAYER, not tick);
        g.layer_visible(TOCK_INACTIVE_LAYER, tick);
        g.default_collision_layer(tick ? TICK_ACTIVE_LAYER : TOCK_ACTIVE_LAYER);
    }
}


class Checkpoint : trigger_base
{
    script@ s;
    scripttrigger@ self;

    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;
    [text] bool right;

    void init(script@ s, scripttrigger@ self)
    {
        @this.s = s;
        @this.self = self;
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1) {
            s.respawn_x = x;
            s.respawn_y = y;
            s.respawn_face = right ? 1 : -1;
        }
    }
}

class Deathzone : trigger_base
{
    script@ s;
    scripttrigger@ self;

    void init(script@ s, scripttrigger@ self)
    {
        @this.s = s;
        @this.self = self;
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1) {
            s.die();
        }
    }
}
