// Follow speaker
if instance_exists(speaker_inst) {
    x = speaker_inst.x;
    y = speaker_inst.y - bubble_offset_y;
}

// Text effects
var _time = current_time * 0.005;
for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;
    switch (_c.effect) {
        case "wave":
            _c.y_off = sin(_time + _i * 0.4) * 3;
        break;
        case "shake":
            _c.x_off = random_range(-1.5, 1.5);
            _c.y_off = random_range(-1.5, 1.5);
        break;
        default:
            _c.x_off = 0;
            _c.y_off = 0;
        break;
    }
}

// Horizontal extended typewriter
if is_choice && choice_style == "horizontal_extended" {
    if choice_typewriter_index < array_length(choice_display_chars) {
        choice_typewriter_timer += choice_typewriter_speed;
        while choice_typewriter_timer >= 1
              && choice_typewriter_index < array_length(choice_display_chars) {
            choice_display_chars[choice_typewriter_index].revealed = true;
            choice_display_chars[choice_typewriter_index].alpha = 1;
            choice_typewriter_index++;
            choice_typewriter_timer--;
        }
    }
}