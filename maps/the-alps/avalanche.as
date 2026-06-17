#include "lib/drawing/circle.cpp"

const string EMBED_rumble = "dormant/rumble.ogg";
const string EMBED_rocks = "rocks.ogg";

class Pos2
{
    [position, mode:world, layer:19, y:y] float x;
    [hidden] float y;

    Pos2() {}

    Pos2(float x, float y)
    {
        this.x = x;
        this.y = y;
    }

    Pos2 opAdd(const Pos2 &in other) const
    {
        return Pos2(x + other.x, y + other.y);
    }

    Pos2 opSub(const Pos2 &in other) const
    {
        return Pos2(x - other.x, y - other.y);
    }

    float length() const
    {
        return sqrt(x * x + y * y);
    }
}

class Visuals
{
    [position, mode:world, layer:19, y:top] float left;
    [hidden] float top;
    [position, mode:world, layer:19, y:bottom] float right;
    [hidden] float bottom;

    [hidden] array<Prop> props;
    [hidden] array<Entity> emitters;

    Visuals() {}

    void init(scene@ g)
    {
        props.resize(0);
        int n = g.get_prop_collision(top, bottom, left, right);
        for (int i = 0; i < n; ++i)
        {
            prop@ p = g.get_prop_collision_index(i);
            if (p.layer() > 11)
                props.insertLast(Prop(p));
        }

        emitters.resize(0);
        n = g.get_entity_collision(top, bottom, left, right, 13);  // col_type_emitter
        for (int i = 0; i < n; ++i)
        {
            entity@ e = g.get_entity_collision_index(i);
            emitters.insertLast(Entity(e));
        }
    }

    void reload()
    {
        for (uint i = 0; i < props.size(); ++i)
            props[i].reload();
        for (uint i = 0; i < emitters.size(); ++i)
            emitters[i].reload();
    }

    void set_offset(Pos2 offset)
    {
        for (uint i = 0; i < props.size(); ++i)
            props[i].set_offset(offset);
        for (uint i = 0; i < emitters.size(); ++i)
            emitters[i].set_offset(offset);
    }

    void debug(scene@ g) const
    {
        if (left > right) return;
        if (top > bottom) return;

        g.draw_rectangle_world(22, 0, left, top, right, bottom, 0, 0x44FF00FF);
    }
}

class Prop
{
    [hidden] int id;

    float start_x;
    float start_y;

    prop@ p;

    Prop() {}

    Prop(prop@ p)
    {
        @this.p = p;
        this.id = p.id();
        this.start_x = p.x();
        this.start_y = p.y();
    }

    void reload()
    {
        @p = prop_by_id(id);
    }

    void set_offset(Pos2 offset)
    {
        p.x(start_x + offset.x);
        p.y(start_y + offset.y);
    }
}

class Entity
{
    [hidden] int id;

    float start_x;
    float start_y;

    entity@ e;

    Entity() {}

    Entity(entity@ e)
    {
        @this.e = e;
        this.id = e.id();
        this.start_x = e.x();
        this.start_y = e.y();
    }

    void reload()
    {
        @e = entity_by_id(id);
    }

    void set_offset(Pos2 offset)
    {
        e.x(start_x + offset.x);
        e.y(start_y + offset.y);
    }
}

class Avalanche
{
    Pos2 origin;

    Visuals@ visuals;

    Avalanche() {}

    Avalanche(Pos2 origin, Visuals@ visuals)
    {
        this.origin = origin;
        @this.visuals = visuals;
    }

    void update(Pos2 target)
    {
        visuals.set_offset(target - origin);
    }
}

class PathNode
{
    [edit] Pos2 pos;
    [edit] float speed = 10.0;

    PathNode() {}
}

class script
{
    scene@ g;
    sprites@ spr;

    [edit] bool debug = false;

    [edit] float volume_scale = 0.5;

    [edit | tooltip:"The bounds of the props/emitters that will move"] Visuals visuals;

    [edit | tooltip:"The path that the avalanche will follow"] array<PathNode> path;
    [hidden] uint path_index;
    [hidden] float path_fraction;

    [position, mode:world, layer:19, y:origin_y | tooltip:"The point that will follow the path"] float origin_x;
    [hidden] float origin_y;

    [position, mode:world, layer:19, y:center_y] float center_x;
    [hidden] float center_y;
    [edit] float death_radius;
    Pos2 target;

    audio@ rumble;
    audio@ rocks;

    Avalanche avalanche;

    dustman@ dm;

    script()
    {
        @g = get_scene();
    }

    void build_sounds(message@ msg) {
        msg.set_string("rumble", "rumble");
        msg.set_string("rocks", "rocks");
    }

