class script { }

class RemoteForce : trigger_base {
    [entity,camera] int camera_node_id;

    void activate(controllable@ c) {
        int player = c.player_index();
        if (player < 0) return;

        entity@ node_entity = entity_by_id(camera_node_id);
        if (node_entity is null) return;

        camera_node@ node = node_entity.as_camera_node();
        if (node is null) return;

        camera@ cam = get_camera(player);
        if (cam.current_node().as_entity().is_same(node_entity)
            or cam.next_node().as_entity().is_same(node_entity)) return;

        cam.try_connect(node);
    }
}
