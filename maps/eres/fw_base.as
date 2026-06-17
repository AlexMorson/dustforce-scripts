#include "lib/math/math.cpp"

class wall_base {
    [position,mode:world,layer:19,y:y1] float x1;
    [position,mode:world,layer:19,y:y2] float x2;
    [hidden] float y1;
    [hidden] float y2;

    int tx1, ty1, tx2, ty2;

    float perp_x, perp_y;

    uint colour = 0x000000;
    int length = 0;
    bool valid = false;

    bool disabled = false;
    bool murderer = false;

    void init(script@ s) {
        tx1 = round(x1 / 48);
        ty1 = round(y1 / 48);
        tx2 = round(x2 / 48);
        ty2 = round(y2 / 48);

        if (tx2-tx1 == 0) {
            length = abs(ty2-ty1);
        } else {
            length = abs(tx2-tx1);
        }

        x1 = 48 * tx1;
        y1 = 48 * ty1;
        x2 = 48 * tx2;
        y2 = 48 * ty2;

        // Compute a unit length perpendicular vector
        float unit_x, unit_y;
        normalize(x2-x1, y2-y1, unit_x, unit_y);
        perp_x =  unit_y;
        perp_y = -unit_x;

        // Is the wall at a multiple of 45 degrees?
        valid = x2-x1==0 or y2-y1==0 or abs(x2-x1)==abs(y2-y1);
    }

    void draw(scene@ g, int frame, bool player_dead) {
        if (!valid or (player_dead and not murderer))
            return;

        // Draw main line
        uint opacity, layer;
        if (disabled) {
            opacity = 0x55000000;
            layer = 17;
        } else {
            opacity = 0xFF000000;
            layer = 20;
        }

        g.draw_line_world(layer, 0, x1, y1, x2, y2, 15, opacity + colour);

        // Draw black detail (but not in the editor)
        if (frame >= 0) {
            int grainy = (3.5 * round(frame / 3.5)) % 20;
            int offset = 5 - abs(10 - grainy);

            g.draw_line_world(
                layer, 0,
                x1+offset*perp_x, y1+offset*perp_y,
                x2+offset*perp_x, y2+offset*perp_y,
                3, opacity
            );
        }
    }

    void editor_draw(scene@ g, int index, canvas@ c, textfield@ t) {
        init(null);
        if (valid)
            draw(g, -1, false);
        else
            g.draw_line_world(19, 0, x1, y1, x2, y2, 15, 0xFF000000 + rand()%0xFFFFFF);

        // Draw my number
        t.text(formatInt(index));
        c.draw_text(t, (x1+x2)/2, (y1+y2)/2, 1, 1, 0);
    }
}
