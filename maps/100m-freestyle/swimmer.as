#include "../lib/easing/quad.cpp"
#include "../lib/easing/cubic.cpp"

#include "angles.as"
#include "math3d.as"

const float ALMOST_HALF_PI = HALF_PI - 0.01;

const float START_TIME = 80.0 / 60;
const float STROKE_TIME = 0.7;
const float FLIP_TIME = 2.0;
const float JUMP_TIME = 1.0;
const float LEG_TIME = 0.3;
const float RESPAWN_TIME = 4.0;

const float STROKE_SPEED = 0.006;
const float JUMP_SPEED = 0.02;
const float LEG_SPEED = 0.002;
const float LAUNCH_SPEED = 0.03;
const float LAUNCH_Y_SPEED = 0.02;

const float STROKE_CANCEL = 0.2;

const float WALL_BUMP = 0.2;
const float JUMP_LEEWAY = 1.5;

const float GRAVITY = 0.001;
const float SWIM_HEIGHT = 0.1;

const float STROKE_COST = 0.15;
const float JUMP_COST = 0.2;
const float LEG_COST = 0.05;
const float IDLE_COST = 0.001;

const float MAX_BREATH = 1.0;
const float MAX_ENERGY = 3.0;

const float EYE_PROTUSION = 0.2;
const float EAR_WIDTH = 0.08;


class Sound
{
    string name;
    float volume;
    bool loop;

    audio@ left_over;
    audio@ left_under;
    audio@ right_over;
    audio@ right_under;

    Sound(string name, float volume, bool loop = false)
    {
        this.name = name;
        this.volume = volume;
        this.loop = loop;
    }

    void play(float left_mix, float right_mix)
    {
        scene@ g = get_scene();

        @left_over = g.play_script_stream(name + "_left_over", 0, 0, 0, loop, volume * left_mix);
        @left_under = g.play_script_stream(name + "_left_under", 0, 0, 0, loop, volume * (1 - left_mix));
        @right_over = g.play_script_stream(name + "_right_over", 0, 0, 0, loop, volume * right_mix);
        @right_under = g.play_script_stream(name + "_right_under", 0, 0, 0, loop, volume * (1 - right_mix));
    }

    bool update(float left_mix, float right_mix, float global_volume)
    {
        if (!left_over.is_playing())
            return false;

        left_over.volume(volume * global_volume * left_mix);
        left_under.volume(volume * global_volume *(1 - left_mix));
        right_over.volume(volume * global_volume * right_mix);
        right_under.volume(volume * global_volume * (1 - right_mix));

        return true;
    }

    void stop()
    {
        left_over.stop();
        left_under.stop();
        right_over.stop();
        right_under.stop();
    }
}

class Input
{
    camera@ c;

    bool up_down;
    bool up_press;

    bool down_down;
    bool down_press;

    bool left_down;
    bool left_press;

    bool right_down;
    bool right_press;

    bool jump_down;
    bool jump_press;

    bool dash_down;
    bool dash_press;

    Input()
    {
        @c = get_camera(0);
        c.controller_mode(4);
    }

    void step()
    {
        int up, down;
        c.input_y(up, down);
        up_down = up & 1 > 0;
        up_press = up & 2 > 0;
        down_down = down & 1 > 0;
        down_press = down & 2 > 0;
        
        int left, right;
        c.input_x(left, right);
        left_down = left & 1 > 0;
        left_press = left & 2 > 0;
        right_down = right & 1 > 0;
        right_press = right & 2 > 0;

        int jump = c.input_jump();
        jump_down = jump & 1 > 0;
        jump_press = jump & 2 > 0;

        int dash = c.input_dash();
        dash_down = dash & 1 > 0;
        dash_press = dash & 2 > 0;
    }
}

enum State
{
    Mark,
    Launch,
    Idle,
    Left,
    LeftStroke,
    Right,
    RightStroke,
    Flip,
    Jump,
    Drown,
    Win,
};

