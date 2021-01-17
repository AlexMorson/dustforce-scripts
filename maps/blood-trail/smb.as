#include "inputs.as"

const float PI = 3.14159265359;

const string EMBED_run_sfx0 = "smb/sfx/run0.ogg";
const string EMBED_run_sfx1 = "smb/sfx/run1.ogg";
const string EMBED_run_sfx2 = "smb/sfx/run2.ogg";
const string EMBED_run_sfx3 = "smb/sfx/run3.ogg";
const string EMBED_run_sfx4 = "smb/sfx/run4.ogg";
const string EMBED_run_sfx5 = "smb/sfx/run5.ogg";
const int RUN_SFX_EMBEDS = 6;

const string EMBED_jump_sfx0 = "smb/sfx/jump0.ogg";
const string EMBED_jump_sfx1 = "smb/sfx/jump1.ogg";
const string EMBED_jump_sfx2 = "smb/sfx/jump2.ogg";
const string EMBED_jump_sfx3 = "smb/sfx/jump3.ogg";
const string EMBED_jump_sfx4 = "smb/sfx/jump4.ogg";
const int JUMP_SFX_EMBEDS = 5;

const string EMBED_death_sfx0 = "smb/sfx/death0.ogg";
const string EMBED_death_sfx1 = "smb/sfx/death1.ogg";
const string EMBED_death_sfx2 = "smb/sfx/death2.ogg";
const string EMBED_death_sfx3 = "smb/sfx/death3.ogg";
const string EMBED_death_sfx4 = "smb/sfx/death4.ogg";
const string EMBED_death_sfx5 = "smb/sfx/death5.ogg";
const string EMBED_death_sfx6 = "smb/sfx/death6.ogg";
const string EMBED_death_sfx7 = "smb/sfx/death7.ogg";
const int DEATH_SFX_EMBEDS = 8;

const string EMBED_impact_sfx0 = "smb/sfx/impact0.ogg";
const string EMBED_impact_sfx1 = "smb/sfx/impact1.ogg";
const string EMBED_impact_sfx2 = "smb/sfx/impact2.ogg";
const string EMBED_impact_sfx3 = "smb/sfx/impact3.ogg";
const string EMBED_impact_sfx4 = "smb/sfx/impact4.ogg";
const string EMBED_impact_sfx5 = "smb/sfx/impact5.ogg";
const string EMBED_impact_sfx6 = "smb/sfx/impact6.ogg";
const string EMBED_impact_sfx7 = "smb/sfx/impact7.ogg";
const string EMBED_impact_sfx8 = "smb/sfx/impact8.ogg";
const int IMPACT_SFX_EMBEDS = 9;

const string EMBED_respawn_sfx = "smb/sfx/respawn.ogg";
const string EMBED_warp_zone_sfx = "smb/sfx/warp_zone.ogg";
const string EMBED_whoosh_in_sfx = "smb/sfx/whoosh_in.ogg";
const string EMBED_whoosh_out_sfx = "smb/sfx/whoosh_out.ogg";
const string EMBED_bandage_sfx = "smb/sfx/bandage.ogg";

const string EMBED_run_img = "smb/img/run.png";
const string EMBED_wall_img = "smb/img/wall.png";
const string EMBED_idle_img = "smb/img/idle.png";
const string EMBED_fall_img = "smb/img/fall.png";
const string EMBED_smile_img = "smb/img/smile.png";
const string EMBED_foot_img = "smb/img/foot.png";
const string EMBED_hand_img = "smb/img/hand.png";
const string EMBED_thumb_img = "smb/img/thumb.png";
const string EMBED_warp_img = "smb/img/warp.png";
const string EMBED_bandage_img = "smb/img/bandage.png";

const string EMBED_portal0_img = "smb/img/portal0.png";
const string EMBED_portal1_img = "smb/img/portal1.png";
const string EMBED_portal2_img = "smb/img/portal2.png";
const string EMBED_portal3_img = "smb/img/portal3.png";
const string EMBED_portal4_img = "smb/img/portal4.png";
const string EMBED_portal5_img = "smb/img/portal5.png";
const string EMBED_portal6_img = "smb/img/portal6.png";
const int PORTAL_IMG_EMBEDS = 7;

const string EMBED_saw0_img = "smb/img/saw0.png";
const string EMBED_saw1_img = "smb/img/saw1.png";
const string EMBED_saw2_img = "smb/img/saw2.png";
const string EMBED_saw3_img = "smb/img/saw3.png";
const int SAW_IMG_EMBEDS = 4;

const string EMBED_girl0_img = "smb/img/girl0.png";
const string EMBED_girl1_img = "smb/img/girl1.png";
const int GIRL_IMG_EMBEDS = 2;

const int PHYSICS_STEPS = 5;
const float RUN_ACCEL = 0.035;
const float MAX_SPEED = 3.0;
const float GRAVITY_ACCEL = 0.02;
const float GRAVITY_WALL_ACCEL = 0.015;
const float JUMP_VEL = 2.8;
const float AIR_FRICTION = 0.99;
const float WALLJUMP_X_VEL = 2.4;
const float WALLJUMP_Y_VEL = 3.0;
const int WALLGRAB_HOLD = 30;

const int TOP = 1;
const int BOTTOM = 2;
const int RIGHT = 4;
const int LEFT = 8;

enum State
{
    IDLE,
    JUMP,
    FALL
}

class MeatBoy : enemy_base, callback_base
{
    scene@ g;
    scriptenemy@ self;
    sprites@ spr;

    float x, y;     // position
    float px, py;   // prev position
    float cx, cy;   // checkpoint position
    bool taunt = false;
    [text] int face = 1;

    // Have to store these manually because the built-in versions are reset on checkpoint load
    [text] float vx;
    [text] float vy;
    [text] State state;
    [text] bool ground;
    [text] bool roof;
    [text] bool wall_left;
    [text] bool wall_right;

    // only used for sound effects
    int prev_state;
    bool prev_ground, prev_roof, prev_wall_left, prev_wall_right, prev_taunt;

    [text] int wall_timer = 0;     // stick to walls
    [text] int run_timer = 0;      // space out footstep sounds
    [text] int respawn_timer = 0;  // wait to respawn
    [text] int frame_timer = 0;    // what frame is this

