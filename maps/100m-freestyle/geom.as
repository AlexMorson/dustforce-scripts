#include "constants.as"
#include "math3d.as"

// Floor plan
//
// Top view:
// +--------------------------------------+ 4
// |                                      |  
// |                 +--------------+     | 3
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// |                 |              |     |  
// +-----------+     |              |     | 2
//             |     |              |     |  
//             |     |              |     |  
//             |     |              |     |  
//             |     |              |     |  
//             |     |              |     |  
//             |     +------00------+     | 1
//             |                          |  
//             +--------------------------+ 0
// 0           1     2              3     4  
//
// Front view:
//
// +--------------------------------------+ 3
// |                                      |
// |                                      |
// |                                      |
// |                                      |
// |                                      |
// |                                      |
// +-----------------+              +-----+ 2
//                   +------00------+       1
//                   |              |
//                   |              |
//                   +--------------+       0

const float POOL_BORDER = 2;
const float BUILDING_HEIGHT = 5;
const float POOL_LIP = 0.2;
const float CLOCK_HEIGHT = 2.8;
const float CLOCK_RADIUS = 1.0;

const array<float> xs = {
    -0.5 * POOL_WIDTH - 4 * POOL_BORDER,
    -0.5 * POOL_WIDTH - POOL_BORDER,
    -0.5 * POOL_WIDTH,
     0.5 * POOL_WIDTH,
     0.5 * POOL_WIDTH + POOL_BORDER,
};

const array<float> zs = {
    -POOL_BORDER,
    0,
    0.4 * POOL_LENGTH,
    POOL_LENGTH,
    POOL_LENGTH + POOL_BORDER,
};

const array<float> ys = {
    -POOL_DEPTH,
    0,
    POOL_LIP,
    POOL_LIP + BUILDING_HEIGHT,
};

class Triangle {
    Vec3 a;
    Vec3 b;
    Vec3 c;
    uint colour;

    Triangle() {}

    Triangle(Vec3 a, Vec3 b, Vec3 c, uint colour)
    {
        this.a = a;
        this.b = b;
        this.c = c;
        this.colour = colour;
    }
}

array<Triangle> quad(Vec3 tl, Vec3 tr, Vec3 bl, Vec3 br, uint colour)
{
    array<Triangle> triangles = {
        Triangle(tl, bl, tr, colour),
        Triangle(br, tr, bl, colour),
    };
    return triangles;
}

array<Triangle> flatten(array<array<Triangle>> nested_triangles)
{
    array<Triangle> triangles;
    for (uint i = 0; i < nested_triangles.size(); ++i)
        triangles.insertAt(triangles.size(), nested_triangles[i]);
    return triangles;
}

array<Triangle> clock(float z)
{
    array<Triangle> triangles;
    float y = CLOCK_HEIGHT;
    uint segments = 12;
    for (uint i = 0; i < segments; ++i)
    {
        float angle1 = 2 * PI * i / segments;
        float angle2 = 2 * PI * (i + 1) / segments;
        float x1 = CLOCK_RADIUS * sin(angle1);
        float x2 = CLOCK_RADIUS * sin(angle2);
        float y1 = CLOCK_RADIUS * cos(angle1);
        float y2 = CLOCK_RADIUS * cos(angle2);
        triangles.insertLast(Triangle(
            Vec3(x1, y + y1, z),
            Vec3(x2, y + y2, z),
            Vec3(0, y, z),
            0xFFEEEEEE));
    }
    return triangles;
}

