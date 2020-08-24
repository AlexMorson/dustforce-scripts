const float HUD_WIDTH = 1600.0;
const float HUD_HEIGHT = 900.0;
const float HUD_WIDTH_HALF = HUD_WIDTH / 2.0;
const float HUD_HEIGHT_HALF = HUD_HEIGHT / 2.0;

mixin class HudScale {
    scene@ g;
    float hud_scale;

    void update_hud_scale() {
        if (g is null) @g = get_scene();
        hud_scale = HUD_WIDTH / g.hud_screen_width(false);
    }
}
