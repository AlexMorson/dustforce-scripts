const array<int> dbs = {
    194, 23,
    195, 23,
    196, 23,
    197, 23,
    198, 23,
    199, 23,
    200, 23,
    201, 23,
    196, 24,
    197, 24,
    198, 24,
    199, 24
};

class script {
    scene@ g;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        swap();
    }

    void checkpoint_load() {
        swap();
    }

    void swap() {
        // Draw layer 12 in front of layer 19
        g.reset_layer_order();
        g.swap_layer_order(19, 18);
        g.swap_layer_order(18, 17);
        g.swap_layer_order(17, 16);
        g.swap_layer_order(16, 15);
        g.swap_layer_order(15, 14);
        g.swap_layer_order(14, 13);
        g.swap_layer_order(13, 12);
    }

    void step(int) {
        for (int i=0; i<dbs.size(); i+=2) {
            tileinfo@ t = g.get_tile(dbs[i], dbs[i+1], 19);
            // If the layer 19 dustblock has been collected
            if (t.solid() and t.sprite_tile() == 0) {
                // Delete the corresponding dustblock on layer 12
                g.set_tile(dbs[i], dbs[i+1], 12, false, 0, 0, 0, 0);
            }
        }
    }
}