array<Triangle> building()
{
    return flatten(array<array<Triangle>>={
        // roof
        quad(
            Vec3(xs[0], ys[3], zs[0]),
            Vec3(xs[4], ys[3], zs[0]),
            Vec3(xs[0], ys[3], zs[4]),
            Vec3(xs[4], ys[3], zs[4]),
            0xFF775555),
        // walls, front door going clockwise
        quad(
            Vec3(xs[1], ys[3], zs[2]),
            Vec3(xs[0], ys[3], zs[2]),
            Vec3(xs[1], ys[2], zs[2]),
            Vec3(xs[0], ys[2], zs[2]),
            0xFF997777),
        // (and also the door)
        quad(
            Vec3((xs[0] + xs[1]) / 2 + 1.0, ys[2] + 2.0, zs[2]),
            Vec3((xs[0] + xs[1]) / 2 - 1.0, ys[2] + 2.0, zs[2]),
            Vec3((xs[0] + xs[1]) / 2 + 1.0, ys[2], zs[2]),
            Vec3((xs[0] + xs[1]) / 2 - 1.0, ys[2], zs[2]),
            0xFF443333),
        quad(
            Vec3(xs[0], ys[3], zs[2]),
            Vec3(xs[0], ys[3], zs[4]),
            Vec3(xs[0], ys[2], zs[2]),
            Vec3(xs[0], ys[2], zs[4]),
            0xFFA28080),
        quad(
            Vec3(xs[0], ys[3], zs[4]),
            Vec3(xs[4], ys[3], zs[4]),
            Vec3(xs[0], ys[2], zs[4]),
            Vec3(xs[4], ys[2], zs[4]),
            0xFFBB9999),
        // interlude to draw the leftmost bit of floor
        quad(
            Vec3(xs[0], ys[2], zs[4]),
            Vec3(xs[1], ys[2], zs[4]),
            Vec3(xs[0], ys[2], zs[2]),
            Vec3(xs[1], ys[2], zs[2]),
            0xFFAAAA99),
        // rest of the walls
        quad(
            Vec3(xs[4], ys[3], zs[4]),
            Vec3(xs[4], ys[3], zs[0]),
            Vec3(xs[4], ys[2], zs[4]),
            Vec3(xs[4], ys[2], zs[0]),
            0xFFAA8888),
        quad(
            Vec3(xs[4], ys[3], zs[0]),
            Vec3(xs[1], ys[3], zs[0]),
            Vec3(xs[4], ys[2], zs[0]),
            Vec3(xs[1], ys[2], zs[0]),
            0xFF997777),
        quad(
            Vec3(xs[1], ys[3], zs[0]),
            Vec3(xs[1], ys[3], zs[2]),
            Vec3(xs[1], ys[2], zs[0]),
            Vec3(xs[1], ys[2], zs[2]),
            0xFFAA8888),
        // floor
        quad(
            Vec3(xs[1], ys[2], zs[4]),
            Vec3(xs[2], ys[2], zs[4]),
            Vec3(xs[1], ys[2], zs[0]),
            Vec3(xs[2], ys[2], zs[0]),
            0xFFAAAA99),
        quad(
            Vec3(xs[3], ys[2], zs[4]),
            Vec3(xs[4], ys[2], zs[4]),
            Vec3(xs[3], ys[2], zs[0]),
            Vec3(xs[4], ys[2], zs[0]),
            0xFFAAAA99),
        quad(
            Vec3(xs[2], ys[2], zs[4]),
            Vec3(xs[3], ys[2], zs[4]),
            Vec3(xs[2], ys[2], zs[3]),
            Vec3(xs[3], ys[2], zs[3]),
            0xFFAAAA99),
        quad(
            Vec3(xs[2], ys[2], zs[1]),
            Vec3(xs[3], ys[2], zs[1]),
            Vec3(xs[2], ys[2], zs[0]),
            Vec3(xs[3], ys[2], zs[0]),
            0xFFAAAA99),
        clock(zs[0]),
        clock(zs[4]),
    });
}

// The T at the bottom/end of the pool
array<Triangle> pool_bar(float x)
{
    const float BAR_BORDER = 2;
    const float BAR_WIDTH = 0.3;

    float x1 = x - 1.5 * BAR_WIDTH;
    float x2 = x - 0.5 * BAR_WIDTH;
    float x3 = x + 0.5 * BAR_WIDTH;
    float x4 = x + 1.5 * BAR_WIDTH;

    float y1 = -POOL_DEPTH;
    float y2 = -3.5 * BAR_WIDTH;
    float y3 = -2.5 * BAR_WIDTH;
    float y4 = -1.5 * BAR_WIDTH;
    float y5 = -0.5 * BAR_WIDTH;

    float z1 = 0;
    float z2 = BAR_BORDER;
    float z3 = BAR_BORDER + BAR_WIDTH;
    float z4 = POOL_LENGTH - BAR_BORDER - BAR_WIDTH;
    float z5 = POOL_LENGTH - BAR_BORDER;
    float z6 = POOL_LENGTH;

    return flatten(array<array<Triangle>>={
        // cross at bottom end of the pool
        quad(
            Vec3(x3, y5, z1),
            Vec3(x2, y5, z1),
            Vec3(x3, y2, z1),
            Vec3(x2, y2, z1),
            0xFF332266),
        quad(
            Vec3(x4, y4, z1),
            Vec3(x1, y4, z1),
            Vec3(x4, y3, z1),
            Vec3(x1, y3, z1),
            0xFF332266),
        // cross at top end of the pool
        quad(
            Vec3(x2, y5, z6),
            Vec3(x3, y5, z6),
            Vec3(x2, y2, z6),
            Vec3(x3, y2, z6),
            0xFF332266),
        quad(
            Vec3(x1, y4, z6),
            Vec3(x4, y4, z6),
            Vec3(x1, y3, z6),
            Vec3(x4, y3, z6),
            0xFF332266),
        // bottom bar
        quad(
            Vec3(x1, y1, z3),
            Vec3(x4, y1, z3),
            Vec3(x1, y1, z2),
            Vec3(x4, y1, z2),
            0xFF332266),
        // long middle bit
        quad(
            Vec3(x2, y1, z4),
            Vec3(x3, y1, z4),
            Vec3(x2, y1, z3),
            Vec3(x3, y1, z3),
            0xFF332266),
        // top bar
        quad(
            Vec3(x1, y1, z5),
            Vec3(x4, y1, z5),
            Vec3(x1, y1, z4),
            Vec3(x4, y1, z4),
            0xFF332266),
    });
}

