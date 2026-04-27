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
    
    dialogue_show_line();
}

function dialogue_show_line() {
    var _mgr = obj_dialogue_manager;
    var _lines = _mgr.current_node.lines;
    
    if _mgr.line_index >= array_length(_lines) {
        dialogue_end();
        exit;
    }
    
    var _line = _lines[_mgr.line_index];
    
    // Destroy old bubble
    if instance_exists(_mgr.bubble_inst) {
        instance_destroy(_mgr.bubble_inst);
    }
    
   // ---- CHOICE LINE ----
	if variable_struct_exists(_line, "type") && _line.type == "choice" {
	    var _bubble = instance_create_layer(
	        oMae.x, oMae.y - 550,
	        "Instances",
	        obj_dialogue_bubble
	    );
	    _bubble.speaker_inst = oMae;
	    _bubble.is_choice = true;
	    _bubble.choice_options = _line.options;
	    _bubble.choice_index = 0;
	    _bubble.choice_style = variable_struct_exists(_line, "style")
	                           ? _line.style
	                           : "vertical";

	    // Title
	    var _title = variable_struct_exists(_line, "title") ? _line.title : "";
		_bubble.choice_title_text = _title;
	    var _parsed = dialogue_parse_text(_title);
	    for (var _i = 0; _i < array_length(_parsed); _i++) {
	        _parsed[_i].revealed = true;
	        _parsed[_i].alpha = 1;
	    }
	    _bubble.chars = _parsed;
	    _mgr.bubble_inst = _bubble;
	    _mgr.char_index = array_length(_parsed);

	    // Pre-load first option text for horizontal_extended
	    if _bubble.choice_style == "horizontal_extended" {
	        dialogue_bubble_set_option(_bubble, _line.options[0].text);
	    }

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
    
    var _bubble = instance_create_layer(
        _speaker_inst.x,
        _speaker_inst.y - 550,
        "Instances",
        obj_dialogue_bubble
    );
    
    _bubble.speaker_inst = _speaker_inst;
    _bubble.chars = dialogue_parse_text(_line.text);
    _bubble.is_choice = false;
    _mgr.bubble_inst = _bubble;
    _mgr.char_index = 0;
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