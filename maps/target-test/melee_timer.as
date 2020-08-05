#include "lib/std.cpp"

class script {
    dustman@ d;

    textfield@ mil_text;
    textfield@ sec_text;
    textfield@ min_text;
    textfield@ sep;

    textfield@ combo_text;
    textfield@ combo_count_text;
    textfield@ combo_break_text;

    bool end = false;
    int fade_timer = 120;
    int frame = -54;
    bool has_combo = false;
    float break_x, break_y, break_r;
    float break_vx, break_vy, break_vr;
    float break_scale;
    int combo_timer = 300;

    script() {
        @mil_text = @create_textfield();
        @sec_text = @create_textfield();
        @min_text = @create_textfield();
        mil_text.set_font("Caracteres", 52);
        sec_text.set_font("Caracteres", 72);
        min_text.set_font("Caracteres", 72);
        mil_text.align_horizontal(-1);
        sec_text.align_horizontal(-1);
        min_text.align_horizontal(1);
        mil_text.align_vertical(1);
        sec_text.align_vertical(1);
        min_text.align_vertical(1);

        @sep = @create_textfield();
        sep.set_font("Caracteres", 72);
        sep.text(":");

        @combo_text = @create_textfield();
        @combo_count_text = @create_textfield();
        @combo_break_text = @create_textfield();
        combo_text.set_font("Caracteres", 36);
        combo_count_text.set_font("Caracteres", 72);
        combo_break_text.set_font("Caracteres", 72);
        combo_text.text("COMBO");
        combo_count_text.text("0");

        scene@ g = @get_scene();
        g.disable_score_overlay(true);
    }

    void on_level_start() {
        @d = @controller_controllable(0).as_dustman();
    }

    void checkpoint_load() {
        @d = @controller_controllable(0).as_dustman();
        if (not end) {
            frame -= 5;
            break_y = 1000;
            combo_timer = 300;
            combo_count_text.text("0");
        }
    }

    void on_level_end() {
        end = true;
        combo_timer = 300;
    }

    float t = 0;
    void step(int) {

        // Animate break timer
        if (break_y < 1000) {
            break_vy += 0.3;
            break_x += break_vx;
            break_y += break_vy;
            break_r += break_vr;
        }

        if (d.combo_count() > 0) {
            if (not end) combo_timer = int(round(300 * d.combo_timer()));

            // Set combo count text
            combo_count_text.text(formatInt(d.combo_count()));
            if (not has_combo) has_combo = true;
        } else if (has_combo and not end) {
            // Handle combo breaks
            has_combo = false;
            break_x = -650;
            break_y = 380;
            break_r = 0;
            break_vx = (int(rand()) % 100) / 50.0;
            break_vy = -8;
            break_vr = (int(rand()) % 200 - 100) / 25.0;
            break_scale = combo_text_scale();
            combo_break_text.text(combo_count_text.text());
            combo_count_text.text("");
            combo_timer = 0;
        }

        if (end) {
            if (fade_timer > 0) --fade_timer;
            return;
        }

        if (not d.dead()) ++frame;

        int timer = max(0, int(round(frame * 1000.0 / 60.0)));

        int mins = floor(timer / 1000 / 60.0);
        int secs = timer / 1000 % 60;
        int mils = (timer / 10) % 100;

        mil_text.text(formatInt(mils, "0", 2));
        sec_text.text(formatInt(secs, "0", 2));
        min_text.text(formatInt(mins));
    }

    float combo_text_scale() {
        return max(0, combo_timer - 100) / 400.0 + 0.5;
    }

    void draw(float subframe) {
        draw_text(mil_text, 60, -320);
        draw_text(sec_text, -30, -320);
        draw_text(min_text, -56, -320);
        draw_text(sep, -43, -355);
        draw_text(combo_text, -700, 320, -15);
        float scale = combo_text_scale();
        if (combo_timer > 100 or (combo_timer / 5) % 2 == 0) draw_text(combo_count_text, -650, 380, 0, scale, scale);
        draw_text(combo_break_text, break_x, break_y, break_r, break_scale, break_scale);
    }

    void draw_text(textfield@ t, float x, float y, float r = 0.0, float sx = 1.0, float sy = 1.0) {
        int opacity = min(0xCC, max(0, int(0xCC * ((fade_timer) / 60.0))));
        t.colour(opacity << 24);
        t.draw_hud(0, 0, x+3, y+3, sx, sy, r % 360);
        t.draw_hud(1, 0, x, y, sx, sy, r % 360);
    }
}