Euler target_facing(State state, bool forwards, bool looking_up)
{
    if (forwards)
    {
        if (looking_up)
            switch (state)
            {
                case Mark:
                case Launch:
                case Idle:
                    return Euler(0, 0, 0);
                case Left:
                case LeftStroke:
                    return Euler(-ALMOST_HALF_PI, 0.2, HALF_PI);
                case Right:
                case RightStroke:
                    return Euler(ALMOST_HALF_PI, 0.2, -HALF_PI);
            }
        else
            switch (state)
            {
                case Mark:
                case Launch:
                case Idle:
                case Left:
                case Right:
                case Drown:
                    return Euler(0, PI / 3, 0);
                case LeftStroke:
                    return Euler(-PI / 3, PI / 3, PI / 3);
                case RightStroke:
                    return Euler(PI / 3, PI / 3, -PI / 3);
            }
    }
    else
    {
        if (looking_up)
            switch (state)
            {
                case Idle:
                    return Euler(PI, 0, 0);
                case Left:
                case LeftStroke:
                    return Euler(PI - ALMOST_HALF_PI, 0.2, HALF_PI);
                case Right:
                case RightStroke:
                    return Euler(PI + ALMOST_HALF_PI, 0.2, -HALF_PI);
                case Win:
                    return Euler(PI, -PI / 5, 0);
            }
        else
            switch (state)
            {
                case Idle:
                case Left:
                case Right:
                case Drown:
                    return Euler(PI, PI / 3, 0);
                case LeftStroke:
                    return Euler(PI - PI / 3, PI / 3, PI / 3);
                case RightStroke:
                    return Euler(PI + PI / 3, PI / 3, -PI / 3);
            }
    }
    return Euler();
}

class Swimmer
{
    scene@ g;
    Input input;

    float last_mouse_x, last_mouse_y;

    bool started = false;
    uint laps = 0;
    bool forwards = true;

    bool looking_up = true;
    bool prev_looking_up;

    Vec3 pos(0, POOL_LIP + 0.5, -0.2);
    float speed;
    float y_speed;

    Euler facing(0, 0, 0);
    Euler prev_facing;

    State state = Mark;
    State prev_state;
    float timer = 0;
    float timer_max = 1;
    float visuals_timer_offset;

    uint left_arm_time = 100;
    uint right_arm_time = 100;
    State flip_start_state;

    float leg_timer = 0;

    bool was_above_water = true;
    float breath = MAX_BREATH;
    float energy = MAX_ENERGY;

    float heart_bpm = 60;

    array<Sound@> active_sounds;
    float left_ear_volume = 1.0;
    float right_ear_volume = 1.0;
    float global_volume = 1.0;

    Swimmer()
    {
        @g = get_scene();
    }

    void change_state(State new_state, bool new_looking_up, float new_timer = 0, float new_timer_max = STROKE_TIME, float new_visuals_timer_offset = 0)
    {
        prev_looking_up = looking_up;
        prev_facing = facing;
        prev_state = state;
        looking_up = new_looking_up;
        state = new_state;
        timer = new_timer;
        timer_max = new_timer_max;
        visuals_timer_offset = new_visuals_timer_offset;
    }

    Vec3 left_arm_pos()
    {
        float z = 0.8 - left_arm_time / 25.0;
        return face_pos() + Vec3(forwards ? -0.2 : 0.2, -0.3, forwards ? z : -z);
    }

    Vec3 right_arm_pos()
    {
        float z = 0.8 - right_arm_time / 25.0;
        return face_pos() + Vec3(forwards ? 0.2 : -0.2, -0.3, forwards ? z : -z);
    }

    Vec3 face_pos()
    {
        return pos + Vec3(0, -EYE_PROTUSION * sin(facing.pitch), 0);
    }