    void init(script@ s, scriptenemy@ self)
    {
        @g = get_scene();
        @spr = create_sprites();
        spr.add_sprite_set("script");

        @this.self = self;
        self.life(3);
        self.auto_physics(false);
        self.on_hurt_callback(this, "on_hurt", 0);

        add_broadcast_receiver("hit_deathzone", this, "hit_deathzone");
        add_broadcast_receiver("hit_saw", this, "hit_deathzone");
        add_broadcast_receiver("please_taunt", this, "please_taunt");
    }

    void step()
    {
        x = px = self.x();
        y = py = self.y() + 24;

        ++frame_timer;

        if (respawn_timer > 0)
        {
            if (respawn_timer == 30)
            {
                if (self.player_index() == -1) g.end_level(0, 0);
            }
            if (--respawn_timer == 20)
            {
                respawn();
            }
        }
        else
        {
            for (int i=0; i<PHYSICS_STEPS; ++i)
            {
                physics_step();
            }

            sound_effects();

            prev_state = state;
            prev_ground = ground;
            prev_roof = roof;
            prev_wall_left = wall_left;
            prev_wall_right = wall_right;
            prev_taunt = taunt;
        }

        // Update the scriptenemy position
        self.x(x);
        self.y(y - 24);

        // Make the camera preempt the movement
        self.set_speed_xy(60 * PHYSICS_STEPS * vx, 60 * PHYSICS_STEPS * vy);

        // Let the camera break
        self.ground(ground);
    }

    void physics_step()
    {
        switch (self.x_intent())
        {
            case 0:
                if (state == IDLE)
                {
                    vx = 0;
                    if (self.taunt_intent() > 0) taunt = true;
                }
                break;
            case -1:
                face = -1;
                taunt = false;
                if (state == IDLE and vx > 0) vx = 0;
                vx = max(min(AIR_FRICTION * vx, vx) - RUN_ACCEL, -MAX_SPEED);
                break;
            case 1:
                face = 1;
                taunt = false;
                if (state == IDLE and vx < 0) vx = 0;
                vx = min(max(AIR_FRICTION * vx, vx) + RUN_ACCEL, MAX_SPEED);
                break;
        }

        if (self.jump_intent() == 1)
        {
            taunt = false;
            if (state == IDLE)
            {
                state = JUMP;
                vy = -JUMP_VEL;
            }

            if (not ground)
            {
                if (wall_right and not wall_left)
                {
                    face = -1;
                    vx = -WALLJUMP_X_VEL;
                    vy = -WALLJUMP_Y_VEL;
                    state = JUMP;
                    wall_timer = 0;
                }

                if (wall_left and not wall_right)
                {
                    face = 1;
                    vx = WALLJUMP_X_VEL;
                    vy = -WALLJUMP_Y_VEL;
                    state = JUMP;
                    wall_timer = 0;
                }

                if (wall_left and wall_right)
                {
                    vy = -WALLJUMP_Y_VEL;
                    state = JUMP;
                    wall_timer = 0;
                }
            }

            self.jump_intent(2);
        }

        if (state == JUMP or state == FALL)
        {
            if (wall_left or wall_right) vy += GRAVITY_WALL_ACCEL;
            else                         vy += GRAVITY_ACCEL;
        }

        if (state == JUMP)
        {
            if (self.jump_intent() == 0) vy *= 0.6;
            if (vy >= 0) state = FALL;
        }

        x += vx;
        y += vy;

        collide_ground();
        collide_roof();
        collide_left();
        collide_right();
    }

    void collide_ground()
    {
        raycast@ sweep = collision_ground(g, x-22, y-12, x+22, y+1);
        ground = sweep.hit();
        if (ground)
        {
            if (vy >= 0)
            {
                y = min(y, sweep.hit_y());
                vy = 0;
                state = IDLE;
            }

            if (respawn_timer == 0)
            {
                tilefilth@ filth = g.get_tile_filth(sweep.tile_x(), sweep.tile_y());
                int filth_top = filth.top();
                if (9 <= filth_top and filth_top <= 13) die();
            }

            g.project_tile_filth(x, y-24, 48, 48, 4, 180, 48, 45, true, false, false, false, false, false);
        }
        else 
        {
            if (state == IDLE) state = FALL;
        }
    }

    void collide_roof()
    {
        raycast@ sweep = collision_roof(g, x-22, y-36, x+22, y-49);
        roof = sweep.hit();
        if (roof and vy <= 0)
        {
            y = max(y, sweep.hit_y() + 48);
            vy = 0;
            if (state == JUMP) state = FALL;

            if (respawn_timer == 0)
            {
                tilefilth@ filth = g.get_tile_filth(sweep.tile_x(), sweep.tile_y());
                int filth_bottom = filth.bottom();
                if (9 <= filth_bottom and filth_bottom <= 13) die();
            }

            g.project_tile_filth(x, y-24, 2*48, 48, 4, 0, 48, 0, false, true, false, false, false, false);
        }
    }

    void collide_right()
    {
        raycast@ sweep = collision_right(g, x, y-46, x+25.1, y-2);
        wall_right = sweep.hit();
        if (wall_right)
        {
            if (vx >= 0)
            {
                wall_timer = WALLGRAB_HOLD;
                x = sweep.hit_x() - 24;
                vx = 0;
            }
            else if (not ground and wall_timer > 0)
            {
                --wall_timer;
                x = sweep.hit_x() - 24;
                vx = 0;
            }

            if (respawn_timer == 0)
            {
                tilefilth@ filth = g.get_tile_filth(sweep.tile_x(), sweep.tile_y());
                int filth_left = filth.left();
                if (9 <= filth_left and filth_left <= 13) die();
            }

            g.project_tile_filth(x, y-24, 48, 48, 4, 90, 48, 45, false, false, true, false, false, false);
        }
    }

    void collide_left()
    {
        raycast@ sweep = collision_left(g, x, y-46, x-25.1, y-2);
        wall_left = sweep.hit();
        if (wall_left)
        {
            if (vx <= 0)
            {
                wall_timer = WALLGRAB_HOLD;
                x = sweep.hit_x() + 24;
                vx = 0;
            }
            else if (not ground and wall_timer > 0)
            {
                --wall_timer;
                x = sweep.hit_x() + 24;
                vx = 0;
            }

            if (respawn_timer == 0)
            {
                tilefilth@ filth = g.get_tile_filth(sweep.tile_x(), sweep.tile_y());
                int filth_right = filth.right();
                if (9 <= filth_right and filth_right <= 13) die();
            }

            g.project_tile_filth(x, y-24, 48, 48, 4, 270, 48, 45, false, false, false, true, false, false);
        }
    }

