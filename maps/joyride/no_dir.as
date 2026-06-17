class script {
    scene@ g;
    dustman@ player;

    script() {
        @g = get_scene();
        get_active_camera().screen_height(1250);
    }

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();
    }

    void step(int entities) {
        if (player !is null) {
            player.x_intent(0);
            player.y_intent(0);
        }
    }
}
