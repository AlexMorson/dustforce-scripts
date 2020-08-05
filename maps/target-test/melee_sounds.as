const string EMBED_music = "target_test.ogg";
const string EMBED_ready = "ready_go.ogg";
const string EMBED_complete = "complete.ogg";

class script {

    [text] float music_volume = 1.0;
    [text] float announcer_volume = 1.0;

    scene@ g;
    audio@ music;

    script() {
        @g = get_scene();
    }

    void build_sounds(message@ msg) {
        msg.set_string("music", "music");
        msg.set_int("music|loop", 125218);

        msg.set_string("ready", "ready");
        msg.set_string("complete", "complete");
    }

    void on_level_start() {
        @music = @g.play_script_stream("music", 1, 0, 0, true, music_volume);
        g.play_script_stream("ready", 1, 0, 0, false, announcer_volume).time_scale(0.5);
    }

    void on_level_end() {
        music.stop();
        g.play_script_stream("complete", 1, 0, 0, false, announcer_volume).time_scale(0.5);
    }
}
