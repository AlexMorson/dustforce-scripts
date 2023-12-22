#include "../lib/math/math.cpp"

#include "constants.as"
#include "geom.as"
#include "math3d.as"
#include "swimmer.as"

const string EMBED_arm = "freestyle/img/arm.png";

const string EMBED_disk_red = "freestyle/img/disk_red.png";
const string EMBED_disk_blue = "freestyle/img/disk_blue.png";
const string EMBED_disk_white = "freestyle/img/disk_white.png";

const string EMBED_disk_side_red = "freestyle/img/disk_side_red.png";
const string EMBED_disk_side_blue = "freestyle/img/disk_side_blue.png";
const string EMBED_disk_side_white = "freestyle/img/disk_side_white.png";

const array<string> DISK_EMBED_NAMES = {
    "disk_red", "disk_blue", "disk_white",
    "disk_side_red", "disk_side_blue", "disk_side_white",
};

const string EMBED_take_your_mark = "freestyle/sfx/take_your_mark.ogg";
const string EMBED_heartbeat_lub = "freestyle/sfx/heartbeat_lub.ogg";
const string EMBED_heartbeat_dub = "freestyle/sfx/heartbeat_dub.ogg";
const string EMBED_beep = "freestyle/sfx/beep.ogg";
const string EMBED_die = "freestyle/sfx/die.ogg";

const string EMBED_breath0 = "freestyle/sfx/breath0.ogg";
const string EMBED_breath1 = "freestyle/sfx/breath1.ogg";
const string EMBED_breath2 = "freestyle/sfx/breath2.ogg";
const string EMBED_intake = "freestyle/sfx/intake.ogg";
const string EMBED_gasp = "freestyle/sfx/gasp.ogg";

const string EMBED_pool_left_over = "freestyle/sfx/pool_left_over.ogg";
const string EMBED_pool_left_under = "freestyle/sfx/pool_left_under.ogg";
const string EMBED_pool_right_over = "freestyle/sfx/pool_right_over.ogg";
const string EMBED_pool_right_under = "freestyle/sfx/pool_right_under.ogg";

const string EMBED_big_splash_left_over = "freestyle/sfx/big_splash_left_over.ogg";
const string EMBED_big_splash_left_under = "freestyle/sfx/big_splash_left_under.ogg";
const string EMBED_big_splash_right_over = "freestyle/sfx/big_splash_right_over.ogg";
const string EMBED_big_splash_right_under = "freestyle/sfx/big_splash_right_under.ogg";

const string EMBED_splash0_left_over = "freestyle/sfx/splash0_left_over.ogg";
const string EMBED_splash0_left_under = "freestyle/sfx/splash0_left_under.ogg";
const string EMBED_splash0_right_over = "freestyle/sfx/splash0_right_over.ogg";
const string EMBED_splash0_right_under = "freestyle/sfx/splash0_right_under.ogg";

const string EMBED_splash1_left_over = "freestyle/sfx/splash1_left_over.ogg";
const string EMBED_splash1_left_under = "freestyle/sfx/splash1_left_under.ogg";
const string EMBED_splash1_right_over = "freestyle/sfx/splash1_right_over.ogg";
const string EMBED_splash1_right_under = "freestyle/sfx/splash1_right_under.ogg";

const string EMBED_splash2_left_over = "freestyle/sfx/splash2_left_over.ogg";
const string EMBED_splash2_left_under = "freestyle/sfx/splash2_left_under.ogg";
const string EMBED_splash2_right_over = "freestyle/sfx/splash2_right_over.ogg";
const string EMBED_splash2_right_under = "freestyle/sfx/splash2_right_under.ogg";

const string EMBED_splash3_left_over = "freestyle/sfx/splash3_left_over.ogg";
const string EMBED_splash3_left_under = "freestyle/sfx/splash3_left_under.ogg";
const string EMBED_splash3_right_over = "freestyle/sfx/splash3_right_over.ogg";
const string EMBED_splash3_right_under = "freestyle/sfx/splash3_right_under.ogg";

const array<string> SOUNDS = {
    "take_your_mark",
    "heartbeat_lub", "heartbeat_dub",
    "beep",
    "die",
    "breath0", "breath1", "breath2", "intake", "gasp",
    "pool_left_over", "pool_left_under", "pool_right_over", "pool_right_under",
    "big_splash_left_over", "big_splash_left_under", "big_splash_right_over", "big_splash_right_under",
    "splash0_left_over", "splash0_left_under", "splash0_right_over", "splash0_right_under",
    "splash1_left_over", "splash1_left_under", "splash1_right_over", "splash1_right_under",
    "splash2_left_over", "splash2_left_under", "splash2_right_over", "splash2_right_under",
    "splash3_left_over", "splash3_left_under", "splash3_right_over", "splash3_right_under",
};

