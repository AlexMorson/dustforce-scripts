const string EMBED_rumble = "dormant/rumble.ogg";
const string EMBED_kaboom = "dormant/kaboom.ogg";
const string EMBED_sizzle = "dormant/sizzle.ogg";


class Trigger
{
    [entity] int id;
    [text] bool dustmod = false;
}

class script
{
    [position, mode:world, layer:19, y:_] float start;
    [position, mode:world, layer:19, y:_] float left;
    [position, mode:world, layer:19, y:_] float right;
    [position, mode:world, layer:19, y:stun] float _;
    [position, mode:world, layer:19, y:low] float __;
    [position, mode:world, layer:19, y:water] float ___;
    [hidden] float stun;
    [hidden] float low;
    [hidden] float water;

    [text] array<Trigger> triggers;

    [position, mode:world, layer:19, y:fire_y] float fire_x;
    [hidden] float fire_y;
    entity@ fire;

    bool triggered = false;
    bool extinguished = false;

    scene@ g;
    camera@ c;
    controllable@ p;
    sprites@ spr;
    audio@ rumble;

    script()
    {
        @g = get_scene();
        @c = get_camera(0);
        @spr = create_sprites();
        spr.add_sprite_set("props1");
    }

    void build_sounds(message@ msg)
    {
        msg.set_string("rumble", "rumble");
        msg.set_string("kaboom", "kaboom");
        msg.set_int("kaboom|loop", 146721);
        msg.set_string("sizzle", "sizzle");
    }

    void on_level_start()
    {
        @p = controller_controllable(0);

        // Start the rumble sound at 0 volume
        @rumble = g.play_script_stream("rumble", 0, 0, 0, true, 0);
    }

    void checkpoint_load()
    {
        @p = controller_controllable(0);
    }

    void step(int)
    {
        // Make the rumble get louder as you near the volcano
        float f = max(0, min(1, (p.x() - start) / (left - start)));
        rumble.volume(f);

        // Erupt when jumping into the volcano, or when you are halfway over the crater
        if (not triggered and ((p.x() > left and p.y() > low) or p.x() > left + (right - left) / 2))
        {
            triggered = true;
            erupt();
        }

        if (triggered)
        {
            float vx = p.x_speed();
            float vy = p.y_speed();

            // Move the player to the right if inside the eruption, and up if below "stun"
            if (p.x() < right)
            {
                vx = max(700, vx);
                if (p.y() > stun) vy = -1500;
            }
            p.set_speed_xy(vx, vy);

            // Move the fire emitter to the player
            if (fire !is null)
            {
                fire.x(p.x());
                fire.y(p.y() - 48);
            }

            // Make the rumble softer, and extinguish the player when going below the water line
            if (p.y() > water)
            {
                rumble.volume(0.5);
                if (not extinguished)
                {
                    extinguished = true;
                    extinguish();
                }
            }
        }
    }

    void erupt()
    {
        g.play_script_stream("kaboom", 0, 0, 0, true, 1);
        c.add_screen_shake(c.x(), c.y(), 0, 150);

        // Move triggers to the player/camera so they are activated
        for (uint i=0; i<triggers.size(); ++i)
        {
            entity@ trigger = entity_by_id(triggers[i].id);
            if (triggers[i].dustmod)
            {
                trigger.x(p.x());
                trigger.y(p.y());
            }
            else
            {
                trigger.x(c.x());
                trigger.y(c.y());
            }
        }

        // Get a reference to the fire emitter
        int n = g.get_entity_collision(fire_y - 48, fire_y + 48, fire_x - 48, fire_x + 48, 13);
        if (n == 1) @fire = g.get_entity_collision_index(0);
        else puts("Could not find fire emitter.");
    }

    void extinguish()
    {
        if (fire !is null) g.remove_entity(fire);
        g.play_script_stream("sizzle", 0, 0, 0, false, 0.7);
    }

    void editor_var_changed(var_info@)
    {
        left = 48 * round(left / 48);
        right = 48 * round(right / 48);
    }

    void editor_draw(float)
    {
        g.draw_line_world(22, 0, start, -10000, start, 10000, 5, 0xFF00FFFF);
        g.draw_line_world(22, 0, left, -10000, left, 10000, 5, 0xFF00FFFF);
        g.draw_line_world(22, 0, right, -10000, right, 10000, 5, 0xFF00FFFF);
        g.draw_line_world(22, 0, left, stun, right, stun, 5, 0xFF00FFFF);
        g.draw_line_world(22, 0, left, low, right, low, 5, 0xFF00FFFF);
        g.draw_line_world(22, 0, right, water, 10000, water, 5, 0xFF00FFFF);
    }

    void draw(float)
    {
        if (not triggered) return;

        for (int i=0; i<40; ++i)
        {
            float x = rand() % (right - left) + left;
            float y = rand() % c.screen_height() + c.y() - c.screen_height() / 2;
            spr.draw_world(20, rand() % 5 + 20, "buildingblocks_3", 0, 0, x-1050, y+800, -90, 4, 4, 0xFFFFFFFF);
        }
    }
}