    void step(float time, bool freecam)
    {
        if (!started and time >= START_TIME)
        {
            g.play_script_stream("beep", 0, 0, 0, false, 1.0);
            started = true;
        }

        input.step();

        if (freecam)
        {
            step_freecam();
            return;
        }

        left_arm_time += 1;
        right_arm_time += 1;

        timer -= 1.0 / 60;
        switch (state)
        {
            case Mark:
                if (input.jump_press and started)
                    launch();
                else if (looking_up and input.down_press)
                    change_state(Mark, false, STROKE_TIME, STROKE_TIME);
                else if (!looking_up and input.up_press)
                    change_state(Mark, true, STROKE_TIME, STROKE_TIME);
                break;

            case Launch:
                step_launch();
                break;

            case LeftStroke:
                step_left_stroke();
                break;

            case RightStroke:
                step_right_stroke();
                break;

            case Left:
                step_left();
                break;

            case Right:
                step_right();
                break;

            case Idle:
                step_idle();
                break;

            case Flip:
                step_flip();
                break;

            case Jump:
                step_jump();
                break;
        }

        leg_timer -= 1.0 / 60;
        if (state != Mark and state != Launch and state != Flip)
            step_legs();

        if (state != Launch and state != Flip and state != Jump)
        {
            if (timer + visuals_timer_offset <= 0)
                facing = target_facing(state, forwards, looking_up);
            else
            {
                Euler src = prev_facing;
                Euler dst = target_facing(state, forwards, looking_up);
                facing = src.slerp(dst, ease_out_cubic(1 - (timer + visuals_timer_offset) / (timer_max + visuals_timer_offset)));
            }
        }

        if (pos.y < SWIM_HEIGHT)
        {
            float buoyancy = max(0.0, SWIM_HEIGHT - pos.y) / (state == Flip or state == Jump ? 1000.0 : 200.0);
            y_speed += buoyancy;
            y_speed = min((SWIM_HEIGHT - pos.y) / 2, y_speed);
            y_speed *= (state == Flip or state == Jump ? 0.99 : 0.9);
        }
        else if (state != Mark)
        {
            y_speed -= GRAVITY;
        }
        pos.y += y_speed;
        pos.y = max(-0.8 * POOL_DEPTH, pos.y);
        pos.z += speed;
        if (forwards and pos.z > POOL_LENGTH - WALL_BUMP)
        {
            speed = 0;
            pos.z = POOL_LENGTH - WALL_BUMP;
            // state = Turn;
        }
        else if (!forwards and pos.z < WALL_BUMP)
        {
            speed = 0;
            pos.z = WALL_BUMP;
            if (laps == 3)
                change_state(Win, true, STROKE_TIME, STROKE_TIME);
        }

        if (state != Launch)
            speed *= looking_up ? 0.985 : 0.994;

        step_breath();

        heart_bpm = max(heart_bpm - 0.015, lerp(heart_bpm, 60, 0.002));

        step_ears();
    }

    void step_idle()
    {
        if (input.left_press)
        {
            change_state(LeftStroke, looking_up, STROKE_TIME);
            stroke();
            step_left_stroke();
        }
        else if (input.right_press)
        {
            change_state(RightStroke, looking_up, STROKE_TIME);
            stroke();
            step_right_stroke();
        }
        else if (looking_up and input.down_press)
            change_state(Idle, false, STROKE_TIME);
        else if (!looking_up and input.up_press)
            change_state(Idle, true, STROKE_TIME);
        else if (input.dash_press)
            flip();
    }

    void step_left_stroke()
    {
        if (timer <= STROKE_CANCEL and input.right_press)
        {
            change_state(RightStroke, looking_up, STROKE_TIME);
            stroke();
            step_right_stroke();
        }
        else if (timer <= 0)
        {
            change_state(Left, looking_up, STROKE_TIME);
            step_left();
        }
        else if (looking_up and input.down_press)
            change_state(LeftStroke, false, timer, timer, max(0.0, STROKE_TIME - timer));
        else if (!looking_up and input.up_press)
            change_state(LeftStroke, true, timer, timer, max(0.0, STROKE_TIME - timer));
        else if (timer <= STROKE_CANCEL and input.dash_press)
            flip();
    }

    void step_right_stroke()
    {
    if (timer <= STROKE_CANCEL and input.left_press)
        {
            change_state(LeftStroke, looking_up, STROKE_TIME);
            stroke();
            step_left_stroke();
        }
        else if (timer <= 0)
        {
            change_state(Right, looking_up, STROKE_TIME);
            step_right();
        }
        else if (looking_up and input.down_press)
            change_state(RightStroke, false, timer, timer, max(0.0, STROKE_TIME - timer));
        else if (!looking_up and input.up_press)
            change_state(RightStroke, true, timer, timer, max(0.0, STROKE_TIME - timer));
        else if (timer <= STROKE_CANCEL and input.dash_press)
            flip();
    }

    void step_left()
    {
        if (input.left_press)
        {
            change_state(LeftStroke, looking_up, STROKE_TIME);
            stroke();
            step_left_stroke();
        }
        if (input.right_press)
        {
            change_state(RightStroke, looking_up, STROKE_TIME);
            stroke();
            step_right_stroke();
        }
        else if (input.up_press)
            change_state(Idle, true, STROKE_TIME);
        else if (input.down_press)
            change_state(Idle, false, STROKE_TIME);
        else if (input.dash_press)
            flip();
    }