const float HEART_THRESHOLD = 1.0 * MAX_ENERGY;
const float FADE_THRESHOLD = 0.5 * MAX_ENERGY;

class script
{
    [text] bool debug = false;
    [text] bool freecam = false;

    [entity] int ambience;
    [entity] int music;
    [entity] int puppet;

    scene@ g;
    sprites@ spr;
    textfield@ text;

    Swimmer swimmer;
    int win_timer = 25;
    float smoothed_breath = MAX_BREATH + MAX_ENERGY;

    float next_heartbeat = 0;
    bool next_is_lub = true;

    float time = 0;

    Mat4 proj = perspective_projection(0.001, 100, 90 * DEG2RAD, SCREEN_WIDTH / SCREEN_HEIGHT);
    Mat4 proj_view;

    script()
    {
        @g = get_scene();
        @spr = create_sprites();
        spr.add_sprite_set("script");
        @text = create_textfield();
        text.align_horizontal(-1);
        text.align_vertical(-1);
    }

    void build_sprites(message@ msg)
    {
        for (uint i = 0; i < DISK_EMBED_NAMES.size(); ++i)
        {
            msg.set_string(DISK_EMBED_NAMES[i], DISK_EMBED_NAMES[i]);
            msg.set_int(DISK_EMBED_NAMES[i] + "|offsetx", 32);
            msg.set_int(DISK_EMBED_NAMES[i] + "|offsety", 32);
        }

        msg.set_string("arm", "arm");
        msg.set_int("arm|offsetx", 180);
        msg.set_int("arm|offsety", 160);
    }

    void build_sounds(message@ msg)
    {
        for (uint i = 0; i < SOUNDS.size(); ++i)
            msg.set_string(SOUNDS[i], SOUNDS[i]);
    }

    void on_level_start()
    {
        camera@ c = get_camera(0);
        c.script_camera(true);
        c.change_ambience(entity_by_id(ambience), 0);
        c.change_music(entity_by_id(music), 0);

        controllable@ p = controller_controllable(0);
        g.remove_entity(p.as_entity());
        g.disable_score_overlay(true);
        controller_entity(0, controllable_by_id(puppet));

        @spr = create_sprites();
        spr.add_sprite_set("script");

        swimmer.play_sound("pool", 0.8, true);
        g.play_script_stream("take_your_mark", 0, 0, 0, false, 1.0);
    }

    void step(int)
    {
        time += 1.0 / 60;
        swimmer.step(time, freecam);

        if (swimmer.state == Drown)
        {
            smoothed_breath = 0;
            return;
        }

        // Heartbeat
        float volume_from_speed = (swimmer.heart_bpm - 60) / 480.0;
        float volume_from_energy = 1 - min(1.0, smoothed_breath / HEART_THRESHOLD);
        float volume = max(0.01, min(1.0, volume_from_speed + volume_from_energy));
        float interval = 60.0 / swimmer.heart_bpm;
        if (time > next_heartbeat)
        {
            // Make noise
            if (next_is_lub)
            {
                g.play_script_stream("heartbeat_lub", 0, 0, 0, false, volume);
                next_heartbeat += interval / 3;
            }
            else
            {
                g.play_script_stream("heartbeat_dub", 0, 0, 0, false, volume);
                next_heartbeat += 2 * interval / 3;
            }
            next_is_lub = !next_is_lub;
        }

        smoothed_breath = lerp(smoothed_breath, swimmer.breath + swimmer.energy, 0.05);

        // Check win condition
        if (swimmer.state == Win and win_timer > 0 and --win_timer == 0)
            g.end_level(0, 0);
    }

    void draw(float sub_frame)
    {
        proj_view = proj * swimmer.view_matrix();

        if (swimmer.face_pos().y <= POOL_LIP)
        {
            draw_building();
            draw_clocks();
            draw_pool();
            draw_flags(20);
            draw_flags(5);
            draw_arms();
            draw_water_surface();
            draw_lane_dividers(-LANE_WIDTH / 2);
            draw_lane_dividers(LANE_WIDTH / 2);
            draw_water();
        }
        else
        {
            draw_pool();
            draw_water_surface();
            draw_building();
            draw_clocks();
            draw_flags(20);
            draw_flags(5);
            draw_arms();
            draw_lane_dividers(-LANE_WIDTH / 2);
            draw_lane_dividers(LANE_WIDTH / 2);
        }

        draw_fainting();

        if (debug)
            draw_debug();
    }

