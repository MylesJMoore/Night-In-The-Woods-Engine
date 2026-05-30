function dialogue_start(node_id) {
    if !instance_exists(obj_dialogue_manager) exit;
    var _mgr = obj_dialogue_manager;
    
    // Find node by id
    var _nodes = _mgr.dialogue_data.nodes;
    for (var _i = 0; _i < array_length(_nodes); _i++) {
        if _nodes[_i].id == node_id {
            _mgr.current_node = _nodes[_i];
            break;
        }
    }
    
    _mgr.line_index = 0;
    _mgr.active = true;
    
    // Lock Mae
    oMae.hsp = 0;
    oMae.vsp = 0;
	
	// Read renderer from node — fallback to NPC default or "bubble"
	if variable_struct_exists(_mgr.current_node, "renderer") {
    _mgr.current_renderer = _mgr.current_node.renderer;
	} else {
	    // Find calling NPC and use its default
	    var _calling_npc = noone;
	    with (oNPC) {
	        if dialogue_node == node_id { // find who triggered this
	            _calling_npc = id;
	            break;
	        }
	    }
	    _mgr.current_renderer = instance_exists(_calling_npc)
	                            ? _calling_npc.default_renderer
	                            : "bubble";
	}
	
	// Read box layout from node — defaults to "full" if not specified
	if variable_struct_exists(_mgr.current_node, "box_layout") {
	    _mgr.current_box_layout = _mgr.current_node.box_layout;
	} else {
	    _mgr.current_box_layout = "full";
	}
	
	// Read box style from node
	if variable_struct_exists(_mgr.current_node, "box_style") {
	    _mgr.current_box_style = _mgr.current_node.box_style;
	} else {
	    _mgr.current_box_style = "default";
	}
	
	if variable_struct_exists(_mgr.current_node, "box_position") {
	    _mgr.current_box_position = _mgr.current_node.box_position;
	} else {
	    _mgr.current_box_position = "bottom";
	}
    
    dialogue_show_line();
}

function dialogue_show_line() {
    var _mgr   = obj_dialogue_manager;
    var _lines = _mgr.current_node.lines;

    if _mgr.line_index >= array_length(_lines) {
        dialogue_end();
        exit;
    }

    var _line = _lines[_mgr.line_index];

    // Destroy old bubble or box
    if instance_exists(_mgr.bubble_inst) {
        instance_destroy(_mgr.bubble_inst);
    }

    // ---- CHOICE LINE ----
    if variable_struct_exists(_line, "type") && _line.type == "choice" {
        var _title  = variable_struct_exists(_line, "title") ? _line.title : "";
        var _style  = variable_struct_exists(_line, "style") ? _line.style : "vertical";
        var _renderer = _mgr.current_renderer; // set when node starts

        var _inst = noone;

        if _renderer == "box" {
            _inst = instance_create_layer(0, 0, "Instances", obj_dialogue_box);
            _inst.box_layout = _mgr.current_box_layout;
        } else {
            _inst = instance_create_layer(oMae.x, oMae.y - 550, "Instances", obj_dialogue_bubble);
        }

        _inst.is_choice       = true;
        _inst.choice_options  = _line.options;
        _inst.choice_index    = 0;
        _inst.choice_style    = _style;
        _inst.choice_title_text = _title;

        var _parsed = dialogue_parse_text(_title);
        for (var _i = 0; _i < array_length(_parsed); _i++) {
            _parsed[_i].revealed = true;
            _parsed[_i].alpha    = 1;
        }
        _inst.chars = _parsed;

        if _style == "horizontal_extended" {
            dialogue_bubble_set_option(_inst, _line.options[0].text);
        }

        _mgr.bubble_inst  = _inst;
        _mgr.char_index   = array_length(_parsed);
        exit;
    }

    // ---- NORMAL LINE ----
    var _speaker_inst = noone;
    if _line.speaker == "mae" {
        _speaker_inst = oMae;
    } else {
        with (oNPC) {
            if npc_id == _line.speaker {
                _speaker_inst = id;
                break;
            }
        }
    }
    if _speaker_inst == noone {
        _speaker_inst = oMae;
    }

    var _renderer = _mgr.current_renderer;
    var _inst     = noone;

    if _renderer == "box" {
        // Spawn box renderer
        _inst = instance_create_layer(0, 0, "Instances", obj_dialogue_box);
        _inst.box_layout    = _mgr.current_box_layout;
        _inst.speaker_name  = dialogue_get_speaker_name(_line.speaker);
        _inst.advance_key   = _mgr.interact_key;
		
		if _mgr.current_box_style == "undertale" {
		    dialogue_box_set_undertale_style(_inst);
		}

        // Portrait — read from line if present
        if variable_struct_exists(_line, "portrait") {
		    var _spr = asset_get_index(_line.portrait);
		    _inst.portrait_spr = (_spr != -1) ? _spr : -1;
		} else {
		    _inst.portrait_spr = -1;
		}

    } else {
        // Spawn bubble renderer
        _inst = instance_create_layer(
            _speaker_inst.x,
            _speaker_inst.y - 550,
            "Instances",
            obj_dialogue_bubble
        );
        _inst.speaker_inst = _speaker_inst;
    }

    _inst.chars    = dialogue_parse_text(_line.text);
    _inst.is_choice = false;
    _mgr.bubble_inst      = _inst;
    _mgr.char_index       = 0;
    _mgr.typewriter_timer = 0;
}

