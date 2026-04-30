function dialogue_parse_text(text) {
    var _chars = [];
    var _len = string_length(text);
    var _i = 1;
    
    // Active style flags
    var _italic = false;
    var _effect = "none";
    var _color  = c_black; // default — swap to c_white for box renderer
    
    while _i <= _len {
        // Check for opening tag
        if string_char_at(text, _i) == "[" {
            var _tag_end = string_pos_ext("]", text, _i);
            if _tag_end > 0 {
                var _tag = string_copy(text, _i + 1, _tag_end - _i - 1);
                
                switch (_tag) {
                    case "i":      _italic = true;    break;
                    case "/i":     _italic = false;   break;
                    case "wave":   _effect = "wave";  break;
                    case "/wave":  _effect = "none";  break;
                    case "shake":  _effect = "shake"; break;
                    case "/shake": _effect = "none";  break;

                    case "br":
                        // Force line break
                        array_push(_chars, {
                            char:     "\n",
                            italic:   false,
                            effect:   "none",
                            color:    _color,
                            x_off:    0,
                            y_off:    0,
                            alpha:    0,
                            revealed: false
                        });
                    break;

                    case "/color":
                        // Reset color to default
                        _color = c_black;
                    break;

                    default:
					    if string_starts_with(_tag, "color=") {
					        var _color_val = string_delete(_tag, 1, 6); // strip "color="
        
					        if string_starts_with(_color_val, "#") {
					            // Hex code — strip # and parse RGB
					            var _hex = string_delete(_color_val, 1, 1);
					            var _r   = real("0x" + string_copy(_hex, 1, 2));
					            var _g   = real("0x" + string_copy(_hex, 3, 2));
					            var _b   = real("0x" + string_copy(_hex, 5, 2));
					            _color   = make_color_rgb(_r, _g, _b);
					        } else {
					            // Named color — map to GM constants
					            switch (_color_val) {
					                case "red":     _color = c_red;     break;
					                case "green":   _color = c_green;   break;
					                case "blue":    _color = c_blue;    break;
					                case "yellow":  _color = c_yellow;  break;
					                case "white":   _color = c_white;   break;
					                case "black":   _color = c_black;   break;
					                case "orange":  _color = c_orange;  break;
					                case "purple":  _color = make_color_rgb(128, 0, 128); break;
					                case "gray":
					                case "grey":    _color = c_gray;    break;
					                case "lime":    _color = c_lime;    break;
					                case "aqua":    _color = c_aqua;    break;
					                case "pink":    _color = make_color_rgb(255, 105, 180); break;
					                default:        _color = c_white;   break;
					            }
					        }
					    }
					    if _tag == "/color" {
					        _color = c_black; // reset to default
					    }
					break;
                }
                
                _i = _tag_end + 1;
                continue;
            }
        }
        
        // Regular character — build struct
        array_push(_chars, {
            char:     string_char_at(text, _i),
            italic:   _italic,
            effect:   _effect,
            color:    _color,
            x_off:    0,
            y_off:    0,
            alpha:    0,
            revealed: false
        });
        
        _i++;
    }
    
    return _chars;
}