// Singleton — destroy duplicates, keep first
if instance_number(obj_dialogue_manager) > 1 {
    instance_destroy();
    exit;
}
instance_persistent = true;

// Init flags only once
if !variable_struct_exists(self, "flags") {
    flags = {};
}

// -------------------------
// STATE
// -------------------------
active = false;          // is dialogue currently running
dialogue_data = undefined; // loaded JSON
current_node = undefined;  // current node struct
line_index = 0;            // which line we're on
char_index = 0;            // typewriter progress
typewriter_speed = 2;      // chars revealed per frame
typewriter_timer = 0;

// Input
interact_key = ord("E");

// Reference to active bubble
bubble_inst = noone;

// -------------------------
// LOAD DIALOGUE FILE
// -------------------------
var _buffer = buffer_load(working_directory + "dialogue_test.json");
if _buffer != -1 {
    var _json_string = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);
    dialogue_data = json_parse(_json_string);
} else {
    // DO NOTHING
}

// -------------------------
// SOUND
// -------------------------
typewriter_sound = snd_typewriter; // swap this per game
typewriter_pitch_vary = true;      // slight random pitch for personality