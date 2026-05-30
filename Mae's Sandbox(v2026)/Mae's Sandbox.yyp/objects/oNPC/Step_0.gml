if !instance_exists(obj_dialogue_manager) exit;
var _mgr = obj_dialogue_manager;

// -------------------------
// JUST ENDED GUARD
// Prevents same E press that ended dialogue from re-triggering it
// -------------------------
if _mgr.dialogue_just_ended exit;

// -------------------------
// DYNAMIC FLAG CHECK
// -------------------------
var _met_flag    = "met_" + npc_id;
var _first_node  = npc_id + "_greet";
var _return_node = npc_id + "_greet_return";
dialogue_node = dialogue_get_flag(_met_flag, false) ? _return_node : _first_node;

// -------------------------
// PROMPT VISIBILITY
// Must run before any exits so it always updates
// -------------------------
var _dist = point_distance(x, y, oMae.x, oMae.y);
if instance_exists(prompt_inst) {
    prompt_inst.visible_target = (_dist < trigger_range) && !_mgr.active;
}

// -------------------------
// FLAG TRACKING — BEFORE active exit
// This must run every frame to catch the moment dialogue ends
// -------------------------
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
    dialogue_was_active = false;
}

if _mgr.active exit;
if _dist > trigger_range exit;

// Only closest NPC triggers
var _closest = noone;
var _closest_dist = 999999;
with (oNPC) {
    var _d = point_distance(x, y, oMae.x, oMae.y);
    if _d < _closest_dist {
        _closest_dist = _d;
        _closest = id;
    }
}
if _closest != id exit;

// AUTO trigger
if trigger_type == "auto" && !triggered_auto {
    triggered_auto = true;
    dialogue_start(dialogue_node);
    dialogue_was_active = true;
}

// PRESS trigger
if trigger_type == "press" {
    if keyboard_check_pressed(ord("E")) {
        dialogue_start(dialogue_node);
        dialogue_was_active = true;
    }
}