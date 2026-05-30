/// @description Dialogue Box — Draw GUI

#region Settings
var _font_w  = 22;
var _font_h  = 38;
var _padding = box_padding;
var _gui_w   = display_get_gui_width();
var _gui_h   = display_get_gui_height();
#endregion

#region Box Position — bottom of screen
var _box_margin = box_margin;
var _bx = _box_margin;
var _bw = _gui_w - (_box_margin * 2);
var _bh = box_h;

if box_position == "top" {
    var _by = _box_margin;
} else {
    var _by = _gui_h - box_h - _box_margin;
}
#endregion

#region Draw Box Background
if box_style == "undertale" {
    // Draw white border rectangle first
    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);
    
    // Draw black fill on top, inset by border thickness
    var _border = 12; // border thickness in pixels — tune this
    draw_set_color(c_black);
    draw_set_alpha(1);
    draw_rectangle(
        _bx + _border, _by + _border,
        _bx + _bw - _border, _by + _bh - _border,
        false
    );
} else {
    // Normal 9-slice sprite for other styles
    draw_set_alpha(box_alpha);
    draw_sprite_stretched(box_sprite, 0, _bx, _by, _bw, _bh);
    draw_set_alpha(1);
}
#endregion

#region Layout — Portrait
var _text_x = _bx + _padding + text_padding_horizontal;     // where text starts horizontally
var _text_y = _by + _padding + text_padding_vertical;     // where text starts vertically
var _text_w = _bw - _padding * 2; // available text width

if box_layout == "portrait" && portrait_spr != -1 {
    // Draw portrait on left side
    var _port_x = _bx + _padding;
    var _port_y = _by + (_bh - portrait_w) / 2;
    draw_sprite_stretched(portrait_spr, 0, _port_x, _port_y, portrait_w, portrait_w);

    // Shift text area to the right of portrait
    _text_x = _bx + portrait_w + _padding * 2;
    _text_w = _bw - portrait_w - _padding * 3;
}
#endregion

#region Layout — Name Tag
if box_layout == "portrait" || box_layout == "name_only" {
    if speaker_name != "" {
        // Name tag background
        var _name_w = string_length(speaker_name) * _font_w + _padding * 2;
        draw_set_color(name_bg_color);
        draw_set_alpha(1);
        draw_roundrect_ext(
            _text_x - 4, _text_y - 4,
            _text_x + _name_w, _text_y + name_tag_h,
            4, 4, false
        );

        // Name text
        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(name_text_color);
        draw_set_alpha(1);
        draw_text(_text_x + 4, _text_y + - 2, speaker_name);

        // Push text down below name tag
        _text_y += name_tag_h + 8;
    }
}
#endregion

#region Draw Text
var _chars_per_line = floor(_text_w / _font_w);
var _draw_x = _text_x;
var _draw_y = _text_y;
var _col    = 0;

draw_set_font(fnt_dialogue);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;

    if _col >= _chars_per_line || _c.char == "\n" {
        _col    = 0;
        _draw_x = _text_x;
        _draw_y += _font_h;
    }

    // Swap black to white for dark box background — preserve explicit color tags
	draw_set_color(_c.color == c_black ? c_white : _c.color);
    draw_set_alpha(_c.alpha);

    var _ix = _c.italic ? 2 : 0;

    draw_text(
        _draw_x + _c.x_off + _ix,
        _draw_y + _c.y_off,
        _c.char
    );

    _draw_x += _font_w;
    _col++;
}
#endregion

