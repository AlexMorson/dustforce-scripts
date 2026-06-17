class script {
    [text] array<barrier> barriers;

    scene@ g;
    dustman@ player;
    fog_setting@ fog;

    int frame = 5;
    bool player_dead = false;
    bool level_ended = false;

    script() {
        @this.g = get_scene();
    }

    void on_level_start() {
        @this.player = controller_controllable(0).as_dustman();
        this.reset_fog_trigger();
    }

    void on_level_end() {
        this.player_dead = false;
        this.level_ended = true;
        for (int i=0; i<barriers.size(); ++i) {
            barriers[i].disabled = false;
            barriers[i].killer = false;
        }
    }

    void checkpoint_load() {
        @this.player = controller_controllable(0).as_dustman();
        this.reset_fog_trigger();
    }

    void reset_fog_trigger() {
        @this.fog = get_camera(0).get_fog();
        // Set background colour
        this.fog.bg_top(0xFF16464C);
        this.fog.bg_mid(0xFF16464C);
        this.fog.bg_bot(0xFF16464C);
        // Remove stars
        this.fog.stars_top(0);
        this.fog.stars_mid(0);
        this.fog.stars_bot(0);
        // Set layer/sublayer colours
        for (uint layer=0; layer<21; ++layer) {
            this.fog.layer_percent(layer, 1);
            switch (layer) {
                case 18:
                    this.fog.layer_colour(layer, 0xFFFFFFFF);
                    break;
                case 19:
                    this.fog.layer_colour(layer, 0xFF16464C);
                    break;
                default:
                    this.fog.layer_colour(layer, 0xFF000000);
                    break;
            }
        }
        get_camera(0).change_fog(this.fog, 0);
    }

    void step(int entities) {
        if (this.player !is null) {
            ++this.frame;

            if (!this.player_dead && !this.level_ended) {

                // Check the player `mode`
                uint mode = 0;
                if (this.player.jump_intent() > 0) {
                    mode = 1;
                }

                // Set the player's colour based on the mode
                uint colour;
                switch (mode) {
                    case 0:
                        colour = 0xFFFFFFFF;
                        break;
                    case 1:
                        colour = 0xFFFF0000;
                        break;
                }
                this.fog.colour(18, 10, colour);
                this.fog.colour(18, 14, colour);
                this.fog.colour(18, 15, colour);
                get_camera(0).change_fog(this.fog, 0);

                // Check collision against the barriers
                rect player_rect = get_collision_rect(player.as_controllable());
                for (int i=0; i<barriers.size(); ++i) {
                    barriers[i].check_intersect(player, player_rect, mode);
                    if (player.dead()) {
                        this.player_dead = true;
                        this.g.combo_break_count(this.g.combo_break_count() + 1);
                        break;
                    }
                }
            }
        }
    }

    void editor_draw(float sub_frame) {
        canvas@ c = create_canvas(false, 20, 1);
        for (int i=0; i<barriers.size(); ++i) {
            barriers[i].draw(g, frame, this.player_dead, false);
            barriers[i].draw_debug(c, i);
        }
    }

    void draw(float sub_frame) {
        for (int i=0; i<barriers.size(); ++i) {
            barriers[i].draw(g, frame, this.player_dead, true);
        }
    }
}

class barrier {
    [position,mode:world,layer:19,y:y1] float x1;
    [position,mode:world,layer:19,y:y2] float x2;
    [hidden] float y1;
    [hidden] float y2;
    [option,0:Yellow,1:White,2:Red,3:Green,4:Pink,5:Blue,6:Grey] int type;

    bool disabled = false;
    bool killer = false;

    void check_intersect(dustman@ player, rect player_rect, uint player_mode) {
        this.disabled = false;
        if (player_rect.intersects(this.line())) {
            switch (this.type) {
                case 1:
                    if (player_mode == 0) {
                        this.disabled = true;
                    } else {
                        this.kill_player(player);
                    }
                    break;
                case 2:
                    if (player_mode == 1) {
                        this.disabled = true;
                    } else {
                        this.kill_player(player);
                    }
                    break;
                case 4:
                    this.kill_player(player);
                    break;

            }
        }
    }

    void kill_player(dustman@ player) {
        point to_prev_player = point(player.prev_x()-x1, player.prev_y()-y1);
        point perp = point(x2-x1, y2-y1).unit().perpendicular();

        this.killer = true;
        player.kill(false);

        if (perp.dot(to_prev_player) >= 0) {
            player.stun(300*perp.x, 300*perp.y);
        } else {
            player.stun(-300*perp.x, -300*perp.y);
        }
    }

