#include "lib/std.cpp"
#include "lib/math/math.cpp"

class Camera {

    [text] bool draw_camera = true;
    [text] bool require_connect = false;
    [text] float node_search_dist = 1000;

    [hidden] int active_node_id;
    [hidden] int target_node_id;

    [hidden] float shake_timer = 0;

    scene@ g;
    camera@ c;

    entity@ active_node;
    entity@ target_node;
    float puppet_x, puppet_y;
    float puppet_vx, puppet_vy;
    float puppet_vy_prev;
    float offset_x, offset_y;
    float target_x, target_y;
    float camera_x, camera_y;
    float camera_vx, camera_vy;
    float target_screen_height = 1080;
    float screen_height = 1080;

    bool in_level = false;

    Camera() {
        @g = get_scene();
        @c = get_camera(0);
        c.script_camera(false);
    }

    void reset() {
        in_level = false;
    }

    void init(float x, float y) {
        if (in_level) {
            @active_node = entity_by_id(active_node_id);
            @target_node = entity_by_id(target_node_id);
        } else {
            in_level = true;
        }

        c.script_camera(true);
        move_cameras(x, y, 0, 0);
        camera_x = target_x;
        camera_y = target_y;
        camera_vx = 0;
        camera_vy = 0;
        screen_height = target_screen_height;
        c.x(target_x);
        c.y(target_y);
        c.prev_x(c.x());
        c.prev_y(c.y());
        c.scale_x(c.screen_height() / screen_height);
        c.scale_y(c.screen_height() / screen_height);
        c.prev_scale_x(c.scale_x());
        c.prev_scale_y(c.scale_y());
    }

    void move_cameras(float x, float y, float vx, float vy) {
        if (not in_level) return;

        puppet_x = x;
        puppet_y = y;
        puppet_vx = vx;
        puppet_vy = vy;

        @target_node = null;

        float active_dist_squared = 1e20;
        entity@ closest;
        bool force = false;
        entity@ new_active_node;

        int n = g.get_entity_collision(puppet_y-node_search_dist, puppet_y+node_search_dist, puppet_x-node_search_dist, puppet_x+node_search_dist, 12);
        for (int i=0; i<n; ++i) {
            entity@ e = g.get_entity_collision_index(i);
            float ds = pow(e.x() - puppet_x, 2) + pow(e.y() - puppet_y, 2);
            bool in_range = ds < pow(e.vars().get_var(4).get_int32(), 2);
            if (e.vars().get_var(2).get_int32() == 5 and in_range) { // Force node
                if (not force or ds < active_dist_squared) { // If we have not seen a closer force node
                    active_dist_squared = ds;
                    @active_node = @e;
                    force = true;
                }
            } else if (@active_node is null and (not require_connect or (e.vars().get_var(2).get_int32() == 3 and in_range))) {
                if (ds < active_dist_squared) {
                    active_dist_squared = ds;
                    @new_active_node = @e;
                }
            }
        }

        if (@new_active_node !is null) {
            if (@active_node is null) {
                @active_node = @new_active_node;
            }
            @new_active_node = null;
        }

        if (@active_node !is null) {
            float dist_squared = 1e20;
            target_x = active_node.x();
            target_y = active_node.y();
            float blend = 0;

            vararray@ control_width = active_node.vars().get_var(1).get_array();
            for (int i=0; i<control_width.size(); ++i) {
                float control_len = control_width.at(i).get_vec2_x();
                float control_dir = control_width.at(i).get_vec2_y();
                float control_x = active_node.x() + control_len * sin(DEG2RAD * control_dir);
                float control_y = active_node.y() - control_len * cos(DEG2RAD * control_dir);
                float path_x, path_y, lambda;
                closest_point_on_line_segment(puppet_x, puppet_y, active_node.x(), active_node.y(), control_x, control_y, path_x, path_y, lambda);
                float ds = dist_sqr(puppet_x, puppet_y, path_x, path_y);
                if (ds < dist_squared) {
                    dist_squared = ds;
                    target_x = path_x;
                    target_y = path_y;
                    blend = lambda;
                }
            }

            vararray@ adjacent_node_ids = active_node.vars().get_var(0).get_array();
            for (int i=0; i<adjacent_node_ids.size(); ++i) {
                entity@ adjacent_node = entity_by_id(adjacent_node_ids.at(i).get_int32());
                float path_x, path_y, lambda;
                closest_point_on_line_segment(puppet_x, puppet_y, active_node.x(), active_node.y(), adjacent_node.x(), adjacent_node.y(), path_x, path_y, lambda);
                float ds = dist_sqr(puppet_x, puppet_y, path_x, path_y);
                if (adjacent_node.vars().get_var(2).get_int32() == 4) { // Interest node
                    vararray@ c_node_ids = adjacent_node.vars().get_var(0).get_array();
                    vararray@ test_width = adjacent_node.vars().get_var(3).get_array();
                    // Search for the active node
                    for (int j=0; j<c_node_ids.size(); ++j) {
                        if (c_node_ids.at(j).get_int32() == active_node.id()) {
                            float dist_to_node = distance(path_x, path_y, adjacent_node.x(), adjacent_node.y());
                            if (dist_to_node <= test_width.at(j).get_int32()) {
                                @new_active_node = @adjacent_node;
                            }
                            break;
                        }
                    }
                }
                if (lambda > 0 and ds < dist_squared) {
                    dist_squared = ds;
                    target_x = path_x;
                    target_y = path_y;
                    blend = lambda;
                    @target_node = @adjacent_node;

                    if (lambda > 0.6) {
                        @new_active_node = @adjacent_node;
                    }

                }
            }

            if (@target_node !is null) {
                if (active_node.vars().get_var(2).get_int32() == 4) { // Interest
                    vararray@ c_node_ids = active_node.vars().get_var(0).get_array();
                    vararray@ test_width = active_node.vars().get_var(3).get_array();
                    // Search for the target node
                    for (int i=0; i<c_node_ids.size(); ++i) {
                        if (c_node_ids.at(i).get_int32() == target_node.id()) {
                            float dist_to_node = distance(target_x, target_y, active_node.x(), active_node.y());
                            if (dist_to_node <= test_width.at(i).get_int32()) {
                                @new_active_node = null;
                                target_x = active_node.x();
                                target_y = active_node.y();
                                blend = 0;
                            }
                            break;
                        }
                    }
                }
            } else {
                if (active_node.vars().get_var(2).get_int32() == 2) { // Detach
                    @active_node = null;
                    return;
                }
            }

            if (@new_active_node !is null) {
                blend = 1 - blend;
                @target_node = @active_node;
                @active_node = @new_active_node;

                if (active_node.vars().get_var(2).get_int32() == 4) { // Interest
                    vararray@ c_node_ids = active_node.vars().get_var(0).get_array();
                    vararray@ test_width = active_node.vars().get_var(3).get_array();
                    // Search for the target node
                    for (int i=0; i<c_node_ids.size(); ++i) {
                        if (c_node_ids.at(i).get_int32() == target_node.id()) {
                            float dist_to_node = distance(target_x, target_y, active_node.x(), active_node.y());
                            if (dist_to_node <= test_width.at(i).get_int32()) {
                                @new_active_node = null;
                                target_x = active_node.x();
                                target_y = active_node.y();
                                blend = 0;
                            }
                            break;
                        }
                    }
                }
            }

            if (target_node !is null) {
                target_screen_height = active_node.vars().get_var(5).get_int32() * (1 - blend) + target_node.vars().get_var(5).get_int32() * blend;
            } else {
                target_screen_height = active_node.vars().get_var(5).get_int32();
            }
            screen_height = (19 * screen_height + target_screen_height) / 20;
            c.scale_x(c.screen_height() / screen_height);
            c.scale_y(c.screen_height() / screen_height);

        } else {
            target_x = puppet_x;
            target_y = puppet_y;
        }

        float shake_angle = rand() % 360;
        float shake_x = shake_timer * cos(shake_angle);
        float shake_y = shake_timer * sin(shake_angle);
        if (shake_timer > 0) --shake_timer;

        offset_x = (9 * offset_x + 0.2 * puppet_vx) / 10;
        offset_y = (9 * offset_y + 0.2 * puppet_vy) / 10;

        camera_vx += 0.01 * (offset_x + target_x - camera_x);
        camera_vy += 0.01 * (offset_y + target_y - camera_y);

        camera_vx *= min(1, 0.7 + abs(puppet_vx / 12000));
        camera_vy *= min(1, 0.7 + abs(puppet_vy / 12000));

        camera_x += camera_vx;
        camera_y += camera_vy;

        c.x(camera_x + shake_x);
        c.y(camera_y + shake_y);

        if (@active_node !is null) active_node_id = active_node.id();
        if (@target_node !is null) target_node_id = target_node.id();
    }