    void step_right()
    {
        if (input.left_press)
        {
            change_state(LeftStroke, looking_up, STROKE_TIME);
            stroke();
        }
        if (input.right_press)
        {
            change_state(RightStroke, looking_up, STROKE_TIME);
            stroke();
        }
        else if (input.up_press)
            change_state(Idle, true, STROKE_TIME);
        else if (input.down_press)
            change_state(Idle, false, STROKE_TIME);
        else if (input.dash_press)
            flip();
    }

    float power() const
    {
        return energy / MAX_ENERGY;
    }

    void stroke()
    {
        play_sound("splash" + formatInt(rand() % 4), 0.6);
        speed += power() * (forwards ? STROKE_SPEED : -STROKE_SPEED);
        energy = max(0.0, energy - STROKE_COST);
        heart_bpm = lerp(heart_bpm, 180, STROKE_COST / 10);

        switch (state)
        {
            case LeftStroke:
                left_arm_time = 0;
                break;
            case RightStroke:
                right_arm_time = 0;
                break;
        }
    }

    void flip()
    {
        play_sound("big_splash", 0.6);
        y_speed = -0.03;
        speed *= 0.7;
        flip_start_state = state;
        change_state(Flip, looking_up, FLIP_TIME, FLIP_TIME);
    }

    void step_flip()
    {
        if (timer <= 0)
        {
            change_state(Idle, true);
            step_idle();
            return;
        }

        float start_angle = prev_facing.pitch;
        float frac = ease_out_quad(1 - timer / timer_max);
        float angle = (start_angle + (2 * PI - start_angle) * frac) % (2 * PI);

        if (3 * PI / 4 < angle and angle < 3 * PI / 2 and input.jump_press and laps != 3)
        {
            if (( forwards and pos.z > POOL_LENGTH - JUMP_LEEWAY) or
                (!forwards and pos.z < JUMP_LEEWAY))
            {
                jump();
                return;
            }
        }

        Euler target;
        if (forwards)
        {
            if (angle <= PI / 2)
                target = Euler(0, angle, 0);
            else if (angle <= 3 * PI / 2)
                target = Euler(PI, PI - angle, PI);
            else if (angle <= 5 * PI / 2)
                target = Euler(0, angle, 0);
        }
        else
        {
            if (angle <= PI / 2)
                target = Euler(PI, angle, 0);
            else if (angle <= 3 * PI / 2)
                target = Euler(0, PI - angle, PI);
            else if (angle <= 5 * PI / 2)
                target = Euler(PI, angle, 0);
        }
        facing = facing.slerp(target, max(0.1, frac));
    }

    void jump()
    {
        y_speed = -0.04;
        laps += 1;
        forwards = !forwards;
        float new_speed = power() * max(abs(speed), JUMP_SPEED);
        speed = forwards ? abs(new_speed) : -abs(new_speed);
        energy = max(0.0, energy - JUMP_COST);
        heart_bpm = lerp(heart_bpm, 180, JUMP_COST / 10);
        change_state(Jump, false, JUMP_TIME, JUMP_TIME);
        step_jump();
    }

    void step_jump()
    {
        if (timer <= 0)
        {
            change_state(Idle, looking_up, STROKE_TIME, STROKE_TIME);
            return;
        }

        Euler upside_down = forwards ? Euler(0, 0, -PI) : Euler(PI, 0, -PI);
        Euler target = forwards ? Euler(0, 0, 0) : Euler(PI, 0, 0);
        facing = prev_facing.slerp(target, 1 - timer / timer_max);
    }

    void launch()
    {
        change_state(Launch, looking_up);
        speed = LAUNCH_SPEED;
        y_speed = LAUNCH_Y_SPEED;
    }

    void step_launch()
    {
        if (pos.y <= SWIM_HEIGHT)
        {
            play_sound("big_splash", 1.0);
            change_state(Idle, looking_up, STROKE_TIME, STROKE_TIME);
            step_jump();
            return;
        }
    }

