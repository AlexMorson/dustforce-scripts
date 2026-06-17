class script {
    dustman@ player;
    scene@ g;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();
    }

    void step(int entities) {
        if (@player !is null) {
            switch (player.state()) {
                case 10: case 11: case 12: case 13: case 14: case 34: break;
                default: if (player.face() != 1) kill();
            }
        }
    }

    void kill() {
        g.combo_break_count(g.combo_break_count()+1);
        player.kill(false);
    }
}