array<Triangle> pool()
{
    return flatten(array<array<Triangle>>={
        // above water, left going clockwise
        quad(
            Vec3(xs[2], ys[2], zs[1]),
            Vec3(xs[2], ys[2], zs[3]),
            Vec3(xs[2], ys[1], zs[1]),
            Vec3(xs[2], ys[1], zs[3]),
            0xFF888888),
        quad(
            Vec3(xs[2], ys[2], zs[3]),
            Vec3(xs[3], ys[2], zs[3]),
            Vec3(xs[2], ys[1], zs[3]),
            Vec3(xs[3], ys[1], zs[3]),
            0xFFAAAAAA),
        quad(
            Vec3(xs[3], ys[2], zs[3]),
            Vec3(xs[3], ys[2], zs[1]),
            Vec3(xs[3], ys[1], zs[3]),
            Vec3(xs[3], ys[1], zs[1]),
            0xFF888888),
        quad(
            Vec3(xs[3], ys[2], zs[1]),
            Vec3(xs[2], ys[2], zs[1]),
            Vec3(xs[3], ys[1], zs[1]),
            Vec3(xs[2], ys[1], zs[1]),
            0xFF777777),
        // under water, left going clockwise
        quad(
            Vec3(xs[2], ys[1], zs[1]),
            Vec3(xs[2], ys[1], zs[3]),
            Vec3(xs[2], ys[0], zs[1]),
            Vec3(xs[2], ys[0], zs[3]),
            0xFF447799),
        quad(
            Vec3(xs[2], ys[1], zs[3]),
            Vec3(xs[3], ys[1], zs[3]),
            Vec3(xs[2], ys[0], zs[3]),
            Vec3(xs[3], ys[0], zs[3]),
            0xFF5588AA),
        quad(
            Vec3(xs[3], ys[1], zs[3]),
            Vec3(xs[3], ys[1], zs[1]),
            Vec3(xs[3], ys[0], zs[3]),
            Vec3(xs[3], ys[0], zs[1]),
            0xFF447799),
        quad(
            Vec3(xs[3], ys[1], zs[1]),
            Vec3(xs[2], ys[1], zs[1]),
            Vec3(xs[3], ys[0], zs[1]),
            Vec3(xs[2], ys[0], zs[1]),
            0xFF336688),
        // bottom
        quad(
            Vec3(xs[2], ys[0], zs[3]),
            Vec3(xs[3], ys[0], zs[3]),
            Vec3(xs[2], ys[0], zs[1]),
            Vec3(xs[3], ys[0], zs[1]),
            0xFF6699BB),
        // bottom (colour difference so you can tell if you're moving)
        quad(
            Vec3(xs[2], ys[0], 10),
            Vec3(xs[3], ys[0], 10),
            Vec3(xs[2], ys[0], 5),
            Vec3(xs[3], ys[0], 5),
            0xFF6B9EC0),
        quad(
            Vec3(xs[2], ys[0], 20),
            Vec3(xs[3], ys[0], 20),
            Vec3(xs[2], ys[0], 15),
            Vec3(xs[3], ys[0], 15),
            0xFF6B9EC0),
        // bars
        pool_bar(0),
        pool_bar(-LANE_WIDTH),
        pool_bar(LANE_WIDTH),
        pool_bar(-2 * LANE_WIDTH),
        pool_bar(2 * LANE_WIDTH),
        pool_bar(-3 * LANE_WIDTH),
        pool_bar(3 * LANE_WIDTH),
    });
}

array<Triangle> back_wall()
{
    return quad(
        Vec3(-POOL_WIDTH / 2, 0.3, POOL_LENGTH),
        Vec3(POOL_WIDTH / 2, 0.3, POOL_LENGTH),
        Vec3(-POOL_WIDTH / 2, -POOL_DEPTH, POOL_LENGTH),
        Vec3(POOL_WIDTH / 2, -POOL_DEPTH, POOL_LENGTH),
        0xFFBBBBBB);
}

array<Triangle> all_geom()
{
    return flatten(array<array<Triangle>>={
        building(),
        pool(),
    });
}

const array<Triangle> BUILDING_GEOMETRY = building();
const array<Triangle> POOL_GEOMETRY = pool();
