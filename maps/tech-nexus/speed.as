#include "lib/math/math.cpp"

class script {}

class Speed : trigger_base
{
    scene@ g;
    script@ s;
    scripttrigger@ self;

    [text] float x;
    [text] float y;

    void init(script@ s, scripttrigger@ self) {
        @g = get_scene();
        @this.s = @s;
        @this.self = @self;
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1)
        {
            if (c.state() == 9 and sign(c.x_speed()) == sign(x))
            {
                c.set_speed_xy(x, y);
            }
        }
    }

    void editor_draw(float sub_frame)
    {
        draw(sub_frame);
    }

    void draw(float)
    {
        g.draw_rectangle_world(
            17, 0,
            self.x() - self.radius(), self.y() - self.radius(),
            self.x() + self.radius(), self.y() + self.radius(),
            0, 0x44FFFF00
        );
    }
}