    void draw_arms()
    {
        bool looking_forwards = swimmer.facing.yaw <= HALF_PI and swimmer.facing.yaw >= -HALF_PI;
        if (looking_forwards and !swimmer.forwards or !looking_forwards and swimmer.forwards)
            return;

        float scale = 0.5 / 256;

        Vec3 left_arm_pos = swimmer.left_arm_pos();
        draw_sprite(left_arm_pos, "arm", scale, scale, 0);

        Vec3 right_arm_pos = swimmer.right_arm_pos();
        draw_sprite(right_arm_pos, "arm", -scale, scale, 0);
    }

    void draw_middle()
    {
        draw_lane_dividers(-LANE_WIDTH / 2);
        draw_lane_dividers(LANE_WIDTH / 2);
    }

    void draw_triangle(Triangle triangle)
    {
        // Project into clip space
        Vec4 p1 = proj_view * triangle.a;
        Vec4 p2 = proj_view * triangle.b;
        Vec4 p3 = proj_view * triangle.c;

        // Clip against near plane
        Vec4@ c1, c2, c3, c4;
        if (!clip_triangle(p1, p2, p3, c1, c2, c3, c4))
            return;

        uint colour = triangle.colour;

        // Clip space -> DNC space -> Screen space
        g.draw_quad_world(
            20, 0, false,
            HALF_SCREEN_WIDTH * c1.x / c1.w, -HALF_SCREEN_HEIGHT * c1.y / c1.w,
            HALF_SCREEN_WIDTH * c2.x / c2.w, -HALF_SCREEN_HEIGHT * c2.y / c2.w,
            HALF_SCREEN_WIDTH * c3.x / c3.w, -HALF_SCREEN_HEIGHT * c3.y / c3.w,
            HALF_SCREEN_WIDTH * c4.x / c4.w, -HALF_SCREEN_HEIGHT * c4.y / c4.w,
            colour, colour, colour, colour);
    }

    void draw_line(Vec3 src, Vec3 dst, float width, uint colour)
    {
        // Scale width
        float dist = swimmer.perpendicular_distance_to(dst.lerp(src, 0.5));
        if (dist <= 0)
            return;
        float scaled_width = HALF_SCREEN_WIDTH * width / dist;

        // Project into clip space
        Vec4 proj_src = proj_view * src;
        Vec4 proj_dst = proj_view * dst;

        draw_line(proj_src, proj_dst, scaled_width, colour);
    }

    void draw_line(Vec4 proj_src, Vec4 proj_dst, float scaled_width, uint colour)
    {
        // Clip against near plane
        Vec4@ clip_src, clip_dst;
        if (!clip_line(proj_src, proj_dst, clip_src, clip_dst))
            return;

        // Clip space -> DNC space -> Screen space
        g.draw_line_world(
            20, 0,
            HALF_SCREEN_WIDTH * clip_src.x / clip_src.w, -HALF_SCREEN_HEIGHT * clip_src.y / clip_src.w,
            HALF_SCREEN_WIDTH * clip_dst.x / clip_dst.w, -HALF_SCREEN_HEIGHT * clip_dst.y / clip_dst.w,
            scaled_width,
            colour);
    }

    void draw_sprite(Vec3 pos, string sprite, float x_scale, float y_scale, float rotation)
    {
        // Scale size
        float dist = swimmer.perpendicular_distance_to(pos);
        if (dist <= 0)
            return;
        float actual_x_scale = x_scale * HALF_SCREEN_WIDTH / dist;
        float actual_y_scale = y_scale * HALF_SCREEN_WIDTH / dist;

        // Project into clip space
        Vec4 proj_pos = proj_view * pos;

        // Clip against near plane
        if (proj_pos.z <= -proj_pos.w)
            return;

        // Clip space -> DNC space -> Screen space
        spr.draw_world(
            20, 0,
            sprite, 1, 1,
            HALF_SCREEN_WIDTH * proj_pos.x / proj_pos.w,
            -HALF_SCREEN_HEIGHT * proj_pos.y / proj_pos.w,
            rotation * RAD2DEG,
            actual_x_scale, actual_y_scale,
            0xFFFFFFFF);
    }

    void draw_pool()
    {
            for (uint i = 0; i < POOL_GEOMETRY.size(); ++i)
                draw_triangle(POOL_GEOMETRY[i]);
    }

