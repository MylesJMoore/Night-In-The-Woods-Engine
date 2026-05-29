sprite_index = spr_npc_idle;
facing = -1;
image_xscale = facing;

// Dialogue config — override npc_id and dialogue_node in room Creation Code
npc_id = "npc_01";
dialogue_node = "npc_01_greet";
trigger_type = "press";
trigger_range = 300;
triggered_auto = false;
dialogue_was_active = false;
prompt_inst = instance_create_layer(x, y, "Instances", obj_dialogue_prompt);
prompt_inst.follow_inst = id;

// Dialogue Renderer Config
default_renderer   = "bubble"; // override to "box" per NPC in Creation Code
default_box_layout = "full";