/**
 * This is a plugin that visualises how dust is cleared when attacking.
 *
 * Every attack is made up of a number of "filth projection nodes". The range of each
 * node is shown by the white outline. Dust outside this area will not be cleared.
 *
 * If the midpoint of a tile of dust lies inside the node's range, it can be cleaned.
 * But there are a few possible outcomes, as shown by the coloured lines:
 * Green = The dust will be cleared.
 * Black = The node does not have line of sight to the dust, so it will not be cleared.
 * Blue = This node can only clear dust on the top of tiles (nodes coloured cyan, used
 * in up attacks) or on the bottom of tiles (nodes coloured red, used in down attacks),
 * so the dust will not be cleared.
 *
 * There do seem to be a few exceptions to these rules though, with certain characters'
 * up or down attacks being slightly shorter than expected. The largest discrepancy is
 * worth's downlight, which is a whole 15 pixels shorter than expected!
 */

#include "lib/math/math.cpp"
#include "lib/tiles/common.cpp"

const float TAU = 2 * PI;

const uint32 OUTER_BORDER = 0xFFFFFFFF;
const uint32 INNER_BORDER = 0x22FFFFFF;
const uint32 PRE_OCCLUDED = 0x44000000;
const uint32 POST_OCCLUDED = 0x44000000;
const uint32 CLEANED = 0x8800FF00;
const uint32 BAD_SIDE = 0x882222FF;

const uint32 NODE = 0xFFFFFFFF;
const uint32 NODE_ONLY_TOP = 0xFF00FFFF;
const uint32 NODE_ONLY_BOTTOM = 0xFFFF0000;

namespace TileSide
{
    const uint LEFT = 1 << 0;
    const uint RIGHT = 1 << 1;
    const uint TOP = 1 << 2;
    const uint BOTTOM = 1 << 3;

    const uint ALL = LEFT | RIGHT | TOP | BOTTOM;
}

class Dust
{
    float x;
    float y;
    uint side;

    Dust() {}

    Dust(float x, float y, uint side)
    {
        this.x = x;
        this.y = y;
        this.side = side;
    }
}

array<Dust> get_dust_in_rectangle(float center_x, float center_y, float width, float height)
{
    int tile_x1 = int(floor((center_x - width / 2) / 48));
    int tile_y1 = int(floor((center_y - height / 2) / 48));
    int tile_x2 = int(ceil((center_x + width / 2) / 48));
    int tile_y2 = int(ceil((center_y + height / 2) / 48));

    scene@ g = get_scene();
    array<Dust> dust;

    // Add a small offset to the position of dust tiles, to ensure that rays don't
    // mistakenly hit the tile that the dust lies on.
    const float OFFSET = 5e-4;

    for (int tile_x = tile_x1; tile_x < tile_x2; ++tile_x)
    {
        for (int tile_y = tile_y1; tile_y < tile_y2; ++tile_y)
        {
            tilefilth@ filth = g.get_tile_filth(tile_x, tile_y);
            if (1 <= filth.top() and filth.top() <= 5)
                dust.insertLast(Dust(48 * tile_x + 24, 48 * tile_y - OFFSET, TileSide::TOP));
            if (1 <= filth.bottom() and filth.bottom() <= 5)
                dust.insertLast(Dust(48 * tile_x + 24, 48 * tile_y + 48 + OFFSET, TileSide::BOTTOM));
            if (1 <= filth.left() and filth.left() <= 5)
                dust.insertLast(Dust(48 * tile_x - OFFSET, 48 * tile_y + 24, TileSide::LEFT));
            if (1 <= filth.right() and filth.right() <= 5)
                dust.insertLast(Dust(48 * tile_x + 48 + OFFSET, 48 * tile_y + 24, TileSide::RIGHT));
        }
    }

    return dust;
}

bool is_inside_tile(scene@ g, float x, float y)
{
    int tile_x = int(floor(x / 48));
    int tile_y = int(floor(y / 48));

    tileinfo@ tile = g.get_tile(tile_x, tile_y);
    if (not tile.solid())
    {
        return false;
    }

    float _;
    return point_in_tile(x, y, tile_x, tile_y, tile.type(), _, _);
}

class FilthProjectionNodes
{
    float center_x;
    float center_y;
    float base_width;
    float distance;
    float direction;
    uint tile_side;

