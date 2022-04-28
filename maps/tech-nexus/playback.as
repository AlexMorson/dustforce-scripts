#include "recordings.as"

class script {}

class PlayerGhost : trigger_base
{
    script@ s;
    scripttrigger@ self;

    [text] string name = "";
    [text] int layer = 15;
    [text] float speed = 1.0;

    [hidden] float offset_x = 0;
    [hidden] float offset_y = 0;

    Recording@ recording;
    Playback@ playback;

    void init(script@ s, scripttrigger@ self) {
        @this.s = @s;
        @this.self = @self;

        self.editor_show_radius(false);

        load_recording();
    }

    void editor_var_changed(var_info@ var)
    {
        string name = var.get_name();
        if (name == "name") load_recording();
        if (name == "layer" and playback !is null) playback.layer = layer; 
    }

    void load_recording()
    {
        if (RECORDINGS.exists(name))
        {
            @recording = Recording(string(RECORDINGS[name]));
            @playback = Playback(recording, layer, speed, true);
        }
        else
        {
            @recording = null;
            @playback = null;
        }

        update_offset();
    }

    void update_offset()
    {
        int tile_x = 48 * int(round(self.x() / 48));
        int tile_y = 48 * int(round(self.y() / 48));

        self.x(tile_x);
        self.y(tile_y);

        if (recording is null) return;

        PlayerState@ start = recording.states[0];

        int player_x = 48 * int(round(start.x / 48));
        int player_y = 48 * int(round(start.y / 48));

        offset_x = tile_x - player_x;
        offset_y = tile_y - player_y;
    }

    void editor_step()
    {
        update_offset();
    }

    void editor_draw(float sub_frame)
    {
        if (playback !is null) playback.editor_draw(offset_x, offset_y);
    }

    void step()
    {
        if (playback !is null) playback.step();
    }

    void draw(float sub_frame)
    {
        if (playback !is null) playback.draw(sub_frame, offset_x, offset_y);
    }
}

class Playback
{
    Recording@ recording;
    int layer = 18;
    int player_sublayer = 10;
    int effect_sublayer = 14;
    float speed = 1.0;
    bool virtual = false;

    sprites@ spr;
    float position;
    array<Effect> active_effects;

    Playback(Recording@ recording, int layer, float speed, bool virtual)
    {
        @this.recording = recording;
        this.layer = layer;
        this.speed = speed;
        this.virtual = virtual;

        @spr = create_sprites();
        spr.add_sprite_set(virtual ? "vdustman" : "dustman");
    }

    void step()
    {
        int last_frame = int(position);
        position = (position + speed) % recording.size();
        int new_frame = int(position);

        // Simulate time passing for the effects
        int frame = last_frame;
        while (frame != new_frame)
        {
            step_frame(frame);
            ++frame;
            if (frame >= int(recording.size()))
            {
                frame = 0;
                active_effects.resize(0);
            }
        }
    }

    void step_frame(int frame)
    {
        // Instantiate recorded effects
        array<Effect>@ new_effects = recording.effects[frame];
        for (uint i=0; i<new_effects.size(); ++i)
        {
            active_effects.insertLast(new_effects[i]);
        }

        // Update the effects
        for (int i=active_effects.size()-1; i>=0; --i)
        {
            active_effects[i].step();
            if (active_effects[i].finished)
            {
                active_effects.removeAt(i);
            }
        }
    }

    void editor_draw(float offset_x, float offset_y)
    {
        const int steps = recording.size() / 10;
        for (int i=0; i<steps; ++i)
        {
            int frame = i * recording.size() / steps;
            PlayerState@ p = recording.states[frame];
            spr.draw_world(layer, player_sublayer, p.sprite_index, p.state_timer, 1, p.x+offset_x, p.y+offset_y, p.rotation, p.face, 1, 0xFFFFFFFF);
        }
    }