    void on_hurt(controllable@ attacked, controllable@ attacker, hitbox@ attack_hitbox, int arg)
    {
        splat();
        self.life(self.life() - attack_hitbox.damage());
        if (self.life() <= 0) die();
    }

    void hit_deathzone(string, message@ msg)
    {
        if (respawn_timer == 0) die();
    }

    void please_taunt(string, message@ msg)
    {
        self.taunt_intent(1);
    }

    void die()
    {
        splat();
        g.play_script_stream("death"+rand()%DEATH_SFX_EMBEDS, 0, 0, 0, false, 0.25 * volume_multiplier());
        broadcast_message("meat_boy_die", create_message());
        respawn_timer = 30;

        if (self.player_index() != -1)
        {
            g.combo_break_count(g.combo_break_count() + 1);
        }
    }

    void respawn()
    {
        x = cx;
        y = cy;
        vx = 0;
        vy = 0;
        ground = true;
        roof = false;
        wall_left = false;
        wall_right = false;
        face = 1;
        taunt = false;
        inverse_splat();
        g.play_script_stream("respawn", 0, 0, 0, false, 0.8 * volume_multiplier());
    }

    void splat()
    {
        g.add_entity(create_emitter(19, 20, 90, x, y-24, 96, 96, 0));
    }

    void inverse_splat()
    {
        g.add_entity(create_emitter(19, 20, 34, x   , y+24, 48, 48, 0));
        g.add_entity(create_emitter(19, 20, 34, x-48, y-24, 48, 48, 90));
        g.add_entity(create_emitter(19, 20, 34, x+48, y-24, 48, 48, -90));
        g.add_entity(create_emitter(19, 20, 34, x   , y-72, 48, 48, 180));
    }

    float volume_multiplier()
    {
        camera@ c = get_camera(0);
        float d = pow(pow(x-c.x(), 2) + pow(y-c.y(), 2), 0.2);
        return max(0.0, min(1.0, 1 - (d - 10) / 11));
    }

    void sound_effects()
    {
        if ((not prev_ground     and ground    ) or
            (not prev_roof       and roof      ) or
            (not prev_wall_left  and wall_left ) or
            (not prev_wall_right and wall_right))
        {
            g.play_script_stream("impact"+rand()%IMPACT_SFX_EMBEDS, 0, 0, 0, false, 0.2 * volume_multiplier());
        }

        if (prev_state != JUMP and state == JUMP)
        {
            g.play_script_stream("jump"+rand()%JUMP_SFX_EMBEDS, 0, 0, 0, false, 0.3 * volume_multiplier());
        }

        if (state == IDLE and self.x_intent() != 0 and --run_timer <= 0)
        {
            g.play_script_stream("run"+rand()%RUN_SFX_EMBEDS, 0, 0, 0, false, 0.15 * volume_multiplier());
            run_timer = 5;
        }

        if (not prev_taunt and taunt)
        {
            g.play_script_stream("impact"+rand()%IMPACT_SFX_EMBEDS, 0, 0, 0, false, 0.5 * volume_multiplier());
            g.add_entity(create_emitter(19, 20, 90, x+12*face, y-24, 24, 24, 0));
        }
    }

