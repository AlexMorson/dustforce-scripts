class script {
    script() {
        scene@ g = get_scene();
        g.reset_layer_order();
        g.swap_layer_order(17, 18);
    }
}
