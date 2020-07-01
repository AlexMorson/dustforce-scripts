class script {
    [text] array<glass> rectangles;

    scene@ g;

    script() {
        @g = get_scene();
    }

    void draw(float subframe) {
        for (int i=0; i<rectangles.size(); ++i) {
            rectangles[i].draw(g);
        }
    }

    void editor_draw(float subframe) {
        draw(subframe);
    }

    void editor_step() {
        for (int i=0; i<rectangles.size(); ++i) {
            rectangles[i].step();
        }
    }
}

class glass {
    [text] int layer = 17;
    [text] int sublayer = 20;
    [position,mode:world,y:y1] float x1;
    [hidden] float y1;
    [position,mode:world,y:y2] float x2;
    [hidden] float y2;

    void draw(scene@ g) {
        g.draw_glass_world(layer, sublayer, x1, y1, x2, y2, 0, 0);
    }

    void step() {
        x1 = 48.0 * round(x1 / 48.0);
        y1 = 48.0 * round(y1 / 48.0);
        x2 = 48.0 * round(x2 / 48.0);
        y2 = 48.0 * round(y2 / 48.0);
    }
}