    void draw(scene@ g, int frame, bool player_dead, bool detailed) {
        if (player_dead && !this.killer) return;

        float x1 = round(this.x1 / 48) * 48;
        float x2 = round(this.x2 / 48) * 48;
        float y1 = round(this.y1 / 48) * 48;
        float y2 = round(this.y2 / 48) * 48;

        uint colour, opacity, layer;

        if (this.type != 0 && disabled) {
            opacity = 0x55000000;
            layer = 17;
        } else {
            opacity = 0xFF000000;
            layer = 20;
        }
        switch (this.type) {
            case 0:
                colour = 0xFFFF00;
                break;
            case 1:
                colour = 0xFFFFFF;
                break;
            case 2:
                colour = 0xFF0000;
                break;
            case 3:
                colour = 0xAAFF33;
                break;
            case 4:
                colour = 0xFF2277;
                break;
            case 5:
                colour = 0x00FFFF;
                break;
            case 6:
                colour = 0x555555;
                break;
        }

        g.draw_line_world(layer, 0, x1, y1, x2, y2, 15, colour + opacity);

        if (detailed) {
            int grainy = (3.5*round(frame/3.5)) % 20;
            int offset = 5 - abs(10 - grainy);
            point perp = point(x2-x1, y2-y1).unit().scale(offset).perpendicular();
            g.draw_line_world(layer, 0, x1+perp.x, y1+perp.y, x2+perp.x, y2+perp.y,  3, opacity);
        }
    }

    void draw_debug(canvas@ c, int index) {
        textfield@ text = create_textfield();
        text.text(formatInt(index));
        c.draw_text(text, (x1+x2)/2, (y1+y2)/2, 1, 1, 0);
    }

    line line() {
        return line(point(x1, y1), point(x2, y2));
    }
}

class point {
    float x;
    float y;

    point() {}

    point(float x, float y) {
        this.x = x;
        this.y = y;
    }

    point unit() {
        float length = sqrt(x*x + y*y);
        if (length > 0) {
            return point(this.x/length, this.y/length);
        } else {
            return point(1, 0);
        }
    }

    point scale(float amount) {
        return point(amount*this.x, amount*this.y);
    }

    point perpendicular() {
        return point(this.y, -this.x);
    }

    float dot(point them) {
        return (this.x * them.x) + (this.y * them.y);
    }
}

string formatPoint(point p) {
    return "point(" + formatFloat(p.x) + "," + formatFloat(p.y) + ")";
}

class line {
    point p1;
    point p2;

    line() {}

    line(point p1, point p2) {
        this.p1 = p1;
        this.p2 = p2;
    }

    bool intersects(line them) {
        return (
            ((them.p1.x-this.p1.x)*(this.p2.y-this.p1.y) - (them.p1.y-this.p1.y)*(this.p2.x-this.p1.x)) * ((them.p2.x-this.p1.x)*(this.p2.y-this.p1.y) - (them.p2.y-this.p1.y)*(this.p2.x-this.p1.x)) < 0 &&
            ((this.p1.x-them.p1.x)*(them.p2.y-them.p1.y) - (this.p1.y-them.p1.y)*(them.p2.x-them.p1.x)) * ((this.p2.x-them.p1.x)*(them.p2.y-them.p1.y) - (this.p2.y-them.p1.y)*(them.p2.x-them.p1.x)) < 0
        );
    }
}

string formatLine(line l) {
    return "line(" + formatPoint(l.p1) + "," + formatPoint(l.p2) + ")";
}

class rect {
    point tl;
    point br;

    line top;
    line right;
    line bottom;
    line left;

    rect() {}

    rect(point tl, point br) {
        this.tl = tl;
        this.br = br;

        point tr(br.x, tl.y);
        point bl(tl.x, br.y);

        this.top = line(tl, tr);
        this.right = line(tr, br);
        this.bottom = line(br, bl);
        this.left = line(bl, tl);
    }

    bool intersects(line them) {
        return (
            top.intersects(them) ||
            right.intersects(them) ||
            bottom.intersects(them) ||
            left.intersects(them)
        );
    }
}

string formatRect(rect r) {
    return "rect(" + formatPoint(r.tl) + "," + formatPoint(r.br) + ")";
}

rect get_collision_rect(controllable@ c) {
    rectangle@ r = c.collision_rect();
    return rect(point(r.left()+c.x(), r.top()+c.y()), point(r.right()+c.x(), r.bottom()+c.y()));
}