    void draw(float sub_frame)
    {
        if (respawn_timer > 0) return;

        float ix = px + (x - px) * sub_frame;
        float iy = py + (y - py) * sub_frame;
        float sub_frame_timer = frame_timer + sub_frame;

        if (ground)
        {
            if (self.x_intent() == 0)
            {
                float idle_bob = 1.5 * abs(sin(sub_frame_timer / 10.0));
                spr.draw_world(18, 20, "foot", 0, 0, ix+10, iy-2, 0, face, 1, 0xFF000000 + (face == -1 ? 0xDDDDDD : 0xBBBBBB));
                spr.draw_world(18, 20, "foot", 0, 0, ix-10, iy-2, 0, face, 1, 0xFF000000 + (face ==  1 ? 0xDDDDDD : 0xBBBBBB));
                if (taunt)
                {
                    spr.draw_world(18, 20, "smile", 0, 0, ix, iy-idle_bob, 0, face, 1, 0xFFFFFFFF);
                    if (face == 1)
                    {
                        spr.draw_world(18, 19, "thumb", 0, 0, ix+18, iy-idle_bob-18,   0,  1, 1, 0xFFBBBBBB);
                        spr.draw_world(18, 20, "hand" , 0, 0, ix-18, iy-idle_bob-18, -80, -1, 1, 0xFFEEEEEE);
                    }
                    else
                    {
                        spr.draw_world(18, 20, "hand" , 0, 0, ix+18, iy-idle_bob-18, 80, 1, 1, 0xFFEEEEEE);
                        spr.draw_world(18, 19, "thumb", 0, 0, ix-18, iy-idle_bob-18, 0, -1, 1, 0xFFBBBBBB);
                    }
                }
                else
                {
                    spr.draw_world(18, 20, "idle", 0, 0, ix, iy-idle_bob, 0, face, 1, 0xFFFFFFFF);
                    spr.draw_world(18, face == -1 ? 20 : 19, "hand", 0, 0, ix+18, iy-idle_bob-18,  80,  1, 1, 0xFF000000 + (face == -1 ? 0xEEEEEE : 0xBBBBBB));
                    spr.draw_world(18, face ==  1 ? 20 : 19, "hand", 0, 0, ix-18, iy-idle_bob-18, -80, -1, 1, 0xFF000000 + (face ==  1 ? 0xEEEEEE : 0xBBBBBB));
                }
            }
            else
            {
                float run_bob = 4 * abs(sin(sub_frame_timer / 3.0));
                float foot_offset = 12 * sin(sub_frame_timer / 3.0);
                spr.draw_world(18, 20, "foot", 0, 0, ix+foot_offset, iy-2, -foot_offset, face, 1, 0xFFBBBBBB);
                spr.draw_world(18, 20, "foot", 0, 0, ix-foot_offset, iy-2, foot_offset, face, 1, 0xFFDDDDDD);
                spr.draw_world(18, 20, "run", 0, 0, ix, iy - run_bob, 0, face, 1, 0xFFFFFFFF);
                spr.draw_world(18, face == -1 ? 20 : 19, "hand", 0, 0, ix+12, iy-run_bob-20,  5*foot_offset+110,  1, 1, 0xFF000000 + (face == -1 ? 0xEEEEEE : 0xBBBBBB));
                spr.draw_world(18, face ==  1 ? 20 : 19, "hand", 0, 0, ix-12, iy-run_bob-20, -5*foot_offset-110, -1, 1, 0xFF000000 + (face ==  1 ? 0xEEEEEE : 0xBBBBBB));
            }
        }
        else if (wall_left)
        {
            spr.draw_world(18, 20, "foot", 0, 0, ix-12, iy-2, 10, 1, 1, 0xFFBBBBBB);
            spr.draw_world(18, 20, "foot", 0, 0, ix-20, iy, 10, 1, 1, 0xFFDDDDDD);
            spr.draw_world(18, 20, "wall", 0, 0, ix, iy, 0, 1, 1, 0xFFFFFFFF);
            spr.draw_world(18, 20, "hand", 0, 0, ix-18, iy-24, 80, -1, 1, 0xFFEEEEEE);
        }
        else if (wall_right)
        {
            spr.draw_world(18, 20, "foot", 0, 0, ix+12, iy-2, -10, -1, 1, 0xFFBBBBBB);
            spr.draw_world(18, 20, "foot", 0, 0, ix+20, iy, -10, -1, 1, 0xFFDDDDDD);
            spr.draw_world(18, 20, "wall", 0, 0, ix, iy, 0, -1, 1, 0xFFFFFFFF);
            spr.draw_world(18, 20, "hand", 0, 0, ix+18, iy-24, -80, 1, 1, 0xFFEEEEEE);
        }
        else
        {
            float angle = 10 / (1 + pow(2, -vy)) - 5;
            spr.draw_world(18, 20, "foot", 0, 0, ix+12, iy, face*angle-10, face, 1, 0xFF000000 + (face == -1 ? 0xDDDDDD : 0xBBBBBB));
            spr.draw_world(18, 20, "foot", 0, 0, ix-12, iy, face*angle+10, face, 1, 0xFF000000 + (face ==  1 ? 0xDDDDDD : 0xBBBBBB));
            spr.draw_world(18, 20, "fall", 0, 0, ix, iy, -face*angle, face, 1, 0xFFFFFFFF);
            spr.draw_world(18, face == -1 ? 20 : 19, "hand", 0, 0, ix+18, iy-18, -10*angle+30,  1, 1, 0xFF000000 + (face == -1 ? 0xEEEEEE : 0xBBBBBB));
            spr.draw_world(18, face ==  1 ? 20 : 19, "hand", 0, 0, ix-18, iy-18,  10*angle-30, -1, 1, 0xFF000000 + (face ==  1 ? 0xEEEEEE : 0xBBBBBB));
        }
    }

    controllable@ as_controllable()
    {
        return self.as_controllable();
    }
}

class PlayIntents
{
    [hidden] uint position = 0;
    [hidden] uint segment = 0;
    [hidden] uint triggered = 0;
    array<array<int>> x_intents;
    array<array<int>> jump_intents;

    void init(string data)
    {
        array<string> segments = data.split("#\n");
        uint size = segments.size();
        x_intents.resize(size);
        jump_intents.resize(size);

        for (uint i=0; i<segments.size(); ++i)
        {
            array<string> intents = segments[i].split(",");
            size = intents.size();
            x_intents[i].resize(size);
            jump_intents[i].resize(size);

            for (uint j=0; j<size; ++j)
            {
                string s = intents[j];
                x_intents[i][j] = (s[0] - 48) - 1;
                jump_intents[i][j] = (s[1] - 48);
            }
        }
    }

    void step(controllable@ p)
    {
        uint segment_size = x_intents[segment].size();
        if (position < segment_size)
        {
            p.x_intent(x_intents[segment][position]);
            p.jump_intent(jump_intents[segment][position]);
            ++position;
        }
        else
        {
            p.x_intent(x_intents[segment][segment_size-1]);
            p.jump_intent(jump_intents[segment][segment_size-1]);
        }

        if (position >= segment_size and segment < triggered)
        {
            ++segment;
            position = 0;
        }
    }
}

class RecordIntents
{
    uint size = 0;
    uint reserved = 1;
    array<int> x_intents(reserved);
    array<int> jump_intents(reserved);

    void step(controllable@ p)
    {
        if (size + 1 > reserved)
        {
            reserved *= 2;
            x_intents.resize(reserved);
            jump_intents.resize(reserved);
        }

        x_intents[size] = p.x_intent();
        jump_intents[size] = p.jump_intent();
        ++size;
    }

    void print()
    {
        string output = "";
        for (uint i=0; i<size; ++i)
        {
            output += (x_intents[i] + 1) + "" + jump_intents[i] + ",";
        }
        puts(output);
    }
}

class SegmentTrigger : trigger_base
{
    [text] uint segment = 0;

    void activate(controllable@ c)
    {
        if (c.player_index() != -1)
        {
            message@ msg = create_message();
            msg.set_int("segment", segment);
            broadcast_message("play_segment", msg);
        }
    }
}

class PortalTrigger : trigger_base
{
    scene@ g;
    sprites@ spr;
    scripttrigger@ self;
    int f = 0;
    bool triggered = false;

    PortalTrigger()
    {
        @g = get_scene();
        @spr = create_sprites();
        spr.add_sprite_set("script");
    }

    void init(script@ s, scripttrigger@ self)
    {
        @this.self = self;
        self.radius(50);
        self.square(true);
        self.editor_show_radius(false);
        self.editor_colour_active(0);
        self.editor_colour_inactive(0);
        self.x(48.0 * round(self.x() / 48.0));
        self.y(48.0 * round(self.y() / 48.0));
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1 and not triggered)
        {
            triggered = true;
            broadcast_message("start_cutscene", create_message());
            c.as_dustman().combo_timer(1e20);
            g.override_stream_sizes(48, 8); // prepare yourself...
            g.save_checkpoint(0, 0);
        }
    }

    void step()
    {
        ++f;
    }

    void draw(float sub_frame)
    {
        int i = (f / 10) % PORTAL_IMG_EMBEDS;
        spr.draw_world(18, 1, "portal"+i, 0, 0, self.x(), self.y(), 0, 1, 1, 0xFFFFFFFF);
    }

    void editor_draw(float sub_frame)
    {
        draw(sub_frame);
    }
}

