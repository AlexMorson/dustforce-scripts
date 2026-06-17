class script {
    [entity] int apple_id;

    void step(int) {
        controllable@ p = controller_controllable(0);
        if (p !is null) {
            dustman@ d = p.as_dustman();
            if (d !is null) {
                if (d.y() > 2000) {
                    string c = d.character();
                    if (c == "dustman" or c == "dustgirl") {
                        d.set_speed_xy(d.x_speed(), -2500);
                    } else if (c == "dustkid") {
                        d.set_speed_xy(d.x_speed(), -2700);
                    } else if (c == "dustworth") {
                        d.set_speed_xy(d.x_speed(), -2350);
                    } else {
                        d.set_speed_xy(d.x_speed(), -9001);
                    }
                    d.dash(d.dash_max());

                    if (d.x() > 12000) {
                        d.set_speed_xy(d.x_speed(), d.y_speed() - 500);
                    }
                }
                if (d.x() > 12000) {
                    d.x(d.x() - (d.x() - 12000) / 100);
                    d.set_speed_xy(d.x_speed() - (d.x() - 12000) / 10, d.y_speed());
                }
            }
        }

        entity@ apple_entity = entity_by_id(apple_id);
        if (apple_entity !is null) {
            controllable@ apple = apple_entity.as_controllable();
            if (apple !is null) {
                if (apple.x() > 12170) {
                    apple.x(apple.x() - (apple.x() - 12170) / 50);
                    apple.set_speed_xy(apple.x_speed() - (apple.x() - 12170) / 10, apple.y_speed());
                }

                if (apple.y() > 2000) {
                    if (apple.x() > 12000) {
                        apple.x(12170);
                        apple.set_speed_xy(apple.x_speed(), -1700);
                    } else {
                        apple.set_speed_xy(apple.x_speed(), -1420);
                    }
                }
            }
        }
    }
}