function dialogue_next_line() {
    var _mgr = obj_dialogue_manager;
    _mgr.line_index++;
    dialogue_show_line();
}

function dialogue_end() {
    var _mgr = obj_dialogue_manager;
    _mgr.active = false;
    _mgr.dialogue_just_ended = true;
    _mgr.just_ended_timer = 2; // stays true for 2 frames
    _mgr.current_node = undefined;

    if instance_exists(_mgr.bubble_inst) {
        instance_destroy(_mgr.bubble_inst);
    }

    _mgr.bubble_inst = noone;
}

function dialogue_set_flag(flag_name, value) {
    variable_struct_set(obj_dialogue_manager.flags, flag_name, value);
}

function dialogue_get_flag(flag_name, default_val) {
    if variable_struct_exists(obj_dialogue_manager.flags, flag_name) {
        return variable_struct_get(obj_dialogue_manager.flags, flag_name);
    }
    return default_val;
}

function dialogue_bubble_set_option(bubble, option_text) {
    var _parsed = dialogue_parse_text(option_text);
    for (var _i = 0; _i < array_length(_parsed); _i++) {
        _parsed[_i].revealed = false;
        _parsed[_i].alpha = 0;
    }
    bubble.choice_display_chars = _parsed;
    bubble.choice_typewriter_index = 0;
    bubble.choice_typewriter_timer = 0;
}

function dialogue_count_lines(text, chars_per_line) {
    // Counts actual lines after word-aware wrapping
    var _words = string_split(text, " ");
    var _lines = 1;
    var _col = 0;
    
    for (var _i = 0; _i < array_length(_words); _i++) {
        var _word = _words[_i];
        var _word_len = string_length(_word);
        
        // If word alone is longer than line, it gets its own line
        if _word_len >= chars_per_line {
            if _col > 0 _lines++;
            _lines++;
            _col = 0;
            continue;
        }
        
        // Adding this word plus a space would overflow
        if _col + _word_len + (_col > 0 ? 1 : 0) > chars_per_line {
            _lines++;
            _col = _word_len;
        } else {
            _col += _word_len + (_col > 0 ? 1 : 0);
        }
    }
    
    return _lines;
}

function dialogue_get_speaker_name(speaker_id) {
    // Map speaker IDs to display names
    // Add entries here for each character in your game
    switch (speaker_id) {
        case "mae":    return "Mae";
        case "bruce": return "Bruce";
        case "npc_02": return "Gregg";
        case "npc_03": return "Angus";
        case "npc_04": return "Mae";
        default:       return speaker_id; // fallback to raw id
    }
}

function dialogue_box_set_undertale_style(box_inst) {
    // Configures a box instance to match Undertale's visual style
	box_inst.box_style = "undertale";
    box_inst.box_layout   = "full";
	box_inst.box_position = obj_dialogue_manager.current_box_position; // "bottom" or "top"
    box_inst.box_h        = 200;
    box_inst.box_margin   = 100;
    box_inst.box_padding  = 24;
    box_inst.box_alpha    = 1;
    box_inst.text_padding_horizontal = 24;
    box_inst.text_padding_vertical   = 20;
    box_inst.advance_key  = ord("Z");
}