class DeathTrigger : trigger_base
{
    void activate(controllable@ c)
    {
        if (c.player_index() != -1)
        {
            broadcast_message("hit_deathzone", create_message());
        }
    }
}

class SawTrigger : trigger_base
{
    scene@ g;
    sprites@ spr;
    scripttrigger@ self;

    int f = 0;
    int cooldown = 0;
    int state = 0;

    SawTrigger()
    {
        @g = get_scene();
        @spr = create_sprites();
        spr.add_sprite_set("script");
    }

    void init(script@ s, scripttrigger@ self)
    {
        @this.self = self;
    }

    void step()
    {
        ++f;
        if (cooldown > 0) --cooldown;
    }

    void draw(float sub_frame)
    {
        float scale = self.radius() / 90.0;
        float angle = 10 * (f + sub_frame);
        spr.draw_world(19, 5, "saw" + state, 0, 0, self.x(), self.y(), angle, scale, scale, 0xFFFFFFFF);
    }

    void editor_draw(float sub_frame)
    {
        draw(0);
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1 and cooldown == 0)
        {
            broadcast_message("hit_saw", create_message());
            cooldown = 30;
            state = int(min(3, state + 1));
        }
    }
}

class BandageTrigger : trigger_base, callback_base
{
    scene@ g;
    sprites@ spr;
    scripttrigger@ self;

    bool collected = false;
    bool counted = false;

    BandageTrigger()
    {
        @g = get_scene();
        @spr = create_sprites();
        spr.add_sprite_set("script");

        add_broadcast_receiver("meat_boy_die", this, "meat_boy_die");
        add_broadcast_receiver("end_warp_level", this, "end_warp_level");
    }

    void init(script@ s, scripttrigger@ self)
    {
        @this.self = self;
        self.radius(15);
        self.square(false);
        self.editor_show_radius(false);
    }

    void draw(float sub_frame)
    {
        if (not collected)
        {
            spr.draw_world(18, 1, "bandage", 0, 0, self.x(), self.y(), 0, 0.8, 0.8, 0xFFFFFFFF);
        }
    }

    void editor_draw(float sub_frame)
    {
        draw(sub_frame);
    }

    void activate(controllable@ c)
    {
        if (c.player_index() != -1 and not collected)
        {
            collected = true;
            g.play_script_stream("bandage", 0, 0, 0, false, 0.3);
            g.add_entity(create_emitter(18, 5, 68, self.x(), self.y(), 20, 20, 0));
        }
    }

    void meat_boy_die(string, message@ msg)
    {
        if (collected) g.add_entity(create_emitter(18, 5, 68, self.x(), self.y(), 20, 20, 0));
        collected = false;
    }

    void end_warp_level(string, message@ msg)
    {
        if (collected and not counted)
        {
            broadcast_message("collected_bandage", create_message());
            counted = true;
        }
    }
}

class BandageGirlTrigger : trigger_base
{
    [text] bool face_right = true;
    sprites@ spr;
    scripttrigger@ self;
    int f = 0;

    void init(script@ s, scripttrigger@ self)
    {
        @spr = create_sprites();
        spr.add_sprite_set("script");

        @this.self = self;
        self.radius(30);
        self.square(true);
        self.y(round((self.y() - 20) / 48.0) * 48.0 + 20);
    }

    void step()
    {
        ++f;
    }

    void draw(float sub_frame)
    {
        int i = (f / 30) % 2;
        float scale = 3.0 / 4;
        int flip = face_right ? 1 : -1;
        spr.draw_world(18, 1, "girl"+i, 0, 0, self.x(), self.y(), 0, flip * scale, scale, 0xFFFFFFFF);
    }

    void editor_draw(float sub_frame)
    {
        draw(sub_frame);
    }

    void activate(controllable@ c)
    {
        broadcast_message("end_warp_level", create_message());
    }
}

class Cutscene
{
    scene@ g;
    sprites@ spr;

    array<int> sizes = {
        15, 150, 15, 30, 15, // Warp zone
        15, 3, 15,           // Screen wipe
        90, 60, 30, 30, 60   // Heart transition
    };
    int state = -1;
    int timer = 0;
    int f = 0;

    Cutscene()
    {
        @g = get_scene();
        @spr = create_sprites();
    }

    void init()
    {
        spr.add_sprite_set("script");
        dustman@ d = controller_controllable(0).as_dustman();
        if (d !is null) spr.add_sprite_set(d.character());
    }

    void step()
    {
        if (state != -1)
        {
            ++f;
            if (--timer == 0)
            {
                if (state == 1) broadcast_message("become_meat_boy", create_message());
                if (state == 5) broadcast_message("next_warp_level", create_message());
                if (state == 6) g.play_script_stream("whoosh_out", 0, 0, 0, false, 0.3);
                if (state == 8) broadcast_message("please_taunt", create_message());
                if (state == 10) broadcast_message("lovely_ending", create_message());
                if (state == 12) broadcast_message("check_true_end", create_message());

                if (state == 4 or state == 7 or state == 12) state = -1;
                else timer = sizes[++state];
            }
        }
    }

    void draw_background(float opacity)
    {
        uint colour = int(0xFF * opacity) << 24;
        g.draw_rectangle_hud(12, 0, -800, -450, 800, 450, 0, colour);
    }

    void draw_ring(int sublayer, float x, float y, float size, float speed, uint colour)
    {
        spr.draw_hud(12, sublayer, "warp", 0, 0, x, y, speed * f,  size,  size, colour);
        spr.draw_hud(12, sublayer, "warp", 0, 0, x, y, speed * f, -size,  size, colour);
        spr.draw_hud(12, sublayer, "warp", 0, 0, x, y, speed * f, -size, -size, colour);
        spr.draw_hud(12, sublayer, "warp", 0, 0, x, y, speed * f,  size, -size, colour);
    }