    void draw(float subframe) {
        if (not draw_camera) return;

        if (@active_node !is null) {
            if (@target_node !is null) {
                g.draw_line_world(22, 0, active_node.x(), active_node.y(), target_node.x(), target_node.y(), 4, 0x88888888);
                g.draw_rectangle_world(22, 0, target_node.x()-5, target_node.y()-5, target_node.x()+5, target_node.y()+5, 0, 0xFFFF0000);
            }
            g.draw_rectangle_world(22, 0, active_node.x()-5, active_node.y()-5, active_node.x()+5, active_node.y()+5, 0, 0xFF00FF00);
        }
        g.draw_rectangle_world(22, 0, c.x()-5, c.y()-5, c.x()+5, c.y()+5, 0, 0xFF888888);
        g.draw_rectangle_world(22, 0, puppet_x+0.2*puppet_vx-5, puppet_y+0.2*puppet_vy-5, puppet_x+0.2*puppet_vx+5, puppet_y+0.2*puppet_vy+5, 0, 0xFF888888);
    }
}

void closest_point_on_line_segment(
    float &in x, float &in y,
    float &in px, float &in py,
    float &in qx, float &in qy,
    float &out sx, float &out sy,
    float &out lambda
) {
    float qx_px = qx - px;
    float qy_py = qy - py;
    float denom = qx_px * qx_px + qy_py * qy_py;
    if (denom == 0) {
        lambda = 0;
        sx = px;
        sy = py;
    } else {
        lambda = ((x - px) * qx_px + (y - py) * qy_py) / denom;
        lambda = max(0, min(1, lambda));
        sx = px + lambda * qx_px;
        sy = py + lambda * qy_py;
    }
}
