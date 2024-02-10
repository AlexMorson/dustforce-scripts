#include "lib/std.cpp"

class script : callback_base {
    scene@ g;
    controllable@ p;
    dustman@ dm;

    script() {
        @g = @get_scene();
    }

    void on_level_start() {
        @p = @controller_controllable(0);
        if (p is null) return;
        @dm = p.as_dustman();
        if (dm is null) return;
        dm.on_subframe_end_callback(this, "on_subframe_end", 0);
    }

    void checkpoint_load() {
        @p = @controller_controllable(0);
        if (p is null) return;
        @dm = p.as_dustman();
        if (dm is null) return;
        dm.on_subframe_end_callback(this, "on_subframe_end", 0);
    }

    void on_subframe_end(dustman@ dm, int) {
        // skip crouch_jump
        if (dm.state() == 10) dm.state(8);
        // skip wall dash
        if (dm.state() == 34)
        {
            dm.state(9);
            dm.face(-dm.face());
        }

        if (dm.attack_timer() > 0) {
            hitbox@ h = dm.hitbox();
            if (h !is null) { // light or heavy attacks
                h.state_timer(h.activate_time());
            } else { // super
            }
            dm.freeze_frame_timer(0);
        }

        if (dm.attack_timer() < 0 and dm.attack_timer() != -1) {
            dm.attack_timer(0);
        }
    }
}