    void draw_rings(float opacity)
    {
        uint colour = uint(0xFF * opacity) << 24;
        draw_ring(5, -30,    0, 1.7,  4, colour + 0xFFFFFF);
        draw_ring(4,   0,  -30, 1.2, -4, colour + 0xDDDDDD);
        draw_ring(3,  30,  -60, 0.8,  4, colour + 0xBBBBBB);
        draw_ring(2,  45,  -90, 0.5, -4, colour + 0x888888);
        draw_ring(1,  60, -110, 0.3,  4, colour + 0x555555);
    }

    void screen_wipe(float l, float r)
    {
        l = 1600 * l - 800;
        r = 1600 * r - 800;
        g.draw_rectangle_hud(12, 0, l, -450, r, 450, 0, 0xFF000000);
    }

    void draw_heart(float scale)
    {
        if (scale < 3)
        {
            draw_background(1);
            return;
        }

        const float a = PI / 5;
        const float r = 900;
        const int segments = 8;

        canvas@ c = create_canvas(true, 12, 0);
        c.translate(410, 230);
        c.scale(scale, scale);

        int state = 0;
        for (int i = 0; i < segments; ++i)
        {
            float t1 = PI * (i / float(segments));
            float t2 = PI * ((i + 1) / float(segments));
            float x1 =  sin(t1);
            float y1 = -cos(t1 - a);
            float x2 =  sin(t2);
            float y2 = -cos(t2 - a);
            if (state == 0)
            {
                // Drawing everything twice to avoid the mad quad bug...
                c.draw_quad(
                    false,
                    x1, y1, x2, y2,
                    x2, -r, x1, -r,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    x1, y1, x2, y2,
                    x2, -r, x1, -r,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    -x2, y2, -x1, y1,
                    x1, -r, x2, -r,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    -x2, y2, -x1, y1,
                    x1, -r, x2, -r,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );

                if (t1 > a)
                {
                    c.draw_quad(
                        false,
                        x2, y2, r, y2,
                        r, -r, x2, -r,
                        0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                    );
                    c.draw_quad(
                        false,
                        x2, y2, r, y2,
                        r, -r, x2, -r,
                        0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                    );
                    c.draw_quad(
                        false,
                        -x2, y2, x2, -r,
                        -r, -r, -r, y2,
                        0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                    );
                    c.draw_quad(
                        false,
                        -x2, y2, x2, -r,
                        -r, -r, -r, y2,
                        0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                    );
                    state = 1;
                }
            }
            else
            {
                c.draw_quad(
                    false,
                    x1, y1, x2, y2,
                    r, y2, r, y1,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    x1, y1, x2, y2,
                    r, y2, r, y1,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    -x2, y2, -x1, y1,
                    -r, y1, -r, y2,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
                c.draw_quad(
                    false,
                    -x2, y2, -x1, y1,
                    -r, y1, -r, y2,
                    0xFF000000, 0xFF000000, 0xFF000000, 0xFF000000
                );
            }
        }

        c.draw_rectangle(-900, -cos(PI - a) - 1/scale, 900, 450, 0, 0xFF000000);
    }

    void draw(float sub_frame)
    {
        if (state == -1) return;

        float t = (timer - sub_frame) / float(sizes[state]);

        switch (state)
        {
            case 0: // Fade in
            {
                draw_background(1 - t);
                draw_rings(1 - t);

                float angle = 5 * f;
                spr.draw_hud(12, 6, "stun1", 0, 0, 200, 400, angle, 5, 5, 0xFFFFFFFF);

                break;
            }
            case 1: // Player fall into portal
            {
                draw_background(1);
                draw_rings(1);

                float x = 200 * t +   60 * (1 - t);
                float y = 400 * t + -110 * (1 - t);
                float angle = 5 * f;
                float scale = 5 * t;
                uint colour = (0xFF << 24) + uint((0.8 * t + 0.2) * 0xFF) * 0x010101;
                spr.draw_hud(12, 6, "stun1", 0, 0, x, y, angle, scale, scale, colour);

                break;
            }
            case 2: // Fade out portal
            {
                draw_background(1);
                draw_rings(t);
                break;
            }
            case 3: // Hold on black
            {
                draw_background(1);
                break;
            }
            case 4: // Fade out
            {
                draw_background(t);
                break;
            }

            case 5: // End level screen wipe in
            {
                screen_wipe(t, 1);
                break;
            }
            case 6: // Hold black
            {
                screen_wipe(0, 1);
                break;
            }
            case 7: // Screen wipe out
            {
                screen_wipe(0, t);
                break;
            }

            case 8: // Heart in
            {
                draw_heart(2000 * pow(t, 5) + 200);
                break;
            }
            case 9: // Framed
            {
                draw_heart(200);
                break;
            }
            case 10: // Close
            {
                draw_heart(200 * (1 - pow(1-t, 5)));
                break;
            }
            case 11: // Hold on black
            {
                draw_background(1);
                break;
            }
            case 12: // Fade out
            {
                draw_background(t);
                break;
            }
        }
    }

    void warp_zone()
    {
        if (state == -1)
        {
            g.play_script_stream("warp_zone", 0, 0, 0, false, 0.3);
            state = 0;
            timer = sizes[0];
        }
    }

    void next_level()
    {
        if (state == -1)
        {
            g.play_script_stream("whoosh_in", 0, 0, 0, false, 0.3);
            state = 5;
            timer = sizes[5];
        }
    }

    void heart_out()
    {
        if (state == -1)
        {
            state = 8;
            timer = sizes[8];
        }
    }

    bool active()
    {
        return state != -1;
    }
}

class WarpLevel
{
    [position,mode:world,layer:19,y:spawn_y] float spawn_x;
    [hidden] float spawn_y;
    [position,mode:world,layer:19,y:top] float left;
    [hidden] float top;
    [position,mode:world,layer:19,y:bottom] float right;
    [hidden] float bottom;
    [hidden] array<Tile> surfaces;

    void init()
    {
        int tx1 = int(round(left   / 48.0));
        int ty1 = int(round(top    / 48.0));
        int tx2 = int(round(right  / 48.0));
        int ty2 = int(round(bottom / 48.0));

        left   = 48 * tx1;
        top    = 48 * ty1;
        right  = 48 * tx2;
        bottom = 48 * ty2;

        scene@ g = get_scene();
        surfaces.resize(0);
        for (int ty=ty1; ty<ty2; ++ty)
        {
            for (int tx=tx1; tx<tx2; ++tx)
            {
                tileinfo@ t = g.get_tile(tx, ty);
                if (t.edge_left() & 8 > 0 or t.edge_top() & 8 > 0 or t.edge_right() & 8 > 0 or t.edge_bottom() & 8 > 0)
                {
                    surfaces.insertLast(Tile(tx, ty));
                }
            }
        }
    }

