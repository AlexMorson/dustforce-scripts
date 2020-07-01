#include "lib/math/math.cpp"

class script : callback_base {
    scene@ g;
    controllable@ p;

    array<trigger@> triggers;

    bool prev_left = false;
    bool prev_right = false;
    bool prev_ground = false;
    bool prev_roof = false;

    float prev_vx = 0;
    float prev_vy = 0;

    script() {
        @g = get_scene();
    }

    void on_level_start() {
        @p = controller_controllable(0);
        p.as_dustman().on_subframe_end_callback(this, "subframe_end", 0);
    }

    void checkpoint_load() {
        @p = controller_controllable(0);
        p.as_dustman().on_subframe_end_callback(this, "subframe_end", 0);

        prev_left = false;
        prev_right = false;
        prev_ground = false;
        prev_roof = false;

        prev_vx = 0;
        prev_vy = 0;
    }

    void subframe_end(dustman@ dm, int) {
        for (int i=0; i<triggers.size(); ++i) {
            triggers[i].subframe_step(dm);
        }

        prev_left = dm.wall_left();
        prev_right = dm.wall_right();
        prev_ground = dm.ground();
        prev_roof = dm.roof();

        prev_vx = dm.x_speed();
        prev_vy = dm.y_speed();
    }
}

class trigger : trigger_base {
    [position,mode:world,y:y] float x;
    [hidden] float y;
    [option,0:Flat,1:SlantLeft,2:SlantRight,3:Slope] int angle;

    [hidden] float px;
    [hidden] float py;
    [hidden] float qx;
    [hidden] float qy;

    float prev_x, prev_y;

    scene@ g;
    script@ s;
    scripttrigger@ self;

    bool opEquals(trigger &in other) {
        return (
            px == other.px and
            py == other.py and
            qx == other.qx and
            qy == other.qy and
            angle == other.angle
        );
    }

    void init(script@ s, scripttrigger@ self) {
        @g = get_scene();
        @this.s = s;
        @this.self = self;

        if (s.triggers.find(this) < 0) {
            s.triggers.insertLast(this);
        }

        prev_x = self.x();
        prev_y = self.y();
    }

    void editor_step() {
        self.x(48 * round(self.x() / 48));
        self.y(48 * round(self.y() / 48));

        x = 48 * round(x / 48) + self.x() - prev_x;
        y = 48 * round(y / 48) + self.y() - prev_y;

        prev_x = self.x();
        prev_y = self.y();

        float vx, vy;
        switch (angle) {
            case 0:
                vx = 1;
                vy = 0;
                break;
            case 1:
                vx = 2;
                vy = -1;
                break;
            case 2:
                vx = 2;
                vy = 1;
                break;
            case 3:
                vx = 1;
                vy = -1;
                break;
        }

        float dx = x - self.x();
        float dy = y - self.y();

        float a = (vx * dx + vy * dy) / (vx * vx + vy * vy);

        float ax = vx * a;
        float ay = vy * a;

        px = self.x() + ax;
        py = self.y() + ay;
        qx = x - ax;
        qy = y - ay;
    }

    bool in_range(dustman@ dm) {
        float cx = (px + qx) / 2;
        float cy = (py + qy) / 2;
        float r = sqrt(pow(px-qx, 2) + pow(py-qy, 2)) / 2;

        return sqrt(pow(dm.x()-cx, 2) + pow(dm.y()-48-cy, 2)) < r + 96;
    }

    void subframe_step(dustman@ dm) {
        if (not in_range(dm)) {
            return;
        }

        rectangle@ r = dm.collision_rect();
        r.left(r.left() + dm.x() - 1);
        r.right(r.right() + dm.x() + 1);
        r.top(r.top() + dm.y() - 7);
        r.bottom(r.bottom() + dm.y() + 7);

        line l1 = line(point(self.x(), self.y()), point(px, py));
        line l2 = line(point(self.x(), self.y()), point(qx, qy));
        line l3 = line(point(x, y), point(px, py));
        line l4 = line(point(x, y), point(qx, qy));
        if (rect_line_intersect(r, l1) ||
            rect_line_intersect(r, l2) ||
            rect_line_intersect(r, l3) ||
            rect_line_intersect(r, l4)
        ) {
            if (dm.wall_left() and not s.prev_left) {
                reflect_speed(dm.left_surface_angle(), dm);
            }
            if (dm.wall_right() and not s.prev_right) {
                reflect_speed(dm.right_surface_angle(), dm);
            }
            if (dm.ground() and not s.prev_ground) {
                reflect_speed(dm.ground_surface_angle(), dm);
            }
            if (dm.roof() and not s.prev_roof) {
                reflect_speed(dm.roof_surface_angle(), dm);
            }
        }
    }

