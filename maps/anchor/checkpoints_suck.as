class script
{
    [text|tooltip:"because the camera ends up in a dumb position"] int specifically_after_the_level_ends;

    void on_level_end()
    {
        entity@ checkpoint = entity_by_id(specifically_after_the_level_ends);
        get_scene().remove_entity(checkpoint);
    }
}
