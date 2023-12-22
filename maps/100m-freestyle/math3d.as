#include "../lib/math/math.cpp"

/* Clip a line in homogeneous space against the near plane: z = -w
 * Return false if the line is completely culled.
 */
bool clip_line(Vec4& v1, Vec4& v2, Vec4@ &out o1, Vec4@ &out o2)
{
    const float d1 = v1.z + v1.w;
    const float d2 = v2.z + v2.w;

    // Line is completely behind the near plane, cull it
    if (d1 < 0 and d2 < 0) return false;

    @o1 = v1;
    @o2 = v2;

    // Line is completely in-front of the near plane, keep it
    if (d1 >= 0 and d2 >= 0) return true;

    // Clip the line
    const float f = d2 / (d2 - d1);
    Vec4 intersection = v1 * f + v2 * (1 - f);
    if (d1 < 0) @o1 = intersection;
    else        @o2 = intersection;
    return true;
}

/* Clip a triangle in homogenous space against the near plane: z = -w
 * The half-space z > -w is in-bounds, because projection space is -1 < x,y,z < 1
 * Creates a quad.
 * Return false if the triangle is completely culled.
 */
bool clip_triangle(Vec4& v1, Vec4& v2, Vec4& v3, Vec4@ &out o1, Vec4@ &out o2, Vec4@ &out o3, Vec4@ &out o4)
{
    const float d1 = v1.z + v1.w;
    const float d2 = v2.z + v2.w;
    const float d3 = v3.z + v3.w;

    const int behind = (d1 < EPSILON ? 1 : 0) + (d2 < EPSILON ? 1 : 0) + (d3 < EPSILON ? 1 : 0);

    // Triangle is completely behind the near plane, cull it
    if (behind == 3) return false;

    @o1 = v1;
    @o2 = v2;
    @o3 = v3;
    @o4 = v3;

    // Triangle is completely in-front of the near plane, keep it
    if (d1 > -EPSILON and d2 > - EPSILON and d3 > -EPSILON) return true;

    // One point is behind the near plane, clip it, making a quad
    if (behind == 1)
    {
        if (d1 <= -EPSILON)
        {
            const float f2 = d1 / (d1 - d2);
            const float f3 = d1 / (d1 - d3);
            Vec4@ intersect2 = v1.lerp(v2, f2);
            Vec4@ intersect3 = v1.lerp(v3, f3);
            @o1 = intersect2;
            @o4 = intersect3;
            return true;
        }

        if (d2 <= -EPSILON)
        {
            const float f1 = d2 / (d2 - d1);
            const float f3 = d2 / (d2 - d3);
            Vec4@ intersect1 = v2.lerp(v1, f1);
            Vec4@ intersect3 = v2.lerp(v3, f3);
            @o2 = intersect1;
            @o3 = intersect3;
            return true;
        }

        if (d3 <= -EPSILON)
        {
            const float f1 = d3 / (d3 - d1);
            const float f2 = d3 / (d3 - d2);
            Vec4@ intersect1 = v3.lerp(v1, f1);
            Vec4@ intersect2 = v3.lerp(v2, f2);
            @o3 = intersect2;
            @o4 = intersect1;
            return true;
        }
    }

    // Two points are behind the near plane, clip them
    if (d1 >= EPSILON)
    {
        const float f2 = d1 / (d1 - d2);
        const float f3 = d1 / (d1 - d3);
        Vec4@ intersect2 = v1.lerp(v2, f2);
        Vec4@ intersect3 = v1.lerp(v3, f3);
        @o2 = intersect2;
        @o3 = intersect3;
        @o4 = intersect3;
        return true;
    }

    if (d2 >= EPSILON)
    {
        const float f1 = d2 / (d2 - d1);
        const float f3 = d2 / (d2 - d3);
        Vec4@ intersect1 = v2.lerp(v1, f1);
        Vec4@ intersect3 = v2.lerp(v3, f3);
        @o1 = intersect1;
        @o3 = intersect3;
        @o4 = intersect3;
        return true;
    }

    if (d3 >= EPSILON)
    {
        const float f1 = d3 / (d3 - d1);
        const float f2 = d3 / (d3 - d2);
        Vec4@ intersect1 = v3.lerp(v1, f1);
        Vec4@ intersect2 = v3.lerp(v2, f2);
        @o4 = intersect2;
        @o1 = intersect1;
        @o2 = intersect1;
        return true;
    }

    // Shouldn't get here :)
    return false;
}

Mat4 perspective_projection(float near, float far, float fov, float aspect)
{
    float s = 1.0 / tan(fov / 2);
    float t = aspect * s;
    float f = (far + near) / (far - near);
    float g = -(2 * far * near) / (far - near);
    return Mat4(
        s, 0, 0, 0,
        0, t, 0, 0,
        0, 0, f, g,
        0, 0, 1, 0
    );
}