    void reflect_speed(float deg, dustman@ dm) {
        deg = (deg+360)%360;
        switch (angle) {
            case 0:
                if (not (deg == 0 or deg == 90 or deg == 180 or deg == 270)) {
                    return;
                }
                break;
            case 1:
                if (not (deg == 64 or deg == 154 or deg == 244 or deg == 334)) {
                    return;
                }
                break;
            case 2:
                if (not (deg == 26 or deg == 116 or deg == 206 or deg == 296)) {
                    return;
                }
                break;
            case 3:
                if (not (deg == 45 or deg == 135 or deg == 225 or deg == 315)) {
                    return;
                }
                break;
        }

        dm.state(7);

        float m = magnitude(s.prev_vx, s.prev_vy);

        float nx = sin(DEG2RAD * deg);
        float ny = -cos(DEG2RAD * deg);

        float ux, uy;
        normalize(s.prev_vx, s.prev_vy, ux, uy);

        float rx, ry;
        reflect(ux, uy, nx, ny, rx, ry);
        s.prev_vx = m * rx;
        s.prev_vy = m * ry;

        dm.set_speed_xy(s.prev_vx, s.prev_vy);
    }

    void editor_draw(float) {
        g.draw_line_world(22, 1, self.x(), self.y(), px, py, 4, 0xFF6E007F);
        g.draw_line_world(22, 1, self.x(), self.y(), qx, qy, 4, 0xFF6E007F);
        g.draw_line_world(22, 1, x, y, px, py, 4, 0xFF6E007F);
        g.draw_line_world(22, 1, x, y, qx, qy, 4, 0xFF6E007F);
    }
}

class point {
    float x, y;

    point() {
        x = 0;
        y = 0;
    }

    point(float _x, float _y) {
        x = _x;
        y = _y;
    }
}; 

class line {
    point p, q;

    line() {
        p = point();
        q = point();
    }

    line(point _p, point _q) {
        p = _p;
        q = _q;
    }
};

bool on_segment(point p, point q, point r) { 
    return (q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) && 
            q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y));
} 
  
int orientation(point p, point q, point r) { 
    float val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y); 
    if (val == 0) return 0; // colinear 
    return (val > 0)? 1: 2; // clock/counterclock wise 
} 
  
bool line_line_intersect(line l1, line l2) { 
    point p1 = l1.p;
    point q1 = l1.q;
    point p2 = l2.p;
    point q2 = l2.q;

    int o1 = orientation(p1, q1, p2); 
    int o2 = orientation(p1, q1, q2); 
    int o3 = orientation(p2, q2, p1); 
    int o4 = orientation(p2, q2, q1); 
  
    if (o1 != o2 && o3 != o4) return true; 
    if (o1 == 0 && on_segment(p1, p2, q1)) return true; 
    if (o2 == 0 && on_segment(p1, q2, q1)) return true; 
    if (o3 == 0 && on_segment(p2, p1, q2)) return true; 
    if (o4 == 0 && on_segment(p2, q1, q2)) return true; 

    return false;
} 

bool rect_line_intersect(rectangle@ r1, line l1) {
    point tl = point(r1.left(), r1.top());
    point tr = point(r1.right(), r1.top());
    point bl = point(r1.left(), r1.bottom());
    point br = point(r1.right(), r1.bottom());

    line t = line(tl, tr);
    line b = line(bl, br);
    line l = line(tl, bl);
    line r = line(tr, br);

    return line_line_intersect(t, l1) ||
           line_line_intersect(b, l1) ||
           line_line_intersect(l, l1) ||
           line_line_intersect(r, l1);
}

bool player_line_intersect(dustman@ player, line l) {
    rectangle@ r = player.collision_rect();
    r.left(r.left() + player.x());
    r.right(r.right() + player.x());
    r.top(r.top() + player.y());
    r.bottom(r.bottom() + player.y());
    return rect_line_intersect(r, l);
}
