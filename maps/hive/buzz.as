const string EMBED_buzz = "buzz_stereo.ogg";

class script {

    [text] float volume = 1.0;

    scene@ g;

    script() {
        @g = get_scene();
    }

    void build_sounds(message@ msg) {
        msg.set_string("buzz", "buzz");
    }

    void on_level_start() {
        g.play_script_stream("buzz", 2, 0, 0, true, volume);
    }
}
