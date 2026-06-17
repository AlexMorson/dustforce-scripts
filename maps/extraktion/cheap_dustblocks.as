const int VK_SPACE = 0x20;
const int LEFT_PRESSED = 0x20;
const int RIGHT_PRESSED = 0x40;


class Block
{
    [text] int _tx;
    [text] int _ty;

    Block() {}

    Block(float x, float y)
    {
        _tx = int(floor(x / 48.0));
        _ty = int(floor(y / 48.0));
    }

    int x() const { return 48 * _tx; }
    int y() const { return 48 * _ty; }
    int tx() const { return _tx; }
    int ty() const { return _ty; }

    bool opEquals(const Block &in other)
    {
        return _tx == other._tx and _ty == other._ty;
    }
}


class script
{
    scene@ g;

    [tooltip:"Left click to add a tile, right click to remove.\nOnly these tiles will be checked when searching\nfor broken dustblocks."] bool edit = false;
    [hidden] array<Block> blocks;
    [hidden] int remaining;

    int _;

    script()
    {
        @g = get_scene();
    }

    void on_level_start()
    {
        g.get_filth_level(_, remaining, _);
    }

    void step(int)
    {
        // Check if any dustblocks have been cleared
        int new_remaining;
        g.get_filth_remaining(_, new_remaining, _);
        if (new_remaining == remaining)
            return;
        remaining = new_remaining;

        // Check which dustblocks were cleared
        for (int i = blocks.size() - 1; i >= 0; --i)
        {
            Block block = blocks[i];
            tileinfo@ tile = g.get_tile(block.tx(), block.ty(), 19);
            // If the layer 19 dustblock has been collected
            if (tile.solid() and tile.sprite_tile() == 0)
            {
                // Delete the corresponding tile on the layer above
                g.set_tile(block.tx(), block.ty(), 20, false, 0, 0, 0, 0);
                blocks.removeAt(i);
            }
        }
    }

    void editor_step()
    {
        if (not edit)
            return;

        editor_api@ e = get_editor_api();
        if (e.mouse_in_gui() or e.key_check_vk(VK_SPACE))
            return;

        input_api@ i = get_input_api();
        float mx = i.mouse_x_world(19);
        float my = i.mouse_y_world(19);
        if (i.mouse_state() & LEFT_PRESSED > 0)
        {
            Block block(mx, my);
            if (blocks.find(block) < 0)
                blocks.insertLast(block);
        }
        else if (i.mouse_state() & RIGHT_PRESSED > 0)
        {
            Block block(mx, my);
            int index = blocks.find(block);
            if (index >= 0)
                blocks.removeAt(index);
        }
    }

    void editor_draw(float)
    {
        if (not edit)
            return;

        for (uint i = 0; i < blocks.size(); ++i)
        {
            Block block = blocks[i];
            g.draw_rectangle_world(22, 0, block.x(), block.y(), block.x() + 48, block.y() + 48, 0, 0x88FF0000);
        }
    }
}
