function dialogue_parse_text(text) {
    var _chars = [];
    var _len = string_length(text);
    var _i = 1;
    
    // Active style flags
    var _italic = false;
    var _effect = "none";
    
    while _i <= _len {
        // Check for opening tag
        if string_char_at(text, _i) == "[" {
            var _tag_end = string_pos_ext("]", text, _i);
            if _tag_end > 0 {
                var _tag = string_copy(text, _i + 1, _tag_end - _i - 1);
                
                // Parse tag
                switch (_tag) {
                    case "i":       _italic = true;          break;
                    case "/i":      _italic = false;         break;
                    case "wave":    _effect = "wave";        break;
                    case "/wave":   _effect = "none";        break;
                    case "shake":   _effect = "shake";       break;
                    case "/shake":  _effect = "none";        break;
					case "br":
					    // Force line break — insert a newline character struct
					    var _break_struct = {
					        char:    "\n",
					        italic:  false,
					        effect:  "none",
					        x_off:   0,
					        y_off:   0,
					        alpha:   0,
					        revealed: false
					    };
					    array_push(_chars, _break_struct);
					break;
                }
                
                _i = _tag_end + 1;
                continue;
            }
        }
        
        // Regular character — build struct
        var _char_struct = {
            char:    string_char_at(text, _i),
            italic:  _italic,
            effect:  _effect,
            x_off:   0,
            y_off:   0,
            alpha:   0,        // starts invisible, typewriter reveals it
            revealed: false
        };
        
        array_push(_chars, _char_struct);
        _i++;
    }
    
    return _chars;
}