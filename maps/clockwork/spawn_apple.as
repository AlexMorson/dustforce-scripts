class script
{
    [entity] int apple_id;
    [position,mode:world,layer:19,y:spawn_y] float spawn_x;
    [hidden] float spawn_y;

    void entity_on_remove(entity@ e)
    {
        if (e.id() == apple_id)
        {
            entity@ apple = create_entity("hittable_apple");
            apple.x(spawn_x);
            apple.y(spawn_y);
            get_scene().add_entity(apple);
        }
    }
}