    uint node_count;
    float spacing;

    FilthProjectionNodes() {}

    FilthProjectionNodes(float center_x, float center_y, float base_width, float distance, float direction, uint tile_side = TileSide::ALL)
    {
        this.center_x = center_x;
        this.center_y = center_y;
        this.base_width = base_width;
        this.distance = distance;
        this.direction = direction;
        this.tile_side = tile_side;

        this.node_count = uint(base_width / 24.0) + 1;
        this.spacing = base_width / (this.node_count - 1);
    }

    void draw()
    {
        // The projection's reach in tiles.
        float tile_distance = distance / 48.0;

        // The y coordinate at which adjacent curves and arcs will intersect.
        float mid_y = spacing / 2.0 / 48.0;

        // The angle at which the curve intersects the arc.
        float curve_arc_angle = acos(1.0 - (1.0 / (2.0 * tile_distance * tile_distance)));

        // The angle at which adjacent curves intersect.
        float adj_curve_angle = TAU - 2.0 * atan(sqrt(1 - mid_y * mid_y) / mid_y);

        // The angle at which adjacent arcs intersect.
        float adj_arc_angle = asin(mid_y / tile_distance);

        canvas@ c = create_canvas(false, 22, 0);
        c.translate(center_x, center_y);
        c.rotate(direction, 0, 0);
        c.translate(-distance / 2, -base_width / 2);

        for (uint i = 0; i < node_count; ++i)
        {
            draw_node(c, tile_side == TileSide::TOP ? NODE_ONLY_TOP : tile_side == TileSide::BOTTOM ? NODE_ONLY_BOTTOM : NODE);
            draw_curve_between(c, curve_arc_angle, TAU - adj_curve_angle, i == 0 ? 2 : 1, i == 0 ? OUTER_BORDER : INNER_BORDER);
            draw_curve_between(c, TAU - adj_curve_angle, adj_curve_angle, 2, OUTER_BORDER);
            draw_curve_between(c, adj_curve_angle, TAU - curve_arc_angle, i == node_count - 1 ? 2 : 1, i == node_count - 1 ? OUTER_BORDER : INNER_BORDER);
            draw_arc_between(c, -curve_arc_angle, -adj_arc_angle, i == node_count - 1 ? 2 : 1, i == node_count - 1 ? OUTER_BORDER : INNER_BORDER);
            draw_arc_between(c, -adj_arc_angle, adj_arc_angle, 2, OUTER_BORDER);
            draw_arc_between(c, adj_arc_angle, curve_arc_angle, i == 0 ? 2 : 1, i == 0 ? OUTER_BORDER : INNER_BORDER);
            c.translate(0, spacing);
        }

        scene@ g = get_scene();
        array<Dust> all_dust = get_dust_in_rectangle(center_x, center_y, max(distance, base_width) + 96, max(distance, base_width) + 96);
        for (uint i = 0; i < all_dust.size(); ++i)
        {
            float dust_x = all_dust[i].x;
            float dust_y = all_dust[i].y;
            uint dust_side = all_dust[i].side;

            for (uint j = 0; j < node_count; ++j)
            {
                float c = cos(DEG2RAD * direction);
                float s = sin(DEG2RAD * direction);

                float node_x = center_x - c * distance / 2 + s * base_width / 2 - s * spacing * j;
                float node_y = center_y - s * distance / 2 - c * base_width / 2 + c * spacing * j;

                float r = sqrt(pow(node_x - dust_x, 2) + pow(node_y - dust_y, 2));
                float a = atan2(dust_y - node_y, dust_x - node_x) - DEG2RAD * direction;

                if (r <= distance and 2 * r * r * (1 - cos(a)) <= 48 * 48)
                {
                    // Check if the node is blocked by being inside of a tile.
                    if (is_inside_tile(g, node_x, node_y))
                    {
                        g.draw_line_world(22, 0, node_x, node_y, dust_x, dust_y, 1, POST_OCCLUDED);
                        continue;
                    }

                    // Check if the node has line of sight to the dust.
                    raycast@ ray = g.ray_cast_tiles(node_x, node_y, dust_x, dust_y);
                    if (ray.hit())
                    {
                        g.draw_line_world(22, 0, node_x, node_y, ray.hit_x(), ray.hit_y(), 1, PRE_OCCLUDED);
                        g.draw_line_world(22, 0, ray.hit_x(), ray.hit_y(), dust_x, dust_y, 1, POST_OCCLUDED);
                        continue;
                    }

                    // Check if the node can clear the tile side that the dust is on.
                    if (tile_side & dust_side == 0)
                    {
                        g.draw_line_world(22, 0, node_x, node_y, dust_x, dust_y, 1, BAD_SIDE);
                        continue;
                    }

                    // The dust will be cleared!
                    g.draw_line_world(22, 0, node_x, node_y, dust_x, dust_y, 1, CLEANED);
                }
            }
        }
    }

