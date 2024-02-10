class script {
    scene@ g;
    bool active = false;

    script() {
        @g = get_scene();
    }

    void on_level_start()
    {
        active = not (is_replay() or get_nexus_api() !is null);
    }

    void on_level_end()
    {
        active = false;
    }

    void draw(float sub_frame) {
        if (active) g.draw_rectangle_hud(999, 0, -1000, -500, 1000, 500, 0, 0xFF000000);
    }
}