    void clear_filth()
    {
        scene@ g = get_scene();
        for (uint i=0; i<surfaces.size(); ++i)
        {
            Tile@ t = surfaces[i];
            g.set_tile_filth(t.x, t.y, 0, 0, 0, 0, false, false);
        }
    }

    void draw()
    {
        scene@ g = get_scene();
        g.draw_rectangle_world(22, 0, left, top, right, bottom, 0, 0x22000000);
        for (uint i=0; i<surfaces.size(); ++i)
        {
            Tile@ t = surfaces[i];
            g.draw_rectangle_world(22, 0, 48*t.x, 48*t.y, 48*t.x+48, 48*t.y+48, 0, 0x88000000);
        }
    }
}

class Tile
{
    [text] int x;
    [text] int y;

    Tile() {}
    Tile(int x, int y)
    {
        this.x = x;
        this.y = y;
    }
}

class script : callback_base
{
    [text] array<WarpLevel> warp_levels;

    scene@ g;

    [hidden] PlayIntents intents;
    Cutscene cutscene;

    MeatBoy@ meat_boy;
    int meat_boy_id;

    int warp_level = 0;
    int bandages = 0;

    script()
    {
        @g = get_scene();
        g.layer_visible(1, true);
        g.override_stream_sizes(16, 8);

        add_broadcast_receiver("play_segment", this, "play_segment");
        add_broadcast_receiver("start_cutscene", this, "start_cutscene");
        add_broadcast_receiver("become_meat_boy", this, "become_meat_boy");
        add_broadcast_receiver("end_warp_level", this, "end_warp_level");
        add_broadcast_receiver("next_warp_level", this, "next_warp_level");
        add_broadcast_receiver("collected_bandage", this, "collected_bandage");
        add_broadcast_receiver("lovely_ending", this, "lovely_ending");
        add_broadcast_receiver("check_true_end", this, "check_true_end");
    }

    void build_sounds(message@ msg)
    {
        for (int i=0; i<RUN_SFX_EMBEDS   ; ++i) msg.set_string("run"   +i, "run_sfx"   +i);
        for (int i=0; i<JUMP_SFX_EMBEDS  ; ++i) msg.set_string("jump"  +i, "jump_sfx"  +i);
        for (int i=0; i<DEATH_SFX_EMBEDS ; ++i) msg.set_string("death" +i, "death_sfx" +i);
        for (int i=0; i<IMPACT_SFX_EMBEDS; ++i) msg.set_string("impact"+i, "impact_sfx"+i);
        msg.set_string("respawn", "respawn_sfx");
        msg.set_string("warp_zone", "warp_zone_sfx");
        msg.set_string("whoosh_in", "whoosh_in_sfx");
        msg.set_string("whoosh_out", "whoosh_out_sfx");
        msg.set_string("bandage", "bandage_sfx");
    }

    void build_sprites(message@ msg)
    {
        msg.set_string("run", "run_img");
        msg.set_int("run|offsetx", 24);
        msg.set_int("run|offsety", 48);

        msg.set_string("wall", "wall_img");
        msg.set_int("wall|offsetx", 24);
        msg.set_int("wall|offsety", 48);

        msg.set_string("idle", "idle_img");
        msg.set_int("idle|offsetx", 24);
        msg.set_int("idle|offsety", 48);

        msg.set_string("fall", "fall_img");
        msg.set_int("fall|offsetx", 24);
        msg.set_int("fall|offsety", 48);

        msg.set_string("smile", "smile_img");
        msg.set_int("smile|offsetx", 24);
        msg.set_int("smile|offsety", 48);

        msg.set_string("foot", "foot_img");
        msg.set_int("foot|offsetx", 5);
        msg.set_int("foot|offsety", 11);

        msg.set_string("hand", "hand_img");
        msg.set_int("hand|offsetx", 0);
        msg.set_int("hand|offsety", 8);

        msg.set_string("thumb", "thumb_img");
        msg.set_int("thumb|offsetx", -4);
        msg.set_int("thumb|offsety", 12);

        msg.set_string("warp", "warp_img");
        msg.set_int("warp|offsetx", 73);
        msg.set_int("warp|offsety", 73);

        msg.set_string("bandage", "bandage_img");
        msg.set_int("bandage|offsetx", 29);
        msg.set_int("bandage|offsety", 20);

        for (int i=0; i<PORTAL_IMG_EMBEDS; ++i)
        {
            msg.set_string("portal"+i, "portal"+i+"_img");
            msg.set_int("portal"+i+"|offsetx", 30);
            msg.set_int("portal"+i+"|offsety", 30);
        }

        for (int i=0; i<SAW_IMG_EMBEDS; ++i)
        {
            msg.set_string("saw"+i, "saw"+i+"_img");
            msg.set_int("saw"+i+"|offsetx", 115);
            msg.set_int("saw"+i+"|offsety", 117);
        }

        for (int i=0; i<GIRL_IMG_EMBEDS; ++i)
        {
            msg.set_string("girl"+i, "girl"+i+"_img");
            msg.set_int("girl"+i+"|offsetx", 40);
            msg.set_int("girl"+i+"|offsety", 40);
        }
    }

    void on_level_start()
    {
        @meat_boy = MeatBoy();

        scriptenemy@ meat_boy_enemy = create_scriptenemy(meat_boy);
        meat_boy_enemy.x(-833);
        meat_boy_enemy.y(-792);

        g.add_entity(meat_boy_enemy.as_entity());
        meat_boy_id = meat_boy_enemy.id();

        intents.init(INPUTS);
        cutscene.init();
    }

    void checkpoint_load()
    {
        update_meat_boy_ref();
        g.layer_visible(1, true);

        if (warp_level > 0)
        {
            entity@ portal = entity_by_id(6877);
            if (portal !is null) g.remove_entity(portal);
        }
    }

    void update_meat_boy_ref()
    {
        @meat_boy = cast<MeatBoy>(entity_by_id(meat_boy_id).as_scriptenemy().get_object());
    }

