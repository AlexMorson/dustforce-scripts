class MovingPlatform : callback_base {
    [text] int tile_width = 8;
    [text] int tile_height = 6;
    [hidden] float width;
    [hidden] float height;

    [hidden] float x;
    [hidden] float y;
    [hidden] float vel = 0;
    [hidden] float player_vel = 0;
    [hidden] bool inside = false;

    [text] array<Box> boxes;
    [hidden] int box_index = 0;
    [hidden] float box_x;
    [hidden] float box_y;

    [text] bool apple_ceiling = true;

    scene@ g;
    controllable@ p;
    clone@ c;
    Apples@ apples;

    MovingPlatform() {
        @g = get_scene();
    }

    void reset() {
        vel = 0;
        player_vel = 0;
        inside = false;
        box_index = 0;
    }

    void init(controllable@ p, clone@ c, Apples@ apples) {
        @this.p = @p;
        @this.c = @c;
        @this.apples = @apples;
    }

    void step() {
        update_box_index();

        // Check entering/leaving
        if (inside) {
            if (p.x() < box_x - 14 or p.x() > box_x + width + 14 or p.y() < box_y) {
                inside = false;
                c.visible = false;
                c.offset_x = 0;
                p.x(p.x() + x - box_x);
                p.y(p.y() + y - box_y);
            }
        } else {
            if (p.x() > x - 14 and p.x() < x + width + 14 and p.y() > y and p.y() <= y + height) {
                inside = true;
                c.visible = true;
                c.offset_x = x - box_x;
                p.x(p.x() + box_x - x);
                p.y(p.y() + box_y - y);
            }
        }

        // Player position
        if (inside) {
            player_vel = 0;
            if (not (p.roof() or p.ground())) {
                player_vel = vel;
                p.y(p.y() - vel);
            }
        }

        y += vel;

        handle_apples();
    }

    void handle_apples() {
        // TODO: Apples seem weird now...
        for (int i=0; i<apples.apples.size(); ++i) {
            if (@apples.apples[i] is null) continue;

            controllable@ apple = apples.apples[i].as_controllable();
            if (@apple is null) continue;

            if (apple.x() > x - 14 and apple.x() < x + width + 14) {
                // Floor collision
                if (apple.y() > y + height - vel - 38 and apple.y() < y + height - vel - 10 and apple.y_speed() >= 60 * vel) {
                    apple.y(y + height - vel - 36);
                    if (apple.stun_timer() > 0) {
                        apple.set_speed_xy(apple.x_speed(), -0.3 * apple.y_speed());
                    } else {
                        apple.set_speed_xy(apple.x_speed(), 60 * vel);
                    }
                    apple.rotation(-15);
                }

                // Ceiling collision
                if (apple_ceiling and apple.y() < y - vel + 28 and apple.y() > y - vel - 20 and apple.y_speed() <= 60 * vel) {
                    apple.y(y - vel + 26);
                    apple.set_speed_xy(apple.x_speed(), 60 * vel);
                }
            }
        }
    }

    void update_box_index() {
        float chosen_dist = distance(x, y, box_x, box_y);
        float chosen_index = box_index;
        for (int i=0; i<boxes.size(); ++i) {
            float dist = distance(x, y, boxes[i].x, boxes[i].y);
            if (dist < chosen_dist) {
                chosen_dist = dist;
                chosen_index = i;
            }
        }

        if (chosen_index != box_index) change_box(chosen_index);
    }

    void change_box(int new_index) {
        int old_index = box_index;
        box_index = new_index;

        box_x = boxes[new_index].x;
        box_y = boxes[new_index].y;

        if (inside) {
            p.x(p.x() + box_x - boxes[old_index].x);
            p.y(p.y() + box_y - boxes[old_index].y);
        }
    }

    void subframe_end_callback() {
        if (inside) {
            hitbox@ h = p.hitbox();
            if (@h !is null) {
                h.attack_strength(h.attack_strength() * 2);
                h.x(h.x() + x - box_x);
                h.y(h.y() + y - box_y);
            }
        }
    }

    void pre_draw(float subframe) {
        if (inside) {
            float subframe_y = y - (vel - player_vel) * (1 - subframe);
            c.offset_x = x - box_x;
            c.offset_y = subframe_y - box_y;
        }
    }

    void editor_step() {
        width = 48.0 * tile_width;
        height = 48.0 * tile_height;

        for (int i=0; i<boxes.size(); ++i) {
            boxes[i].x = 48.0 * round(boxes[i].x / 48.0);
            boxes[i].y = 48.0 * round(boxes[i].y / 48.0);
        }

        if (boxes.size() > 0) {
            box_x = boxes[0].x;
            box_y = boxes[0].y;
        }
    }

    void editor_draw(float subframe) {
        for (int i=0; i<boxes.size(); ++i) {
            outline_rect(g, 22, 0, boxes[i].x, boxes[i].y, boxes[i].x + width, boxes[i].y + height, 1, 0xDDCB0079);
            outline_rect(g, 22, 0, boxes[i].x - 6 * 48, boxes[i].y - 5 * 48, boxes[i].x + width + 6 * 48, boxes[i].y + height + 2 * 48, 1, 0xDD888888);
        }
    }
}

class Box {
    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;
}

class Apples {
    [text] float oob_y = 4000;
    [position,mode:world,layer:19,y:failsafe_y] float failsafe_x;
    [hidden] float failsafe_y;
    [hidden] array<entity@> apples;

    void reset() {
        apples.resize(0);
    }

    void step(int entities) {
        for (int i=0; i<entities; ++i) {
            entity@ e = entity_by_index(i);
            if (e.type_name() == "hittable_apple") {
                bool duplicate = false;
                for (int j=0; j<apples.size(); ++j) {
                    if (e.is_same(apples[j])) {
                        duplicate = true;
                        break;
                    }
                }

                if (not duplicate) {
                    apples.insertLast(@e);
                }

                if (e.y() > oob_y) {
                    e.x(failsafe_x);
                    e.y(failsafe_y);
                }
            }
        }
    }
}
