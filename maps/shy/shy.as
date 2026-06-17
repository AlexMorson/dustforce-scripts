class script {
    dustman@ player;

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();

    }
}

class wall : trigger_base {
    script@ script;
    scene@ g;
    scripttrigger@ self;

    [text] array<block> blocks;

    wall() {
        @g = get_scene();
    }
    
    void init(script@ s, scripttrigger@ self) {
        @this.script = s;
        @this.self = self;

        for (int i=0; i<blocks.size(); ++i) {
            blocks[i].init(g, script.player);
        }
    }

    void step() {
        for (int i=0; i<blocks.size(); ++i) {
            blocks[i].step(g, script.player);
        }
    }

    //void draw(float sub_frame) {
    //    editor_draw(sub_frame);
    //}

    void editor_draw(float sub_frame) {
        for (int i=0; i<blocks.size(); ++i) {
            blocks[i].draw(g, i);
        }
    }
}

class block {
    [text] bool shy;
    [position,mode:world,layer:19,y:y1] float x1;
    [position,mode:world,layer:19,y:y2] float x2;
    [hidden] float y1;
    [hidden] float y2;

    [hidden] bool watched = false;

    int tile_x1, tile_y1, tile_x2, tile_y2;

    void init(scene@ g, dustman@ player) {
        tile_x1 = int(floor(x1 / 48));
        tile_y1 = int(floor(y1 / 48));
        tile_x2 = int(floor(x2 / 48)) + 1;
        tile_y2 = int(floor(y2 / 48)) + 1;
    }

    void step(scene@ g, dustman@ player) {
        switch (player.state()) {
            case 10: case 11: case 12: case 13: case 14: case 34: break;
            default:
            if (watched) {
                if (player.face() == 1) {
                    if (player.x()-21 > 48*tile_x2) toggle(g);
                } else {
                    if (player.x()+21 < 48*tile_x1) toggle(g);
                }
            } else {
                if (player.face() == 1) {
                    if (player.x()+21.2 < 48*tile_x1) toggle(g);
                } else {
                    if (player.x()-21.2 > 48*tile_x2) toggle(g);
                }
            }
        }
    }

    void toggle(scene@ g) {
        watched = !watched;
        if (shy) {
            if (watched) hide(g);
            else         show(g);
        } else {
            if (watched) show(g);
            else         hide(g);
        }
    }

    void show(scene@ g) {
        for (int x=tile_x1; x < tile_x2; ++x) {
            for (int y=tile_y1; y < tile_y2; ++y) {
                tileinfo@ tile = g.get_tile(x, y, 17);
                g.set_tile(x, y, 19, tile, true);
                tile.solid(false);
                g.set_tile(x, y, 17, tile, true);
            }
        }
    }

    void hide(scene@ g) {
        for (int x=tile_x1; x < tile_x2; ++x) {
            for (int y=tile_y1; y < tile_y2; ++y) {
                tileinfo@ tile = g.get_tile(x, y, 19);
                g.set_tile(x, y, 17, tile, true);
                tile.solid(false);
                g.set_tile(x, y, 19, tile, true);
            }
        }
    }

    void draw(scene@ g, int id) {
        const float tx1 = tile_x1 * 48;
        const float ty1 = tile_y1 * 48;
        const float tx2 = tile_x2 * 48;
        const float ty2 = tile_y2 * 48;

        g.draw_rectangle_world(22, 22,
            tx1, ty1, tx2, ty2,
            0, 0x44FF0000);
        outline_rect(g,
            tx1, ty1, tx2, ty2,
            22, 22, 1, 0x88FF0000);

        textfield@ text = create_textfield();
        text.text(formatInt(id));
        text.align_horizontal(-1);
        text.align_vertical(-1);
        text.draw_world(20, 0, tx1+12, ty1+12, 1, 1, 0);
    }
}

void outline_rect(scene@ g, float x1, float y1, float x2, float y2, uint layer, uint sub_layer, float thickness=2, uint colour=0xFFFFFFFF)
{
    // Top
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y1 - thickness,
        x2 + thickness, y1 + thickness,
        0, colour);
    // Bottom
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y2 - thickness,
        x2 + thickness, y2 + thickness,
        0, colour);
    // Left
    g.draw_rectangle_world(layer, sub_layer,
        x1 - thickness, y1 - thickness,
        x1 + thickness, y2 + thickness,
        0, colour);
    // Right
    g.draw_rectangle_world(layer, sub_layer,
        x2 - thickness, y1 - thickness,
        x2 + thickness, y2 + thickness,
        0, colour);
}
