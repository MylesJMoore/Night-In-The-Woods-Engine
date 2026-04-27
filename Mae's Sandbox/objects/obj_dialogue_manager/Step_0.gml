if !active exit;

var _bubble = bubble_inst;
if !instance_exists(_bubble) exit;

// -------------------------
// TYPEWRITER
// -------------------------
var _chars = _bubble.chars;
var _total = array_length(_chars);

if char_index < _total {
    typewriter_timer += typewriter_speed;
    while typewriter_timer >= 1 && char_index < _total {
        _chars[char_index].revealed = true;
        _chars[char_index].alpha = 1;
        char_index++;
        typewriter_timer--;
		
		// Play sound on each revealed character
        // Skip spaces and punctuation for cleaner sound
        var _revealed_char = _chars[char_index - 1].char;
        if _revealed_char != " " && _revealed_char != "." 
        && _revealed_char != "," && _revealed_char != "!" 
        && _revealed_char != "?" {
            var _pitch = typewriter_pitch_vary 
                         ? random_range(0.9, 1.1) 
                         : 1.0;
            audio_play_sound(typewriter_sound, 1, false);
            audio_sound_pitch(typewriter_sound, _pitch);
        }
    }
}

// -------------------------
// ADVANCE / DISMISS / CHOICES
// -------------------------
if instance_exists(bubble_inst) {
    var _is_choice = bubble_inst.is_choice;
    var _opts      = bubble_inst.choice_options;
    var _count     = array_length(_opts);
    var _style     = bubble_inst.choice_style;

    if _is_choice {
        // Capture index BEFORE navigation so we can detect changes
        var _prev_index = bubble_inst.choice_index;

        // ---- NAVIGATION ----
        if _style == "vertical" {
            if keyboard_check_pressed(vk_up) || keyboard_check_pressed(ord("W")) {
                bubble_inst.choice_index = (bubble_inst.choice_index - 1 + _count) mod _count;
            }
            if keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S")) {
                bubble_inst.choice_index = (bubble_inst.choice_index + 1) mod _count;
            }
        } else if _style == "horizontal" {
            if keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A")) {
                bubble_inst.choice_index = (bubble_inst.choice_index - 1 + _count) mod _count;
            }
            if keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D")) {
                bubble_inst.choice_index = (bubble_inst.choice_index + 1) mod _count;
            }
        } else if _style == "horizontal_extended" {
            if keyboard_check_pressed(vk_left) || keyboard_check_pressed(ord("A")) {
                bubble_inst.choice_index = (bubble_inst.choice_index - 1 + _count) mod _count;
            }
            if keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D")) {
                bubble_inst.choice_index = (bubble_inst.choice_index + 1) mod _count;
            }
        }

        // If index changed and style is extended — reload option text with typewriter
        if bubble_inst.choice_index != _prev_index && _style == "horizontal_extended" {
            dialogue_bubble_set_option(
                bubble_inst,
                _opts[bubble_inst.choice_index].text
            );
        }

        // ---- CONFIRM ----
        if keyboard_check_pressed(interact_key) {
            var _chosen = _opts[bubble_inst.choice_index];
            dialogue_start(_chosen.goto);
        }

    } else {
        // ---- NORMAL LINE ----
        var _line_chars = bubble_inst.chars;
        var _line_total = array_length(_line_chars);

        if keyboard_check_pressed(interact_key) {
            if char_index < _line_total {
                // Snap typewriter to full line
                for (var _i = 0; _i < _line_total; _i++) {
                    _line_chars[_i].revealed = true;
                    _line_chars[_i].alpha = 1;
                }
                char_index = _line_total;
            } else {
                dialogue_next_line();
            }
        }
    }
}