#region Draw Choices
if is_choice {
    var _title_lines    = dialogue_count_lines(choice_title_text, _chars_per_line);
    var _choice_start_y = _text_y + (_title_lines * _font_h) + 8;

    if choice_style == "vertical" {
        var _cy = _choice_start_y;
        for (var _i = 0; _i < array_length(choice_options); _i++) {
            var _opt = choice_options[_i];
            draw_set_font(fnt_dialogue);

            if _i == choice_index {
                draw_set_color(make_color_rgb(200, 230, 255));
                draw_set_alpha(1);
                draw_roundrect_ext(
                    _text_x - 4, _cy - 2,
                    _text_x + _text_w + 4, _cy + _font_h,
                    4, 4, false
                );
                draw_set_color(c_black);
                draw_set_alpha(1);
                draw_text(_text_x + 12, _cy, "> " + _opt.text);
            } else {
                draw_set_color(make_color_rgb(180, 180, 180));
                draw_set_alpha(1);
                draw_text(_text_x + 12, _cy, "  " + _opt.text);
            }
            _cy += _font_h + 8;
        }

    } else if choice_style == "horizontal" {
        var _total_opts = array_length(choice_options);
        var _opt_widths = array_create(_total_opts, 0);
        var _total_w    = 0;

        for (var _i = 0; _i < _total_opts; _i++) {
            _opt_widths[_i] = string_length("> " + choice_options[_i].text) * _font_w + _padding;
            _total_w += _opt_widths[_i];
        }

        var _cx = _text_x + (_text_w - _total_w) / 2;
        var _cy = _choice_start_y;

        for (var _i = 0; _i < _total_opts; _i++) {
            var _opt = choice_options[_i];
            draw_set_font(fnt_dialogue);

            if _i == choice_index {
                draw_set_color(make_color_rgb(200, 230, 255));
                draw_set_alpha(1);
                draw_roundrect_ext(
                    _cx - 4, _cy - 2,
                    _cx + _opt_widths[_i], _cy + _font_h,
                    4, 4, false
                );
                draw_set_color(c_black);
                draw_set_alpha(1);
                draw_text(_cx, _cy, "> " + _opt.text);
            } else {
                draw_set_color(make_color_rgb(180, 180, 180));
                draw_set_alpha(1);
                draw_text(_cx, _cy, "  " + _opt.text);
            }
            _cx += _opt_widths[_i];
        }

    } else if choice_style == "horizontal_extended" {
        var _total_opts  = array_length(choice_options);
        var _total_disp  = array_length(choice_display_chars);
        var _text_draw_y = _choice_start_y;
        var _text_draw_x = _text_x;
        var _wcol        = 0;

        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        for (var _i = 0; _i < _total_disp; _i++) {
            var _c = choice_display_chars[_i];
            if !_c.revealed continue;

            if _c.char == " " {
                _text_draw_x += _font_w;
                _wcol++;
            } else {
                var _word_len = 0;
                var _j = _i;
                while _j < _total_disp && choice_display_chars[_j].char != " " {
                    _word_len++;
                    _j++;
                }
                if _wcol + _word_len > _chars_per_line && _wcol > 0 {
                    _text_draw_y += _font_h;
                    _text_draw_x = _text_x;
                    _wcol        = 0;
                }
                draw_set_color(c_white);
                draw_set_alpha(_c.alpha);
                draw_text(_text_draw_x + _c.x_off, _text_draw_y + _c.y_off, _c.char);
                _text_draw_x += _font_w;
                _wcol++;
            }
        }

        // Dot row
        var _dot_radius  = 7;
        var _dot_gap     = 22;
        var _dot_total_w = _total_opts * _dot_gap;
        var _dot_start_x = _text_x + (_text_w - _dot_total_w) / 2 + _dot_gap / 2;
        var _dot_y       = _by + _bh - _padding - _dot_radius;

        for (var _i = 0; _i < _total_opts; _i++) {
            var _dot_x = _dot_start_x + (_i * _dot_gap);
            if _i == choice_index {
                draw_set_color(c_white);
                draw_set_alpha(1);
                draw_circle(_dot_x, _dot_y, _dot_radius, false);
            } else {
                draw_set_color(c_white);
                draw_set_alpha(0.3);
                draw_circle(_dot_x, _dot_y, _dot_radius, false);
                draw_set_color(make_color_rgb(30, 30, 80));
                draw_set_alpha(1);
                draw_circle(_dot_x, _dot_y, _dot_radius - 2, false);
            }
        }
    } // closes horizontal_extended
} // closes if is_choice
#endregion

#region Advance Indicator
// Blinking arrow at bottom right when text is fully revealed
if !is_choice && fully_revealed {
	var _blink = (current_time mod 800) < 400;
	if _blink {
	    draw_set_color(c_white);
	    draw_set_alpha(1);
	    var _ax = _bx + _bw - _padding - 80;
	    var _ay = _by + _bh - _padding - 16;
	    draw_triangle(
	        _ax,      _ay,
	        _ax + 14, _ay,
	        _ax + 7,  _ay + 10,
	        false
	    );
	}
}
#endregion

#region Reset Draw State
draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);
#endregion