class script {
    void entity_on_remove(entity@ e)
    {
        int id = e.id();
        if (id == 0) return;

        message@ msg = create_message();
        msg.set_int("id", id);
        broadcast_message("entity_on_remove", msg);
    }
}

class Respawner : trigger_base, callback_base
{
    scene@ g;
    scripttrigger@ self;

    [entity] int entity_id;
    [text] int time = 0;
    [text] bool heal = false;

    [hidden] Entity entity_data;
    [hidden] AIController ai_data;

    [hidden] int timer = 0;

    Respawner()
    {
        @g = get_scene();
        add_broadcast_receiver("entity_on_remove", this, "entity_on_remove");
    }

    void init(script@ s, scripttrigger@ self)
    {
        @this.self = self;
    }

    void step()
    {
        if (timer > 0 and --timer == 0)
        {
            respawn();
        }

        if (heal)
        {
            entity@ e = entity_by_id(entity_id);
            if (e is null) return;
            controllable@ c = e.as_controllable();
            if (c !is null) c.life(100);
        }

    }

    void entity_on_remove(string, message@ msg)
    {
        if (msg.get_int("id") != entity_id) return;

        if (time == 0) respawn();
        else timer = time;
    }

    void respawn()
    {
        entity@ e = entity_data.create();
        if (e is null) return;

        scene@ g = get_scene();
        g.add_entity(e);
        entity_id = e.id();

        entity@ ai = ai_data.create(e.id());
        if (ai is null) return;

        g.add_entity(ai);
    }

    void editor_step()
    {
        entity@ e = entity_by_id(entity_id);
        if (e is null)
        {
            entity_data = Entity();
            ai_data = AIController();
            return;
        }

        entity_data = Entity(e);

        // Look for a matching ai controller
        int n = g.get_entity_collision(e.y(), e.y(), e.x(), e.x(), 15);
        for (int i=0; i<n; ++i)
        {
            entity@ f = g.get_entity_collision_index(i);
            if (f.type_name() != "AI_controller") continue;

            varstruct@ vars = f.vars();
            if (vars.get_var("puppet_id").get_int32() != entity_id) continue;

            ai_data = AIController(f);
            return;
        }

        // No ai controller found
        ai_data = AIController();
    }

    void editor_draw(float)
    {
        entity@ e = entity_by_id(entity_id);
        if (e is null) return;

        get_scene().draw_line_world(22, 0, self.x(), self.y(), e.x(), e.y(), 4, 0xFFFF0000);
    }
}

class Entity
{
    [text] float x;
    [text] float y;
    [text] string type;

    Entity() {}

    Entity(entity@ e)
    {
        x = e.x();
        y = e.y();
        type = e.type_name();
    }

    entity@ create()
    {
        if (type == "") return null;

        entity@ e = create_entity(type);
        e.x(x);
        e.y(y);
        return e;
    }
}

class AIController
{
    [text] float x;
    [text] float y;

    [text] array<float> node_xs;
    [text] array<float> node_ys;
    [text] array<int> wait_times;

    AIController() {}

    AIController(entity@ ai)
    {
        x = ai.x();
        y = ai.y();

        varstruct@ vars = ai.vars();

        vararray@ ai_nodes = vars.get_var("nodes").get_array();
        vararray@ ai_wait_times = vars.get_var("nodes_wait_time").get_array();

        for (uint i=0; i<ai_nodes.size(); ++i)
        {
            varvalue@ var = ai_nodes.at(i);
            node_xs.insertLast((var.get_vec2_x()));
            node_ys.insertLast(var.get_vec2_y());
        }

        for (uint i=0; i<ai_wait_times.size(); ++i)
        {
            varvalue@ var = ai_wait_times.at(i);
            wait_times.insertLast(var.get_int32());
        }
    }

    entity@ create(int puppet_id)
    {
        if (node_xs.size() == 0) return null;

        entity@ ai = create_entity("AI_controller");

        ai.x(x);
        ai.y(y);

        varstruct@ vars = ai.vars();

        vars.get_var("puppet_id").set_int32(puppet_id);

        vararray@ ai_nodes = vars.get_var("nodes").get_array();
        vararray@ ai_wait_times = vars.get_var("nodes_wait_time").get_array();

        int n = int(min(node_xs.size(), node_ys.size()));
        ai_nodes.resize(n);
        for (int i=0; i<n; ++i)
        {
            ai_nodes.at(i).set_vec2(node_xs[i], node_ys[i]);
        }

        n = wait_times.size();
        ai_wait_times.resize(n);
        for (int i=0; i<n; ++i)
        {
            ai_wait_times.at(i).set_int32(wait_times[i]);
        }

        return ai;
    }
}
