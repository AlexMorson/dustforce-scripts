#include "recordings.as"

class script {}

class PlayerGhost : trigger_base
{
    script@ s;
    scripttrigger@ self;

    [text] string name = "";
    [text] int layer = 15;
    [text] float rate = 1.0;

    [hidden] float offset_x = 0;
    [hidden] float offset_y = 0;

    Recording@ recording;
    Playback@ playback;

    void init(script@ s, scripttrigger@ self)
    {
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
        if (name == "rate" and playback !is null) playback.rate = rate; 
    }

    void load_recording()
    {
        if (RECORDINGS.exists(name))
        {
            @recording = Recording(string(RECORDINGS[name]));
            @playback = Playback(recording, layer, rate);
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

        Sprite@ start = recording.sprites[0][0];

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
    SpritesCache sprites_cache;
    Recording@ recording;
    int layer;
    float rate;
    int enemy_sublayer = 8;
    int player_sublayer = 10;
    int effect_sublayer = 14;

    float time;
    array<Effect> active_effects;

    Playback(Recording@ recording, int layer, float rate)
    {
        @this.recording = recording;
        this.layer = layer;
        this.rate = rate;
    }

    void step()
    {
        int last_frame = int(time);
        time = (time + rate) % recording.frames;
        puts("> " + time);
        int new_frame = int(time);

        // Simulate time passing for the effects
        int frame = last_frame;
        while (frame != new_frame)
        {
            step_frame(frame);
            ++frame;
            if (frame >= int(recording.frames))
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
        for (uint i = 0; i < new_effects.size(); ++i)
        {
            active_effects.insertLast(new_effects[i]);
        }

        // Update the effects
        for (int i = active_effects.size() - 1; i >= 0; --i)
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
        for (uint entity_index = 0; entity_index < recording.sprites.size(); ++entity_index)
        {
            int sub_layer = entity_index == 0 ? player_sublayer : enemy_sublayer;
            int frame_count = recording.sprites[entity_index].size();
            int steps = frame_count / 10;
            for (int i = 0; i < steps; ++i)
            {
                int frame = i * frame_count / steps;
                Sprite@ sprite = recording.sprites[entity_index][frame];
                sprite.draw(sprites_cache, layer, sub_layer, offset_x, offset_y, 0xFFFFFFFF);
            }
        }
    }

    void draw(float sub_frame, float offset_x, float offset_y)
    {
        // How far through the current frame are we?
        float sub_time = time - (1 - sub_frame) * rate;
        float frac = sub_time - floor(sub_time);

        // Fade in/out at the start/end of the recording
        float fade_duration = 10 * rate;
        int opacity = 0xFF;
        if (sub_time < fade_duration)
            opacity = int(0xFF * max(0, sub_time) / fade_duration);
        if (sub_time > int(recording.frames) - fade_duration)
            opacity = int(0xFF * (recording.frames - sub_time) / fade_duration);
        uint colour = (opacity << 24) + 0xFFFFFF;

        for (uint entity_index = 0; entity_index < recording.sprites.size(); ++entity_index)
        {
            array<Sprite>@ entity_sprites = recording.sprites[entity_index];
            int frames = entity_sprites.size();

            // Interpolate between previous and current frames
            Sprite@ prev = entity_sprites[int(max(0, min(frames - 1, sub_time - 1)))];
            Sprite@ cur = entity_sprites[int(max(0, min(frames - 1, sub_time)))];

            float sub_offset_x = frac * (cur.x - prev.x) + offset_x;
            float sub_offset_y = frac * (cur.y - prev.y) + offset_y;

            int sub_layer = entity_index == 0 ? player_sublayer : enemy_sublayer;
            prev.draw(sprites_cache, layer, sub_layer, sub_offset_x, sub_offset_y, colour);
        }

        // Draw the effects
        for (uint i = 0; i < active_effects.size(); ++i)
        {
            active_effects[i].draw(sprites_cache, layer, effect_sublayer, offset_x, offset_y, colour);
        }
    }
}

class Recording
{
    array<array<Effect>> effects; // effects[frame][i]
    array<array<Sprite>> sprites; // sprites[entity][frame]
    uint frames = 0;

    Recording(string recording)
    {
        array<string>@ lines = recording.split("\n");
        array<string>@ sprite_sets = lines[0].split(" ");
        array<Effect> frame_effects;
        for (uint i = 1; i < lines.size(); ++i)
        {
            array<string>@ args = lines[i].split(" ");
            int entity_index = parseInt(args[0]);
            if (entity_index == -1)
            {
                // Effect
                string name = args[1];
                float x = parseFloat(args[2]);
                float y = parseFloat(args[3]);
                int face = parseInt(args[4]);
                float rotation = parseFloat(args[5]);
                int freeze = parseInt(args[6]);
                frame_effects.insertLast(Effect(sprite_sets[0], name, x, y, face, rotation, freeze));
            }
            else
            {
                // Entity sprite
                string name = args[1];
                int frame = parseInt(args[2]);
                float x = parseFloat(args[3]);
                float y = parseFloat(args[4]);
                int face = parseInt(args[5]);
                float rotation = parseFloat(args[6]);

                if (entity_index >= int(sprites.size()))
                    sprites.insertLast(array<Sprite>());
                
                sprites[entity_index].insertLast(Sprite(sprite_sets[entity_index], name, frame, x, y, face, rotation));

                // A player sprite indicates the start of the next frame
                if (entity_index == 0)
                {
                    effects.insertLast(frame_effects);
                    frame_effects = array<Effect>();
                    ++frames;
                }
            }
        }
        effects.insertLast(frame_effects);
        effects.removeAt(0);
    }
}

class Sprite
{
    string sprite_set;
    string name;
    int frame;
    float x;
    float y;
    int face;
    float rotation;

    Sprite() {}

    Sprite(string sprite_set, string name, int frame, float x, float y, int face, float rotation)
    {
        this.sprite_set = sprite_set;
        this.name = name;
        this.frame = frame;
        this.x = x;
        this.y = y;
        this.face = face;
        this.rotation = rotation;
    }

    void draw(SpritesCache@ sprites_cache, int layer, int sub_layer, float offset_x, float offset_y, uint colour)
    {
        sprites@ spr = sprites_cache.get(sprite_set);
        spr.draw_world(layer, sub_layer, name, frame, 1, x + offset_x, y + offset_y, rotation, face, 1, colour);
    }
}

class SpritesCache
{
    array<sprites@> buffer;
    dictionary lookup;

    sprites@ get(string sprite_set)
    {
        int index;
        if (lookup.get(sprite_set, index))
            return buffer[index];
        sprites@ spr = create_sprites();
        spr.add_sprite_set(sprite_set);
        index = buffer.size();
        lookup[sprite_set] = index;
        buffer.insertLast(spr);
        return spr;
    }
}

class Effect
{
    string sprite_set;
    string name;
    int effect_index;
    float x;
    float y;
    int face;
    float rotation;
    int freeze;

    int frame = 0;
    uint sprite_index = 0;
    bool finished = false;

    Effect() {}

    Effect(string sprite_set, string name, float x, float y, int face, float rotation, int freeze)
    {
        this.sprite_set = sprite_set;
        this.name = name;
        this.effect_index = EFFECTS.find(name);
        this.x = x;
        this.y = y;
        this.face = face;
        this.rotation = rotation;
        this.freeze = freeze;
    }

    Effect(Effect@ other)
    {
        this.sprite_set = other.sprite_set;
        this.name = other.name;
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

    void draw(SpritesCache@ sprites_cache, int layer, int sub_layer, float offset_x, float offset_y, uint colour)
    {
        if (finished) return;

        sprites@ spr = sprites_cache.get(sprite_set);
        spr.draw_world(layer, sub_layer, name, sprite_index, 1, x + offset_x, y + offset_y, rotation, face, 1, colour);
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
