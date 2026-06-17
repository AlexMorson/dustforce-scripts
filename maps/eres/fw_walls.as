#include "fw_base.as"

class script {
    [text] array<wall> walls;
    array<tile> tiles;

    scene@ g;
    dustman@ player;

    int frame = 0;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        @player = controller_controllable(0).as_dustman();

        for (int i=0; i<walls.size(); ++i) {
            walls[i].init(this);
        }
    }

    void checkpoint_load() {
        @player = controller_controllable(0).as_dustman();
    }

    tile@ add_tile(int x, int y) {
        // See if we already track this tile
        for (int i=0; i<tiles.size(); ++i) {
            if (tiles[i].x == x && tiles[i].y == y) {
                // Return the handle to the existing tile object
                return @tiles[i];
            }
        }
        // We don't, so create a new object and return a handle to it
        tile new_tile;
        new_tile.x = x;
        new_tile.y = y;
        tiles.insertLast(new_tile);
        return @tiles[tiles.size()-1];
    }

    void step(int entities) {
        ++frame;

        if (player !is null) {
            float x = player.x();
            float y = player.y() - 48;

            for (int i=0; i<walls.size(); ++i) {
                walls[i].update(x, y);
            }

            for (int i=0; i<tiles.size(); ++i) {
                tiles[i].update(g);
            }
        }
    }

    void editor_draw(float sub_frame) {
        canvas@ c = create_canvas(false, 20, 1);
        textfield@ t = create_textfield();
        for (int i=0; i<walls.size(); ++i) {
            walls[i].editor_draw(g, i, c, t);
        }
    }

    void draw(float sub_frame) {
        for (int i=0; i<walls.size(); ++i) {
            walls[i].draw(g, frame, player.dead());
        }
    }
}

class tile {
    int x, y;
    bool t, r, b, l;
    bool tr, br, bl, tl;

    tile() {}

    void update(scene@ g) {
        int tile_type = 0;
        if ((t?1:0) + (r?1:0) + (b?1:0) + (l?1:0) < 2) {
            if (tr and not (t or r)) {
                tile_type = 17;
            } else if (br and not (b or r)) {
                tile_type = 18;
            } else if (bl and not (b or l)) {
                tile_type = 19;
            } else if (tl and not (t or l)) {
                tile_type = 20;
            }
        }

        bool top = t or tr or tl;
        bool right = r;
        bool bottom = b or bl or br;
        bool left = l;

        tileinfo@ tile;
        @tile = create_tileinfo();

        // Make the tile invisible
        tile.sprite_tile(0);

        // Set the shape
        tile.type(tile_type);

        // Set the borders
        tile.edge_top(top ? 15 : 0);
        tile.edge_right(right ? 15 : 0);
        tile.edge_bottom(bottom ? 15: 0);
        tile.edge_left(left ? 15: 0);

        g.set_tile(x, y, 19, tile, false);

        // Eliminate dust-spread
        g.set_tile_filth(x, y, 0, 0, 0, 0, false, true);
    }
}

enum WallType {
    None = -1,
    Horizontal = 0,
    Vertical = 1,
    NegativeGradient = 2,
    PositiveGradient = 3
}

class wall : wall_base {
    array<tile@> tiles;

    WallType angle = WallType::None;

    void init(script@ s) {
        colour = 0xFFFF00;

        wall_base::init(s);

        // If we are not in the editor
        if (@s !is null) {
            // Ensure p1 is always to the left of p2 or if equal, that p1 is above p2
            if (tx1 > tx2 or (tx1 == tx2 and ty1 > ty2)) {
                int tx = tx2;
                tx2 = tx1;
                tx1 = tx;

                float x = x2;
                x2 = x1;
                x1 = x;

                int ty = ty2;
                ty2 = ty1;
                ty1 = ty;

                float y = y2;
                y2 = y1;
                y1 = y;
            }

            // Determine which of the 4 angles this wall is at
            if (ty2-ty1 == 0) { 
                angle = WallType::Horizontal;
            } else if (tx2-tx1 == 0) {
                angle = WallType::Vertical;
            } else if (tx2-tx1 == ty1-ty2) {
                angle = WallType::PositiveGradient;
            } else if (tx2-tx1 == ty2-ty1){
                angle = WallType::NegativeGradient;
            }

            for (int i=0; i<length; ++i) {
                switch (angle) {
                    case WallType::Horizontal:
                        tiles.insertLast(@s.add_tile(tx1 + i, ty1    ));
                        tiles.insertLast(@s.add_tile(tx1 + i, ty1 - 1));
                        break;
                    case WallType::Vertical:
                        tiles.insertLast(@s.add_tile(tx1    , ty1 + i));
                        tiles.insertLast(@s.add_tile(tx1 - 1, ty1 + i));
                        break;
                    case WallType::PositiveGradient:
                        tiles.insertLast(@s.add_tile(tx1 + i, ty1 - i - 1));
                        break;
                    case WallType::NegativeGradient:
                        tiles.insertLast(@s.add_tile(tx1 + i, ty1 + i));
                        break;
                }
            }
        }
    }

    void update(float player_x, float player_y) {
        bool left = orientation(x1, y1, x2, y2, player_x, player_y) < 0;

        for (int i=0; i<length; ++i) {
            switch (angle) {
                case WallType::Horizontal:
                    tiles[2*i  ].t = left;
                    tiles[2*i+1].b = !left;
                    break;
                case WallType::Vertical:
                    tiles[2*i  ].l = !left;
                    tiles[2*i+1].r = left;
                    break;
                case WallType::PositiveGradient:
                    tiles[i].tl = left;
                    tiles[i].br = !left;
                    break;
                case WallType::NegativeGradient:
                    tiles[i].tr = left;
                    tiles[i].bl = !left;
                    break;
            }
        }
    }
}
