class script {
    [text] int delay = 600;

    int wobble = 0;
    int frame = 0;

    camera@ c;

    script() {
        @c = get_camera(0);
    }

    void step(int) {
        if (wobble > 0) {
            frame += 1;
            wobble -= 1;

            float t = (pow(1.3, (wobble - 100) / 20.0) - 1.0) / 50.0;

            c.rotation(90.0 * t * sin(frame / 30.0));
            c.scale_x(1 + t / 2.0 * sin(frame / 17.134));
            c.scale_y(1 + t / 3.0 * sin(frame / 19.471));
        }
    }
}

class Wobble : trigger_base {

    script@ s;
    scripttrigger@ self;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @this.self = @self;
    }

    void activate(controllable@ c) {
        if (c.player_index() != -1) {
            if (s.wobble < s.delay) {
                s.wobble += 2;
            }
        }
    }
}