Mat4 z_rotation_matrix(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return Mat4(
        c, -s, 0, 0,
        s,  c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1
    );
}

Mat4 look_at_matrix(Vec3& pos, float yaw, float pitch, float roll)
{
    Vec3 forward = Vec3(0, 0, 1).rotate_x(pitch).rotate_y(yaw);
    Vec3 right = Vec3(0, 1, 0).cross(forward).normalised();
    Vec3 up = forward.cross(right);

    return z_rotation_matrix(roll) * Mat4(
        right.x  , right.y  , right.z  , -pos.dot(right),
        up.x     , up.y     , up.z     , -pos.dot(up),
        forward.x, forward.y, forward.z, -pos.dot(forward),
        0        , 0        , 0        , 1
    );
}


class Mat4
{
    float a11, a12, a13, a14,
          a21, a22, a23, a24,
          a31, a32, a33, a34,
          a41, a42, a43, a44;

    Mat4() {}

    Mat4(
        float a11, float a12, float a13, float a14,
        float a21, float a22, float a23, float a24,
        float a31, float a32, float a33, float a34,
        float a41, float a42, float a43, float a44
    )
    {
        this.a11 = a11; this.a12 = a12; this.a13 = a13; this.a14 = a14;
        this.a21 = a21; this.a22 = a22; this.a23 = a23; this.a24 = a24;
        this.a31 = a31; this.a32 = a32; this.a33 = a33; this.a34 = a34;
        this.a41 = a41; this.a42 = a42; this.a43 = a43; this.a44 = a44;
    }

    Mat4 transpose() const
    {
        return Mat4(
            a11, a21, a31, a41,
            a12, a22, a32, a42,
            a13, a23, a33, a43,
            a14, a24, a34, a44
        );
    }

    Vec4 opMul(const Vec4& other) const
    {
        return Vec4(
            a11 * other.x + a12 * other.y + a13 * other.z + a14 * other.w,
            a21 * other.x + a22 * other.y + a23 * other.z + a24 * other.w,
            a31 * other.x + a32 * other.y + a33 * other.z + a34 * other.w,
            a41 * other.x + a42 * other.y + a43 * other.z + a44 * other.w
        );
    }

    Vec4 opMul(const Vec3& other) const
    {
        return Vec4(
            a11 * other.x + a12 * other.y + a13 * other.z + a14,
            a21 * other.x + a22 * other.y + a23 * other.z + a24,
            a31 * other.x + a32 * other.y + a33 * other.z + a34,
            a41 * other.x + a42 * other.y + a43 * other.z + a44
        );
    }

    Mat4 opMul(const Mat4& m) const
    {
        return Mat4(
            a11 * m.a11 + a12 * m.a21 + a13 * m.a31 + a14 * m.a41, a11 * m.a12 + a12 * m.a22 + a13 * m.a32 + a14 * m.a42, a11 * m.a13 + a12 * m.a23 + a13 * m.a33 + a14 * m.a43, a11 * m.a14 + a12 * m.a24 + a13 * m.a34 + a14 * m.a44,
            a21 * m.a11 + a22 * m.a21 + a23 * m.a31 + a24 * m.a41, a21 * m.a12 + a22 * m.a22 + a23 * m.a32 + a24 * m.a42, a21 * m.a13 + a22 * m.a23 + a23 * m.a33 + a24 * m.a43, a21 * m.a14 + a22 * m.a24 + a23 * m.a34 + a24 * m.a44,
            a31 * m.a11 + a32 * m.a21 + a33 * m.a31 + a34 * m.a41, a31 * m.a12 + a32 * m.a22 + a33 * m.a32 + a34 * m.a42, a31 * m.a13 + a32 * m.a23 + a33 * m.a33 + a34 * m.a43, a31 * m.a14 + a32 * m.a24 + a33 * m.a34 + a34 * m.a44,
            a41 * m.a11 + a42 * m.a21 + a43 * m.a31 + a44 * m.a41, a41 * m.a12 + a42 * m.a22 + a43 * m.a32 + a44 * m.a42, a41 * m.a13 + a42 * m.a23 + a43 * m.a33 + a44 * m.a43, a41 * m.a14 + a42 * m.a24 + a43 * m.a34 + a44 * m.a44
        );
    }

    string opConv() const
    {
        return (
            "Mat4("
            + "\n    " + str(a11) + "," + str(a21) + "," + str(a31) + "," + str(a41)
            + "\n    " + str(a12) + "," + str(a22) + "," + str(a32) + "," + str(a42)
            + "\n    " + str(a13) + "," + str(a23) + "," + str(a33) + "," + str(a43)
            + "\n    " + str(a14) + "," + str(a24) + "," + str(a34) + "," + str(a44)
            + "\n)"
        );
    }
}