    void draw(float sub_frame, float offset_x, float offset_y)
    {
        // Interpolate the player position
        float sub_position = position - (1 - sub_frame) * speed;
        float frac = sub_position - floor(sub_position);

        PlayerState@ prev = recording.states[int(max(0, sub_position - 1))];
        PlayerState@ cur = recording.states[int(max(0, sub_position))];

        float x = prev.x + frac * (cur.x - prev.x) + offset_x;
        float y = prev.y + frac * (cur.y - prev.y) + offset_y;

        // Fade in/out at the start/end of the recording
        const float fade_time = 10 * speed;
        int opacity = 0xFF;
        if (sub_position < fade_time) opacity = int(0xFF * max(0, sub_position) / fade_time);
        if (sub_position > int(recording.size()) - fade_time) opacity = int(0xFF * (recording.size() - sub_position) / fade_time);
        uint colour = (opacity << 24) + 0xFFFFFF;

        // Draw the player
        spr.draw_world(layer, player_sublayer, cur.sprite_index, cur.state_timer, 1, x, y, cur.rotation, cur.face, 1, colour);

        // Draw the effects
        for (uint i=0; i<active_effects.size(); ++i)
        {
            active_effects[i].draw(spr, layer, effect_sublayer, offset_x, offset_y, colour, virtual);
        }
    }
}

class Recording
{
    array<array<Effect>> effects;
    array<PlayerState> states;

    Recording(string recording)
    {
        array<string>@ lines = recording.split("\n");
        array<Effect> frame_effects;
        for (uint i=0; i<lines.size(); ++i)
        {
            array<string>@ args = lines[i].split(" ");
            if (args[0].substr(0, 2) == "dm")
            {
                // Effect
                string sprite_name = args[0];
                float x = parseFloat(args[1]);
                float y = parseFloat(args[2]);
                int face = parseInt(args[3]);
                float rotation = parseFloat(args[4]);
                int freeze = parseInt(args[5]);
                frame_effects.insertLast(Effect(sprite_name, x, y, face, rotation, freeze));
            }
            else
            {
                effects.insertLast(frame_effects);
                frame_effects = array<Effect>();

                // Player state
                string sprite_index = args[0];
                int state_timer = parseInt(args[1]);
                float x = parseFloat(args[2]);
                float y = parseFloat(args[3]);
                int face = parseInt(args[4]);
                float rotation = parseFloat(args[5]);
                states.insertLast(PlayerState(sprite_index, state_timer, x, y, face, rotation));
            }
        }
        effects.insertLast(frame_effects);
        effects.removeAt(0);
    }

    uint size()
    {
        return states.size();
    }
}

class PlayerState
{
    string sprite_index;
    int state_timer;
    float x;
    float y;
    int face;
    float rotation;

    PlayerState() {}

    PlayerState(string sprite_index, int state_timer, float x, float y, int face, float rotation)
    {
        this.sprite_index = sprite_index;
        this.state_timer = state_timer;
        this.x = x;
        this.y = y;
        this.face = face;
        this.rotation = rotation;
    }
}

class Effect
{
    string sprite_name;
    int effect_index;
    int face;
    float x;
    float y;
    float rotation;
    int freeze;

    int frame = 0;
    uint sprite_index = 0;
    bool finished = false;

    Effect() {}

    Effect(string sprite_name, float x, float y, int face, float rotation, int freeze)
    {
        this.sprite_name = sprite_name;
        this.effect_index = EFFECTS.find(sprite_name);
        this.x = x;
        this.y = y;
        this.face = face;
        this.rotation = rotation;
        this.freeze = freeze;
    }

    Effect(Effect@ other)
    {
        this.sprite_name = other.sprite_name;
        this.effect_index = other.effect_index;
        this.x = other.x;
        this.y = other.y;
        this.face = other.face;
        this.rotation = other.rotation;
        this.freeze = other.freeze;
    }

    void step()
    {
        if (++frame >= FRAMES[effect_index][sprite_index] + (sprite_index == 0 ? freeze : 0))
        {
            frame = 0;
            if (++sprite_index >= FRAMES[effect_index].size())
            {
                finished = true;
            }
        }
    }

    void draw(sprites@ spr, int layer, int sub_layer, float offset_x=0.0, float offset_y=0.0, uint colour=0xFFFFFFFF, bool virtual=false)
    {
        if (finished) return;

        string is_virtual = virtual ? "v" : "";
        spr.draw_world(layer, sub_layer, is_virtual + sprite_name, sprite_index, 1, x+offset_x, y+offset_y, rotation, face, 1, colour);
    }
}