    private void draw_node(canvas@ c, uint32 colour)
    {
        c.draw_rectangle(-2, -2, 2, 2, 0, colour);
    }

    private void draw_curve_between(canvas@ c, float start_angle, float end_angle, float width, uint32 colour)
    {
        uint steps = 20;
        for (uint i = 0; i < steps; ++i)
        {
            float a1 = start_angle + float(i) / steps * (end_angle - start_angle);
            float a2 = start_angle + float(i + 1) / steps * (end_angle - start_angle);

            float r1 = 48 / sqrt(2 * (1 - cos(a1)));
            float r2 = 48 / sqrt(2 * (1 - cos(a2)));

            float x1 = r1 * cos(a1);
            float x2 = r2 * cos(a2);
            float y1 = -r1 * sin(a1);
            float y2 = -r2 * sin(a2);

            c.draw_line(x1, y1, x2, y2, width, colour);
        }
    }

    private void draw_arc_between(canvas@ c, float start_angle, float end_angle, float width, uint32 colour)
    {
        uint steps = 10;
        for (uint i = 0; i < steps; ++i)
        {
            float a1 = start_angle + float(i) / steps * (end_angle - start_angle);
            float a2 = start_angle + float(i + 1) / steps * (end_angle - start_angle);

            float x1 = distance * cos(a1);
            float x2 = distance * cos(a2);
            float y1 = -distance * sin(a1);
            float y2 = -distance * sin(a2);

            c.draw_line(x1, y1, x2, y2, width, colour);
        }
    }
}

array<FilthProjectionNodes> filth_projection_nodes_from_hitbox(hitbox@ h)
{
    rectangle@ r = h.base_rectangle();

    switch (h.attack_dir())
    {
        case -85:
            return array<FilthProjectionNodes> = {FilthProjectionNodes(h.centre_x(), h.centre_y(), r.bottom() - r.top(), r.right() - r.left(), 180)};
        case 85:
            return array<FilthProjectionNodes> = {FilthProjectionNodes(h.centre_x(), h.centre_y(), r.bottom() - r.top(), r.right() - r.left(), 0)};
        case -30:
        case 30:
            return array<FilthProjectionNodes> = {
                FilthProjectionNodes(h.centre_x(), h.centre_y(), r.right() - r.left(), r.bottom() - r.top(), 90, TileSide::TOP),
                FilthProjectionNodes(h.centre_x(), h.centre_y(), r.right() - r.left(), r.bottom() - r.top(), 270),
            };
        case -151:
        case -150:
        case 150:
        case 151:
            return array<FilthProjectionNodes> = {
                FilthProjectionNodes(h.centre_x(), h.centre_y(), r.right() - r.left(), r.bottom() - r.top(), 90),
                FilthProjectionNodes(h.centre_x(), h.centre_y(), r.right() - r.left(), r.bottom() - r.top(), 270, TileSide::BOTTOM),
            };
    }

    return array<FilthProjectionNodes> = {};
}

class script
{
    scene@ g;
    controllable@ p;

    script()
    {
        @g = get_scene();
    }
    
    void on_level_start()
    {
        @p = controller_controllable(0);
    }

    void checkpoint_load()
    {
        @p = controller_controllable(0);
    }

    void draw(float)
    {
        if (p is null) return;

        hitbox@ h = p.hitbox();
        if (h is null) return;

        array<FilthProjectionNodes> filth_projection_nodes = filth_projection_nodes_from_hitbox(h);

        for (uint i = 0; i < filth_projection_nodes.size(); ++i)
            filth_projection_nodes[i].draw();
    }
}