    void draw_building()
    {
            for (uint i = 0; i < BUILDING_GEOMETRY.size(); ++i)
                draw_triangle(BUILDING_GEOMETRY[i]);
    }

    void draw_flags(float z)
    {
        draw_line(
            Vec3(-POOL_WIDTH / 2, POOL_LIP, z),
            Vec3(-POOL_WIDTH / 2, 2, z),
            0.1, 0xFF666666);
        draw_line(
            Vec3(POOL_WIDTH / 2, POOL_LIP, z),
            Vec3(POOL_WIDTH / 2, 2, z),
            0.1, 0xFF666666);

        uint segments = 6;
        float sag = 1.0;
        
        float top = 1.95 - cosh(sag) / sag;
        for (uint i = 0; i < segments; ++i)
        {
            float x1 = i * POOL_WIDTH / 2 / segments;
            float x2 = (i + 1) * POOL_WIDTH / 2 / segments;
            float y1 = cosh(sag * i / segments) / sag + top;
            float y2 = cosh(sag * (i + 1) / segments) / sag + top;

            {
                Vec3 wire1(x1, y1, z);
                Vec3 wire2(x2, y2, z);
                draw_line(wire1, wire2, 0.03, 0xFFDDDDDD);

                Vec3 flag1 = wire1.lerp(wire2, 2.0 / 5);
                Vec3 flag2 = wire1.lerp(wire2, 3.0 / 5);
                Vec3 flag3 = wire1.lerp(wire2, 0.5) + 0.35 * (wire2 - wire1).cross(Vec3(0, 0, 1)).normalised();
                uint colour = i % 3 == 0 ? 0xFFFF0000 : i % 3 == 1 ? 0xFF0000FF : 0xFFFFFFFF;
                draw_triangle(Triangle(flag1, flag2, flag3, colour));
            }

            {
                Vec3 wire1(-x2, y2, z);
                Vec3 wire2(-x1, y1, z);
                draw_line(wire1, wire2, 0.03, 0xFFDDDDDD);

                Vec3 flag1 = wire1.lerp(wire2, 2.0 / 5);
                Vec3 flag2 = wire1.lerp(wire2, 3.0 / 5);
                Vec3 flag3 = wire1.lerp(wire2, 0.5) + 0.35 * (wire2 - wire1).cross(Vec3(0, 0, 1)).normalised();
                uint colour = i % 3 == 2 ? 0xFFFF0000 : i % 3 == 1 ? 0xFF0000FF : 0xFFFFFFFF;
                draw_triangle(Triangle(flag1, flag2, flag3, colour));
            }
        }
    }

    void draw_clocks()
    {
        float angle = (time - 55.0 / 60) / 60 * 2 * PI;
        draw_clock(angle, POOL_LENGTH + POOL_BORDER);
        draw_clock(-angle, -POOL_BORDER);
    }

    void draw_clock(float angle, float z)
    {
        float s = 0.1 * sin(angle);
        float c = 0.1 * cos(angle);
        Vec3 p1(c, CLOCK_HEIGHT - s, z);
        Vec3 p2(-c, CLOCK_HEIGHT + s, z);

        Vec3 middle(0, CLOCK_HEIGHT, z);
        Vec3 hand_offset = CLOCK_RADIUS * (p2 - p1).cross(Vec3(0, 0, 1)).normalised();
        Vec3 red = middle + hand_offset;
        Vec3 black = middle - hand_offset;

        draw_triangle(Triangle(p1, p2, red, 0xFFEE0000));
        draw_triangle(Triangle(p2, p1, black, 0xFF000000));
    }

    void draw_water()
    {
        if (swimmer.face_pos().y <= 0)
        {
            g.draw_rectangle_world(
                20, 0,
                -SCREEN_WIDTH, -SCREEN_HEIGHT,
                SCREEN_WIDTH, SCREEN_HEIGHT,
                0,
                0xAA4455BB);
        }
    }

    void draw_water_surface()
    {
        Vec3 tl(-POOL_WIDTH / 2, 0, POOL_LENGTH);
        Vec3 tr(POOL_WIDTH / 2, 0, POOL_LENGTH);
        Vec3 bl(-POOL_WIDTH / 2, 0, 0);
        Vec3 br(POOL_WIDTH / 2, 0, 0);
        draw_triangle(Triangle(tl, tr, bl, 0xAA6688BB));
        draw_triangle(Triangle(tr, br, bl, 0xAA6688BB));
    }