    void on_level_start()
    {
        path_index = 0;
        path_fraction = 0.0;

        target = path[0].pos;
        visuals.init(g);
        avalanche = Avalanche(Pos2(origin_x, origin_y), visuals);
        @dm = controller_controllable(0).as_dustman();
        @rumble = g.play_script_stream("rumble", 0, 0, 0, true, 0.0);
        @rocks = g.play_script_stream("rocks", 0, 0, 0, true, 0.0);
    }

    void checkpoint_load()
    {
        visuals.reload();
        @dm = controller_controllable(0).as_dustman();
    }

    void step(int entities)
    {
        if (dm is null) return;

        move_target();
        avalanche.update(target);
        proximity_effects();

        // Check for death
        Pos2 player(dm.x(), dm.y());
        Pos2 center(center_x, center_y);
        Pos2 origin(origin_x, origin_y);
        float distance = (target + center - origin - player).length();
        if (distance < death_radius and not dm.dead())
            dm.kill(false);
    }

    void move_target()
    {
        // How long is the current segment?
        Pos2@ start = path[path_index].pos;
        Pos2@ end = path[path_index + 1].pos;
        Pos2 delta(end.x - start.x, end.y - start.y);
        float length = sqrt(delta.x * delta.x + delta.y * delta.y);

        // Rubber-banding
        float speed_modifier = 1.0;
        camera@ c = get_camera(0);
        Pos2 camera_pos(c.x(), c.y());
        Pos2 center(center_x, center_y);
        Pos2 origin(origin_x, origin_y);
        float distance = max(0.0, (center + target - origin - camera_pos).length() - death_radius);
        if (distance > 1500.0)
            speed_modifier = (distance - 1000.0) / 500.0;

        // Move along the path
        path_fraction += speed_modifier * path[path_index].speed / length;

        // Switch to the next segment and recurse
        if (path_fraction > 1.0)
        {
            if (path_index < path.size() - 2)
            {
                path_fraction = (path_fraction - 1.0) / path[path_index].speed * path[path_index + 1].speed;
                path_index += 1;
                move_target();
            }
            return;
        }

        // Update the target position
        target.x = start.x + path_fraction * delta.x;
        target.y = start.y + path_fraction * delta.y;
    }

    void proximity_effects()
    {
        // How far is the camera from "dying"?
        camera@ c = get_camera(0);
        Pos2 camera_pos(c.x(), c.y());
        Pos2 center(center_x, center_y);
        Pos2 origin(origin_x, origin_y);
        float distance = max(0.0, (center + target - origin - camera_pos).length() - death_radius);

        const float near = 500.0;
        const float mid = 1500.0;
        const float far = 3000.0;
        
        // Rocks: 0 at mid, 1 at near
        float rocks_volume = max(0.0, min(1.0, 1.0 - (distance - near) / (mid - near)));
        rocks.volume(rocks_volume * volume_scale);

        // Rumble: 0 at far, 1 at mid
        float rumble_volume = max(0.0, min(1.0, 1.0 - (distance - mid) / (far - mid)));
        rumble.volume(rumble_volume * volume_scale);

        // Screen-shake: 0 at mid, 0.8 at near
        float shake_chance = max(0.0, min(1.0, 0.8 * (1.0 - (distance - near) / (mid - near))));
        if (float(rand()) < 1073741824 * shake_chance)
            c.add_screen_shake(c.x(), c.y(), rand() % 360, 6);
    }

    void draw(float sub_frame)
    {
        if (!debug) return;

        Pos2 center(center_x, center_y);
        Pos2 origin(origin_x, origin_y);
        Pos2 death = target + center - origin;
        drawing::circle(g, 22, 0, death.x, death.y, death_radius, 64, 4, 0x88FF0000);
    }

    void editor_draw(float sub_frame)
    {
        if (!debug) return;

        visuals.debug(g);
  
        drawing::fill_circle(g, 22, 0, origin_x, origin_y, 10, 16, 0x88FF0000, 0x88FF0000);

        drawing::circle(g, 22, 0, center_x, center_y, death_radius, 64, 4, 0x88FF0000);

        textfield@ t = create_textfield();
        t.align_horizontal(-1);
        t.align_vertical(1);
        for (uint i = 0; i < path.size(); ++i)
        {
            Pos2@ start = path[i].pos;
            if (i < path.size() - 1)
            {
                Pos2@ end = path[i + 1].pos;
                g.draw_line_world(22, 0, start.x, start.y, end.x, end.y, 4, 0x88FF0000);
            }

            t.text("" + i);
            t.draw_world(22, 0, start.x + 10, start.y - 10, 1, 1, 0);
        }
    }
}
