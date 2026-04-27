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
                        // Color tag — format: [color=#rrggbb]
                        if string_starts_with(_tag, "color=#") {
                            var _hex = string_delete(_tag, 1, 7); // strip "color=#"
                            var _r   = real("0x" + string_copy(_hex, 1, 2));
                            var _g   = real("0x" + string_copy(_hex, 3, 2));
                            var _b   = real("0x" + string_copy(_hex, 5, 2));
                            _color   = make_color_rgb(_r, _g, _b);
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