    void step(int)
    {
        if (cutscene.active())
        {
            clear_intents();
            cutscene.step();
        }

        if (meat_boy is null) update_meat_boy_ref();
        if (meat_boy !is null)
        {
            controllable@ c = meat_boy.as_controllable();
            if (c !is null and c.player_index() == -1)
            {
                intents.step(c);
            }
        }
    }

    void draw(float sub_frame)
    {
        if (cutscene.active()) cutscene.draw(sub_frame);
    }

    void editor_var_changed(var_info@ v)
    {
        int i = v.get_index(0);
        if (i != -1) warp_levels[i].init();
    }

    void editor_draw(float sub_frame)
    {
        for (uint i=0; i<warp_levels.size(); ++i)
        {
            warp_levels[i].draw();
        }
    }

    void play_segment(string, message@ msg)
    {
        uint segment = msg.get_int("segment");
        intents.triggered = uint(max(segment, intents.triggered));
    }

    void start_cutscene(string, message@ msg)
    {
        cutscene.warp_zone();
    }

    void setup_warp_level(int level)
    {
        float warp_x = warp_levels[level].spawn_x;
        float warp_y = warp_levels[level].spawn_y;
        controllable@ c = meat_boy.as_controllable();
        c.x(warp_x);
        c.y(warp_y - 24);
        reset_camera(0);
        meat_boy.cx = warp_x;
        meat_boy.cy = warp_y;
        meat_boy.face = 1;
    }

    void become_meat_boy(string, message@ msg)
    {
        // Hide sun
        g.layer_visible(1, false);

        // Do the thing
        controllable@ c = meat_boy.as_controllable();
        if (c.player_index() == -1)
        {
            controller_entity(0, c);
            setup_warp_level(0);
        }
    }

    void end_warp_level(string, message@ msg)
    {
        if (warp_level < int(warp_levels.size())-1) cutscene.next_level();
        else cutscene.heart_out();
        meat_boy.vx = 0;
    }

    void next_warp_level(string, message@ msg)
    {
        warp_levels[warp_level].clear_filth();
        setup_warp_level(++warp_level);
    }

    void collected_bandage(string, message@ msg)
    {
        ++bandages;
    }

    void lovely_ending(string, message@ msg)
    {
        g.load_checkpoint();
    }

    void check_true_end(string, message@ msg)
    {
        if (bandages == 6)
        {
            entity@ apple = create_entity("hittable_apple");
            apple.x(768);
            apple.y(-1000);
            g.add_entity(apple);
        }
    }
}

raycast@ collision_ground(scene@ g, float x1, float y1, float x2, float y2, int edges=TOP)
{
    // Central ray
    float mx = x1 + (x2 - x1) / 2;
    raycast@ r = g.ray_cast_tiles(mx, y1, mx, y2, edges);
    if (r.hit()) return r;

    // Outer rays
    float dx = (x2 - x1) / 6;
    for (int i=1; i<=3; ++i)
    {
        @r = g.ray_cast_tiles(mx + i * dx, y1, mx + i * dx, y2, edges, r);
        if (r.hit()) return r;

        @r = g.ray_cast_tiles(mx - i * dx, y1, mx - i * dx, y2, edges, r);
        if (r.hit()) return r;
    }

    return r;
}

raycast@ collision_roof(scene@ g, float x1, float y1, float x2, float y2, int edges=BOTTOM)
{
    // Central ray
    float mx = x1 + (x2 - x1) / 2;
    raycast@ r = g.ray_cast_tiles(mx, y1, mx, y2, edges);
    if (r.hit()) return r;

    // Outer rays
    float dx = (x2 - x1) / 6;
    for (int i=1; i<=3; ++i)
    {
        @r = g.ray_cast_tiles(mx + i * dx, y1, mx + i * dx, y2, edges, r);
        if (r.hit()) return r;

        @r = g.ray_cast_tiles(mx - i * dx, y1, mx - i * dx, y2, edges, r);
        if (r.hit()) return r;
    }

    return r;
}

raycast@ collision_left(scene@ g, float x1, float y1, float x2, float y2, int edges=LEFT)
{
    // Central ray
    float my = y1 + (y2 - y1) / 2;
    raycast@ r = g.ray_cast_tiles(x1, my, x2, my, edges);
    if (r.hit()) return r;

    // Outer rays
    float dy = (y2 - y1) / 6;
    for (int i=1; i<=3; ++i)
    {
        @r = g.ray_cast_tiles(x1, my + i * dy, x2, my + i * dy, edges, r);
        if (r.hit()) return r;

        @r = g.ray_cast_tiles(x1, my - i * dy, x2, my - i * dy, edges, r);
        if (r.hit()) return r;
    }

    return r;
}

raycast@ collision_right(scene@ g, float x1, float y1, float x2, float y2, int edges=RIGHT)
{
    // Central ray
    float my = y1 + (y2 - y1) / 2;
    raycast@ r = g.ray_cast_tiles(x1, my, x2, my, edges);
    if (r.hit()) return r;

    // Outer rays
    float dy = (y2 - y1) / 6;
    for (int i=1; i<=3; ++i)
    {
        @r = g.ray_cast_tiles(x1, my + i * dy, x2, my + i * dy, edges, r);
        if (r.hit()) return r;

        @r = g.ray_cast_tiles(x1, my - i * dy, x2, my - i * dy, edges, r);
        if (r.hit()) return r;
    }

    return r;
}

entity@ create_emitter(int layer, int sub_layer, int id, float x, float y, int width, int height, int rotation)
{
    entity@ emitter = create_entity("entity_emitter");
    varstruct@ vars = emitter.vars();
    emitter.layer(layer);
    vars.get_var("emitter_id").set_int32(id);
    vars.get_var("width").set_int32(width);
    vars.get_var("height").set_int32(height);
    vars.get_var("draw_depth_sub").set_int32(sub_layer);
    vars.get_var("r_area").set_bool(true);
    vars.get_var("e_rotation").set_int32(rotation);
    emitter.set_xy(x, y);
    
    return emitter;
}

void clear_intents()
{
    controllable@ c = controller_controllable(0);
    if (c is null) return;
    c.x_intent(0);
    c.y_intent(0);
    c.taunt_intent(0);
    c.heavy_intent(0);
    c.light_intent(0);
    c.dash_intent(0);
    c.jump_intent(0);
    c.fall_intent(0);
}
