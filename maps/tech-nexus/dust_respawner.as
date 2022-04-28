class script {}

class DustRespawner : trigger_base
{
    scene@ g;
    script@ s;
    scripttrigger@ self;

    float prev_x;
    float prev_y;

    [position,mode:world,layer:19,y:y] float x;
    [hidden] float y;
    [text] int respawn_time = 60;

    [hidden] array<Tile> tiles;
    [hidden] int tx1;
    [hidden] int ty1;
    [hidden] int tx2;
    [hidden] int ty2;

    void init(script@ s, scripttrigger@ self)
    {
        @g = get_scene();
        @this.s = s;
        @this.self = self;

        tiles.resize(0);
        for (int ty=ty1; ty<ty2; ++ty)
        {
            for (int tx=tx1; tx<tx2; ++tx)
            {
                tilefilth@ filth = g.get_tile_filth(tx, ty);
                Tile tile(tx, ty, filth);
                if (tile.has_dust())
                {
                    tiles.insertLast(tile);
                }
            }
        }

        prev_x = self.x();
        prev_y = self.y();
    }

    void step()
    {
        for (uint i=0; i<tiles.size(); ++i)
        {
            tiles[i].step(g, respawn_time);
        }
    }

    void editor_step()
    {
        x += self.x() - prev_x;
        y += self.y() - prev_y;

        tx1 = int(round(self.x() / 48.0));
        ty1 = int(round(self.y() / 48.0));
        tx2 = int(round(x        / 48.0));
        ty2 = int(round(y        / 48.0));

        self.x(48 * tx1);
        self.y(48 * ty1);
        x  = 48 * tx2;
        y = 48 * ty2;

        prev_x = self.x();
        prev_y = self.y();
    }

    void editor_draw(float)
    {
        uint colour = (self.x() < x and self.y() < y) ? 0x22000000 : 0x22FF0000;
        g.draw_rectangle_world(22, 0, self.x(), self.y(), x, y, 0, colour);

        for (uint i=0; i<tiles.size(); ++i)
        {
            Tile@ t = tiles[i];
            g.draw_rectangle_world(22, 0, 48*t.x, 48*t.y, 48*t.x+48, 48*t.y+48, 0, 0x2200FF00);
        }
    }
}

class Tile
{
    [text] int x;
    [text] int y;
    [text] uint top;
    [text] uint bottom;
    [text] uint left;
    [text] uint right;

    [hidden] int respawn_timer = 0;

    Tile() {}

    Tile(int x, int y, tilefilth@ filth)
    {
        this.x = x;
        this.y = y;
        top    = filth.top();
        bottom = filth.bottom();
        left   = filth.left();
        right  = filth.right();
    }

    bool has_dust()
    {
        return (
            top    != 0 or
            bottom != 0 or
            left   != 0 or
            right  != 0
        );
    }

    void step(scene@ g, int respawn_time)
    {
        if (respawn_timer > 0)
        {
            // If the timer is up
            if (--respawn_timer == 0)
            {
                // Reset the dust
                g.set_tile_filth(x, y, top, bottom, left, right, true, true);
            }
        }
        else
        {
            // Check if dust has been collected
            tilefilth@ filth = g.get_tile_filth(x, y);
            if (filth.top()    != top    or
                filth.bottom() != bottom or
                filth.left()   != left   or
                filth.right()  != right)
            {
                respawn_timer = respawn_time;
            }
        }
    }
}