    void step_legs()
    {
        if (leg_timer <= 0 and input.jump_press)
        {
            leg_timer = LEG_TIME;
            speed += power() * (forwards ? LEG_SPEED : -LEG_SPEED);
            energy = max(0.0, energy - LEG_COST);
            heart_bpm = lerp(heart_bpm, 180, LEG_COST / 10);
        }
    }

    void step_breath()
    {
        if (state == Drown)
        {
            global_volume = max(0.0, timer / RESPAWN_TIME);
            if (timer <= 0)
                g.load_checkpoint();
            return;
        }

        energy = max(0.0, energy - IDLE_COST * pow(heart_bpm / 60, 1.5));
        
        // Convert breath into energy
        float conversion = min(0.02, min(MAX_ENERGY - energy, breath));
        breath -= conversion;
        energy += conversion;

        // Breath if above water
        bool is_above_water = face_pos().y > 0;
        if (is_above_water)
        {
            // Make noise
            if (!was_above_water)
            {
                string sound;
                if (energy < 0.3 * MAX_ENERGY)
                    sound = "gasp";
                else if (energy < 0.6 * MAX_ENERGY)
                    sound = "intake";
                else
                    sound = "breath" + formatInt(rand() % 3);

                g.play_script_stream(sound, 0, 0, 0, false, 1 - breath / MAX_BREATH);
            }

            // Inhale
            float intake = was_above_water ? 0.02 : 0.8;
            float actual_intake = min(intake, MAX_BREATH - breath);
            breath += actual_intake;
        }
        was_above_water = is_above_water;

        // Dieeeee
        if (energy <= 0 and breath <= 0 and state != Win)
        {
            // Make sure the death sound effect is heard (because there is a max
            // number of streams, above which new sounds are just not played).
            cull_sounds();
            g.play_script_stream("die", 0, 0, 0, false, 1.0);
            change_state(Drown, false, RESPAWN_TIME, RESPAWN_TIME);
        }
    }

    void step_ears()
    {
        float face = face_pos().y;
        float left_ear = face + EAR_WIDTH * sin(facing.roll);
        float right_ear = face - EAR_WIDTH * sin(facing.roll);

        left_ear_volume = lerp(left_ear_volume, left_ear > 0 ? 1.0 : 0.0, 0.1);
        right_ear_volume = lerp(right_ear_volume, right_ear > 0 ? 1.0 : 0.0, 0.1);

        array<uint> finished;
        for (uint i = 0; i < active_sounds.size(); ++i)
        {
            if (!active_sounds[i].update(left_ear_volume, right_ear_volume, global_volume))
                finished.insertLast(i);
        }

        for (int i = finished.size() - 1; i >= 0; --i)
            active_sounds.removeAt(finished[i]);
    }

    void cull_sounds()
    {
        // Leave crowd noise and most recent sfx alone
        for (int i = 1; i < int(active_sounds.size()) - 1; ++i)
            active_sounds[i].stop();
    }

    void play_sound(string name, float volume, bool loop = false)
    {
        Sound sound(name, volume, loop);
        sound.play(left_ear_volume, right_ear_volume);
        active_sounds.insertLast(sound);
    }

    float perpendicular_distance_to(Vec3 point) const
    {
        Vec3 world = point - pos;
        Vec3 local = world.rotate_y(-facing.yaw).rotate_x(-facing.pitch);
        return local.z;
    }

    Mat4 view_matrix() const
    {
        return look_at_matrix(face_pos(), facing.yaw, facing.pitch, facing.roll);
    }

    void step_freecam()
    {
        scene@ g = get_scene();

        Vec3 vel;
        if (input.left_down) vel.x -= 0.1;
        if (input.right_down) vel.x += 0.1;
        if (input.down_down) vel.z -= 0.1;
        if (input.up_down) vel.z += 0.1;
        if (input.dash_down) vel.y -= 0.1;
        if (input.jump_down) vel.y += 0.1;
        pos += vel.rotate_x(facing.pitch).rotate_y(facing.yaw);

        float mouse_x = g.mouse_x_hud(0);
        float mouse_y = g.mouse_y_hud(0);
        if (g.mouse_state(0) & 4 > 0)
        {
            float dx = mouse_x - last_mouse_x;
            float dy = mouse_y - last_mouse_y;
            facing.yaw += dx / 100;
            facing.pitch += dy / 100;
        }
        last_mouse_x = mouse_x;
        last_mouse_y = mouse_y;
    }
}