const array<string> EFFECTS = {
    "dmairdash",
    "dmbjump",
    "dmdash",
    "dmdbljump",
    "dmfastfall",
    "dmfjump",
    "dmheavyland",
    "dmjump",
    "dmland",
    "dmwalljump",

    "dmairheavyd",
    "dmairstriked1",
    "dmgroundstrike1",
    "dmgroundstriked",
    "dmgroundstrikeu1",
    "dmheavyd",
    "dmheavyf",
    "dmheavyu",

    "dgairdash",
    "dgbjump",
    "dgdash",
    "dgdbljump",
    "dgfastfall",
    "dgfjump",
    "dgheavyland",
    "dgjump",
    "dgland",
    "dgwalljump",

    "dgairheavyd",
    "dgairstriked1",
    "dggroundstrike1",
    "dggroundstriked",
    "dggroundstrikeu1",
    "dgheavyd",
    "dgheavyf",
    "dgheavyu",

    "dkairdash",
    "dkbjump",
    "dkdash",
    "dkdbljump",
    "dkfastfall",
    "dkfjump",
    "dkheavyland",
    "dkjump",
    "dkland",
    "dkwalljump",

    "dkairheavyd",
    "dkairstriked1",
    "dkgroundstrike1",
    "dkgroundstriked",
    "dkgroundstrikeu1",
    "dkheavyd",
    "dkheavyf",
    "dkheavyu",

    "doairdash",
    "dobjump",
    "dodash",
    "dodbljump",
    "dofastfall",
    "dofjump",
    "doheavyland",
    "dojump",
    "doland",
    "dowalljump",

    "doairheavyd",
    "doairstriked1",
    "dogroundstrike1",
    "dogroundstriked",
    "dogroundstrikeu1",
    "doheavyd",
    "doheavyf",
    "doheavyu",

    "vdmairdash",
    "vdmbjump",
    "vdmdash",
    "vdmdbljump",
    "vdmfastfall",
    "vdmfjump",
    "vdmheavyland",
    "vdmjump",
    "vdmland",
    "vdmwalljump",

    "vdmairheavyd",
    "vdmairstriked1",
    "vdmgroundstrike1",
    "vdmgroundstriked",
    "vdmgroundstrikeu1",
    "vdmheavyd",
    "vdmheavyf",
    "vdmheavyu",

    "vdgairdash",
    "vdgbjump",
    "vdgdash",
    "vdgdbljump",
    "vdgfastfall",
    "vdgfjump",
    "vdgheavyland",
    "vdgjump",
    "vdgland",
    "vdgwalljump",

    "vdgairheavyd",
    "vdgairstriked1",
    "vdggroundstrike1",
    "vdggroundstriked",
    "vdggroundstrikeu1",
    "vdgheavyd",
    "vdgheavyf",
    "vdgheavyu",

    "vdkairdash",
    "vdkbjump",
    "vdkdash",
    "vdkdbljump",
    "vdkfastfall",
    "vdkfjump",
    "vdkheavyland",
    "vdkjump",
    "vdkland",
    "vdkwalljump",

    "vdkairheavyd",
    "vdkairstriked1",
    "vdkgroundstrike1",
    "vdkgroundstriked",
    "vdkgroundstrikeu1",
    "vdkheavyd",
    "vdkheavyf",
    "vdkheavyu",

    "vdoairdash",
    "vdobjump",
    "vdodash",
    "vdodbljump",
    "vdofastfall",
    "vdofjump",
    "vdoheavyland",
    "vdojump",
    "vdoland",
    "vdowalljump",

    "vdoairheavyd",
    "vdoairstriked1",
    "vdogroundstrike1",
    "vdogroundstriked",
    "vdogroundstrikeu1",
    "vdoheavyd",
    "vdoheavyf",
    "vdoheavyu",
};

const array<array<int>> FRAMES = {
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 2, 3, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},

    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},

    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 2, 3, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},

    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},

    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3, 2, 3, 2},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},

    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},

    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3, 2, 3, 2},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},

    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},

    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 2, 3, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},

    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},

    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 2, 3, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},
    {3, 3, 4, 3, 3},

    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},
    {4, 3, 4, 3, 2, 3},

    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3, 2, 3, 2},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},

    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},

    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3, 2, 3, 2},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},
    {3, 2, 3, 2, 3},

    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
    {4, 2, 3, 2, 3, 2},
};
