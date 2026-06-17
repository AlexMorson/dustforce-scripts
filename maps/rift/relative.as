class script {}

class relative : trigger_base {
    [position,mode:world,layer:19,y:to_y] float to_x;
    [hidden] float to_y;

    [hidden] float dx;
    [hidden] float dy;

    script@ script;
    scripttrigger@ self;

    scene@ g;

    void init(script@ script, scripttrigger@ self) {
        @this.script = @script;
        @this.self = @self;

        @g = get_scene();

        dx = to_x - self.x();
        dy = to_y - self.y();

        dx = 48.0 * round(dx / 48.0);
        dy = 48.0 * round(dy / 48.0);

        puts("dx:"+formatInt(dx));
        puts("dy:"+formatInt(dy));
    }

    void editor_draw(float sub_frame) {
        g.draw_rectangle_world(20, 0, to_x-12, to_y-12, to_x+12, to_y+12, 0, 0xFF3FFFFF);
    }

    void activate(controllable@ e) {
        if (e.player_index() != -1) {
            e.x(e.x() + dx);
            e.y(e.y() + dy);

            e.prev_x(e.prev_x() + dx);
            e.prev_y(e.prev_y() + dy);

            reset_camera(0);
            //camera@ c = get_active_camera();
            //c.x(c.x() + dx);
            //c.y(c.y() + dy);

            //c.prev_x(e.prev_x() + dx);
            //c.prev_y(e.prev_y() + dy);
        }
    }
}
