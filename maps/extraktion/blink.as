#include "fog.as"

class script
{
    [text] int count = 5;
    [text] int interval = 60;
    [text] float fade_time = 0.5;
    [entity] int trigger_id;

    [color] uint on_colour = 0xFFE9E9;
    [color] uint off_colour = 0xDC9A9F;

    [hidden] int frame = 0;
    [hidden] array<int> on;

    camera@ c;
    fog_setting@ fog;

    script()
    {
        @c = get_camera(0);
    }

    void on_level_start()
    {
        for (int i = 0; i < count; ++i)
            on.insertLast(i);

        entity@ trigger = entity_by_id(trigger_id);
	float fog_speed;
	int trigger_size;
	get_fog_setting(trigger, fog, fog_speed, trigger_size);
    }

    void step(int)
    {
        if (++frame % interval > 0)
            return;

        if (frame == interval)
        {
            entity@ trigger = entity_by_id(trigger_id);
            trigger.x(trigger.x() + 1000);
        }

        on.insertLast(rand() % 25);
        on.removeAt(0);

        array<bool> state(25, false);
        for (uint i = 0; i < on.size(); ++i)
            state[on[i]] = true;

        for (uint i = 0; i < state.size(); ++i)
            fog.colour(15, i, state[i] ? on_colour : off_colour);
        c.change_fog(fog, fade_time);
    }
}