    void draw_lane_dividers(float x_offset)
    {
        bool forwards = swimmer.facing.yaw <= HALF_PI and swimmer.facing.yaw >= -HALF_PI;
        if (forwards)
            draw_lane_dividers_forward(x_offset);
        else
            draw_lane_dividers_backward(x_offset);
    }

    void draw_lane_dividers_forward(float x_offset)
    {
        bool side = swimmer.facing.yaw > PI / 3 or swimmer.facing.yaw < -PI / 3;
        Vec3 last_disk_pos;
        for (int i = DISK_COUNT; i >= 0; --i)
        {
            float pool_z = POOL_LENGTH * i / DISK_COUNT;

            float pool_y = 0;
            if (i != DISK_COUNT && i != 0)
                pool_y = (
                    0.015 * sin(pool_z + time + x_offset) +
                    0.015  * sin(1.7 * (pool_z + time + x_offset) + 1));

            Vec3 disk_pos(x_offset, pool_y, pool_z);

            if (i != DISK_COUNT)
                draw_line(last_disk_pos, disk_pos, 0.01, 0xFFDDDD00);
            last_disk_pos = disk_pos;

            string sprite = "disk_";
            if (side) sprite += "side_";
            if (pool_z < 5 or pool_z >= POOL_LENGTH - 5)
                sprite += "red";
            else if (int(pool_z) % 2 == 0)
                sprite += "blue";
            else
                sprite += "white";

            float scale = DISK_DIAMETER / 48.0;
            if (i != DISK_COUNT and i != 0)
                draw_sprite(disk_pos, sprite, (x_offset > 0 ? 1 : -1) * scale, scale, -swimmer.facing.roll);
        }
    }

    void draw_lane_dividers_backward(float x_offset)
    {
        bool side = -2 * PI / 3 < swimmer.facing.yaw and swimmer.facing.yaw < 2 * PI / 3;
        Vec3 last_disk_pos;
        for (int i = 0; i <= DISK_COUNT; ++i)
        {
            float pool_z = POOL_LENGTH * i / DISK_COUNT;

            float pool_y = 0;
            if (i != DISK_COUNT && i != 0)
                pool_y = (
                    0.015 * sin(pool_z + time + x_offset) +
                    0.015  * sin(1.7 * (pool_z + time + x_offset) + 1));

            Vec3 disk_pos(x_offset, pool_y, pool_z);

            if (i != 0)
                draw_line(last_disk_pos, disk_pos, 0.01, 0xFFDDDD00);
            last_disk_pos = disk_pos;

            string sprite = "disk_";
            if (side) sprite += "side_";
            if (pool_z < 5 or pool_z >= POOL_LENGTH - 5)
                sprite += "red";
            else if (int(pool_z) % 2 == 0)
                sprite += "blue";
            else
                sprite += "white";

            float scale = DISK_DIAMETER / 48.0;
            if (i != DISK_COUNT and i != 0)
                draw_sprite(disk_pos, sprite, (x_offset > 0 ? -1 : 1) * scale, scale, -swimmer.facing.roll);
        }
    }

    void draw_fainting()
    {
        float fade = min(1.0, smoothed_breath / FADE_THRESHOLD);
        uint opacity = uint(255 * (1 - fade)) << 24;
        g.draw_rectangle_world(
            20, 0,
            -SCREEN_WIDTH, -SCREEN_HEIGHT,
            SCREEN_WIDTH, SCREEN_HEIGHT,
            0,
            opacity);
    }

    void draw_debug()
    {
        g.draw_rectangle_world(
            20, 0,
            -800, -500,
            -780, 100 * swimmer.energy - 500,
            0,
            0xAA66FF66);
        g.draw_rectangle_world(
            20, 0,
            -770, -500,
            -750, 100 * swimmer.breath - 500,
            0,
            0xFF6666FF);

        text.text("Pos: " + formatFloat(swimmer.pos.z, "0", 3, 2));
        text.draw_world(20, 0, -740, -500, 1, 1, 0);

        text.text("Speed: " + formatFloat(60 * swimmer.speed, "0", 3, 2));
        text.draw_world(20, 0, -740, -460, 1, 1, 0);

        text.text("Power: " + formatFloat(swimmer.power(), "0", 3, 2));
        text.draw_world(20, 0, -740, -420, 1, 1, 0);

        text.text("Heart: " + formatFloat(swimmer.heart_bpm, "", 3, 0));
        text.draw_world(20, 0, -740, -380, 1, 1, 0);
    }
}