class Vec4
{
    float x, y, z, w;

    Vec4() {}

    Vec4(float x, float y, float z, float w)
    {
        this.x = x;
        this.y = y;
        this.z = z;
        this.w = w;
    }

    Vec4(Vec3 xyz, float w)
    {
        this.x = xyz.x;
        this.y = xyz.y;
        this.z = xyz.z;
        this.w = w;
    }

    Vec4 lerp(const Vec4& other, float f) const
    {
        return Vec4(
            x + f * (other.x - x),
            y + f * (other.y - y),
            z + f * (other.z - z),
            w + f * (other.w - w)
        );
    }

    Vec4 opAdd(const Vec4& other) const
    {
        return Vec4(
            x + other.x,
            y + other.y,
            z + other.z,
            w + other.w
        );
    }

    Vec4 opSub(const Vec4& other) const
    {
        return Vec4(
            x - other.x,
            y - other.y,
            z - other.z,
            w - other.w
        );
    }

    Vec4 opMul(Vec4& other) const
    {
        return Vec4(
            x * other.x,
            y * other.y,
            z * other.z,
            w * other.w
        );
    }

    Vec4 opMul(float value) const
    {
        return Vec4(
            x * value,
            y * value,
            z * value,
            w * value
        );
    }

    Vec4 opDiv(float value) const
    {
        return Vec4(
            x / value,
            y / value,
            z / value,
            w / value
        );
    }

    string opConv() const
    {
        return "Vec4(" + str(x) + "," + str(y) + "," + str(z) + "," + str(w) + ")";
    }
}


class Vec3
{
    float x, y, z;

    Vec3() {}

    Vec3(Vec4& other)
    {
        x = other.x;
        y = other.y;
        z = other.z;
    }

    Vec3(float x, float y, float z)
    {
        this.x = x;
        this.y = y;
        this.z = z;
    }

    Vec3 rotate_x(float angle) const
    {
        const float c = cos(angle);
        const float s = sin(angle);
        return Vec3(
            x,
            y * c - z * s,
            y * s + z * c
        );
    }

    Vec3 rotate_y(float angle) const
    {
        const float c = cos(angle);
        const float s = sin(angle);
        return Vec3(
            z * s + x * c,
            y,
            z * c - x * s
        );
    }

    Vec3 rotate_z(float angle) const
    {
        const float c = cos(angle);
        const float s = sin(angle);
        return Vec3(
            x * c - y * s,
            x * s + y * c,
            z
        );
    }

    Vec3 cross(Vec3& other) const
    {
        return Vec3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        );
    }

    float dot(Vec3& other) const
    {
        return x * other.x + y * other.y + z * other.z;
    }

    float magnitude() const
    {
        return sqrt(x * x + y * y + z * z);
    }

    float magnitude_sqr() const
    {
        return x * x + y * y + z * z;
    }

    Vec3 normalised() const
    {
        float m = magnitude();
        if (m == 0) return Vec3(1, 0, 0);
        return this / m;
    }

    Vec3 lerp(const Vec3& other, float f) const
    {
        return Vec3(
            x + f * (other.x - x),
            y + f * (other.y - y),
            z + f * (other.z - z)
        );
    }

    Vec3 opNeg() const
    {
        return Vec3(-x, -y, -z);
    }

    Vec3 opAdd(const Vec3& other) const
    {
        return Vec3(
            x + other.x,
            y + other.y,
            z + other.z
        );
    }

    void opAddAssign(const Vec3 &in other)
    {
        x += other.x;
        y += other.y;
        z += other.z;
    }

    Vec3 opSub(const Vec3& other) const
    {
        return Vec3(
            x - other.x,
            y - other.y,
            z - other.z
        );
    }

    Vec3 opMul(Vec3& other) const
    {
        return Vec3(
            x * other.x,
            y * other.y,
            z * other.z
        );
    }

    Vec3 opMul_r(float value) const
    {
        return Vec3(
            x * value,
            y * value,
            z * value
        );
    }

    Vec3 opMul(float value) const
    {
        return Vec3(
            x * value,
            y * value,
            z * value
        );
    }

    Vec3 opDiv(float value) const
    {
        return Vec3(
            x / value,
            y / value,
            z / value
        );
    }

    bool opEquals(const Vec3& other) const
    {
        return x == other.x and y == other.y and z == other.z;
    }

    string opConv() const
    {
        return "Vec3(" + str(x) + "," + str(y) + "," + str(z) + ")";
    }
}
