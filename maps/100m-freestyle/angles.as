#include "../lib/math/math.cpp"

class Euler
{
    float yaw, pitch, roll;

    Euler() {}

    Euler(float yaw, float pitch, float roll)
    {
        this.yaw = ((yaw + PI) % (2 * PI)) - PI;
        this.pitch = pitch;
        this.roll = roll;
    }

    Euler slerp(const Euler& other, float t) const
    {
        // I guess I'm using a different convention for my rendering than
        // the wikipedia page I copied this quaternion code from, because
        // I needed to invert the pitch to get smooth interpolations.
        // This definitely didn't take me a whole day to figure out...
        Quaternion src = Euler(yaw, -pitch, roll).to_quaternion();
        Quaternion dst = Euler(other.yaw, -other.pitch, other.roll).to_quaternion();
        Euler result = src.slerp(dst, t).to_euler();
        return Euler(result.yaw, -result.pitch, result.roll);
    }

    bool opEquals(const Euler& other) const
    {
        return (
            abs(yaw - other.yaw) < 0.001 and
            abs(pitch - other.pitch) < 0.001 and
            abs(roll - other.roll) < 0.001
        );
    }

    string opConv() const
    {
        return "Euler(" + yaw + ", " + pitch + ", " + roll + ")";
    }

    Quaternion to_quaternion() const
    {
        float cr = cos(0.5 * roll);
        float sr = sin(0.5 * roll);
        float cp = cos(0.5 * pitch);
        float sp = sin(0.5 * pitch);
        float cy = cos(0.5 * yaw);
        float sy = sin(0.5 * yaw);

        Quaternion quaternion;
        quaternion.w = cr * cp * cy + sr * sp * sy;
        quaternion.x = sr * cp * cy - cr * sp * sy;
        quaternion.y = cr * sp * cy + sr * cp * sy;
        quaternion.z = cr * cp * sy - sr * sp * cy;
        return quaternion;
    }
}

class Quaternion
{
    float w, x, y, z;

    Quaternion() {}

    Quaternion(float w, float x, float y, float z)
    {
        this.w = w;
        this.x = x;
        this.y = y;
        this.z = z;
    }

    Quaternion lerp(const Quaternion& other, float t) const
    {
        Quaternion quaternion;
        quaternion.w = (1 - t) * w + t * other.w;
        quaternion.x = (1 - t) * x + t * other.x;
        quaternion.y = (1 - t) * y + t * other.y;
        quaternion.z = (1 - t) * z + t * other.z;
        return quaternion;
    }

    Quaternion slerp(const Quaternion& other, float t) const
    {
        float d = w * other.w + x * other.x + y * other.y + z * other.z;
        if (d >= 1)
            return this;
        Quaternion a_prime = this;
        if (d < 0)
            a_prime = -this;
        float theta = acos(abs(d));
        if (sin(theta) <= 0)
            return this;
        return (a_prime * sin((1 - t) * theta) + other * sin(t * theta)) * (1 / sin(theta));
    }

    Euler to_euler() const
    {
        // roll (x-axis rotation)
        double sinr_cosp = 2 * (w * x + y * z);
        double cosr_cosp = 1 - 2 * (x * x + y * y);
        float roll = atan2(sinr_cosp, cosr_cosp);

        // pitch (y-axis rotation)
        double sinp = sqrt(1 + 2 * (w * y - x * z));
        double cosp = sqrt(1 - 2 * (w * y - x * z));
        float pitch = 2 * atan2(sinp, cosp) - PI / 2;

        // yaw (z-axis rotation)
        double siny_cosp = 2 * (w * z + x * y);
        double cosy_cosp = 1 - 2 * (y * y + z * z);
        float yaw = atan2(siny_cosp, cosy_cosp);

        return Euler(yaw, pitch, roll);
    }

    Quaternion opNeg() const
    {
        return Quaternion(-w, -x, -y, -z);
    }

    Quaternion opAdd(const Quaternion& other) const
    {
        return Quaternion(
            w + other.w,
            x + other.x,
            y + other.y,
            z + other.z
        );
    }

    Quaternion opMul(float other) const
    {
        return Quaternion(other * w, other * x, other * y, other * z);
    }

    string opConv() const
    {
        return "Quaternion(" + w + ", " + x + ", " + y + ", " + z + ")";
    }
}
