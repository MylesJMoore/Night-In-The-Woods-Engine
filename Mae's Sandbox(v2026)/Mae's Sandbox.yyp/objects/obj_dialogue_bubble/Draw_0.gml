if array_length(chars) == 0 exit;

// -------------------------
// BUBBLE COLORS — tweak these
// -------------------------
var _bubble_fill    = c_white;
var _bubble_outline = c_white;
var _tail_color     = c_white;
var _text_color     = c_black;

// -------------------------
// SETTINGS — tune these to match your font
// -------------------------
var _font_w   = 22;
var _font_h   = 38;
var _padding  = 24;
var _max_bubble_w = max_bubble_w;
var _chars_per_line = floor((_max_bubble_w - _padding * 2) / _font_w);

// -------------------------
// DYNAMIC BUBBLE SIZING
// -------------------------
var _total_revealed = 0;
var _lines_needed = 1;
var _col_count = 0;

for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if _c.char == "\n" {
        _lines_needed++;
        _col_count = 0;
        continue;
    }
    _col_count++;
    if _col_count >= _chars_per_line {
        _lines_needed++;
        _col_count = 0;
    }
    if _c.revealed _total_revealed++;
}

var _content_w = min(_total_revealed, _chars_per_line) * _font_w;
bubble_w = max(_content_w + _padding * 2, 120);
bubble_h = (_lines_needed * _font_h) + (_padding * 2);

// ---- CHOICE SIZING ----
if is_choice {
    // Word-aware title line count
    var _title_lines = dialogue_count_lines(choice_title_text, _chars_per_line);

    if choice_style == "vertical" {
        bubble_h = (_title_lines * _font_h) + (_padding * 2)
                 + (array_length(choice_options) * (_font_h + 8)) + 12;
        for (var _oi = 0; _oi < array_length(choice_options); _oi++) {
            var _opt_w = string_length("> " + choice_options[_oi].text) * _font_w + _padding * 2;
            bubble_w = max(bubble_w, _opt_w);
        }

    } else if choice_style == "horizontal" {
        bubble_h = (_title_lines * _font_h) + (_padding * 2) + _font_h + _padding + 12;
        var _total_opt_w = _padding * 2;
        for (var _oi = 0; _oi < array_length(choice_options); _oi++) {
            _total_opt_w += string_length("> " + choice_options[_oi].text) * _font_w + _padding;
        }
        bubble_w = max(bubble_w, _total_opt_w);

    } else if choice_style == "horizontal_extended" {
        bubble_w = max_bubble_w;

        // Word-aware line count for longest option
        var _max_opt_lines = 1;
        for (var _oi = 0; _oi < array_length(choice_options); _oi++) {
            var _opt_lines = dialogue_count_lines(choice_options[_oi].text, _chars_per_line);
            _max_opt_lines = max(_max_opt_lines, _opt_lines);
        }

        bubble_h = (_title_lines * _font_h) + (_padding * 2)
                 + (_max_opt_lines * _font_h) + 8
                 + 24 + _padding;
    }
}

// -------------------------
// BUBBLE POSITION
// -------------------------
var _bx = x - bubble_w / 2;
var _by = y - bubble_h;

// -------------------------
// 1. DRAW TAIL (behind bubble)
// -------------------------
draw_set_color(_tail_color);
draw_set_alpha(1);
draw_triangle(
    x - 8, _by + bubble_h,
    x + 8, _by + bubble_h,
    x,     _by + bubble_h + 14,
    false
);

// -------------------------
// 2. DRAW FILLED BUBBLE
// -------------------------
draw_set_color(_bubble_fill);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, false);

// -------------------------
// 3. DRAW BUBBLE OUTLINE
// -------------------------
draw_set_color(_bubble_outline);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, true);

// -------------------------
// 4. DRAW TEXT (title / normal line)
// -------------------------
var _draw_x = _bx + _padding;
var _draw_y = _by + _padding;
var _col = 0;

draw_set_font(fnt_dialogue);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;

    if _col >= _chars_per_line || _c.char == "\n" {
        _col = 0;
        _draw_x = _bx + _padding;
        _draw_y += _font_h;
    }

    draw_set_color(_text_color);
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

// -------------------------
// RESET DRAW STATE
// -------------------------
draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);

// -------------------------
// 5. DRAW CHOICES
// -------------------------
if is_choice {
    // Word-aware title line count for choice positioning
    var _title_lines = dialogue_count_lines(choice_title_text, _chars_per_line);
    var _choice_start_y = _by + _padding + (_title_lines * _font_h) + 12;

    if choice_style == "vertical" {
        // ---- VERTICAL ----
        var _cy = _choice_start_y;
        for (var _i = 0; _i < array_length(choice_options); _i++) {
            var _opt = choice_options[_i];
            draw_set_font(fnt_dialogue);

            if _i == choice_index {
                draw_set_color(make_color_rgb(200, 230, 255));
                draw_set_alpha(1);
                draw_roundrect_ext(
                    _bx + _padding - 4, _cy - 2,
                    _bx + bubble_w - _padding + 4, _cy + _font_h,
                    4, 4, false
                );
                draw_set_color(c_black);
                draw_set_alpha(1);
                draw_text(_bx + _padding + 12, _cy, "> " + _opt.text);
            } else {
                draw_set_color(make_color_rgb(100, 100, 100));
                draw_set_alpha(1);
                draw_text(_bx + _padding + 12, _cy, "  " + _opt.text);
            }
            _cy += _font_h + 8;
        }

    } else if choice_style == "horizontal" {
        // ---- HORIZONTAL ----
        var _total_opts = array_length(choice_options);
        var _opt_widths = array_create(_total_opts, 0);
        var _total_w = 0;

        for (var _i = 0; _i < _total_opts; _i++) {
            _opt_widths[_i] = string_length("> " + choice_options[_i].text) * _font_w + _padding;
            _total_w += _opt_widths[_i];
        }

        var _cx = _bx + (bubble_w - _total_w) / 2;
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
                draw_set_color(make_color_rgb(100, 100, 100));
                draw_set_alpha(1);
                draw_text(_cx, _cy, "  " + _opt.text);
            }
            _cx += _opt_widths[_i];
        }

    } else if choice_style == "horizontal_extended" {
        // ---- HORIZONTAL EXTENDED ----
        var _total_opts = array_length(choice_options);

        // Word-aware option text drawing — stays in choice_display_chars array
        var _text_y = _choice_start_y;
        var _text_x = _bx + _padding;
        var _wcol = 0;
        var _total_disp = array_length(choice_display_chars);

        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        for (var _i = 0; _i < _total_disp; _i++) {
            var _c = choice_display_chars[_i];
            if !_c.revealed continue;

            if _c.char == " " {
                // Space — just advance position, no draw
                _text_x += _font_w;
                _wcol++;
            } else {
                // Measure word length from current position
                var _word_len = 0;
                var _j = _i;
                while _j < _total_disp && choice_display_chars[_j].char != " " {
                    _word_len++;
                    _j++;
                }

                // Wrap before drawing if word doesn't fit
                if _wcol + _word_len > _chars_per_line && _wcol > 0 {
                    _text_y += _font_h;
                    _text_x = _bx + _padding;
                    _wcol = 0;
                }

                // Draw the character
                draw_set_color(c_black);
                draw_set_alpha(_c.alpha);
                draw_text(_text_x + _c.x_off, _text_y + _c.y_off, _c.char);
                _text_x += _font_w;
                _wcol++;
            }
        }

        // Dot row — bottom of bubble above tail
        var _dot_radius = 7;
        var _dot_gap    = 22;
        var _dot_total_w = _total_opts * _dot_gap;
        var _dot_start_x = x - _dot_total_w / 2 + _dot_gap / 2;
        var _dot_y = _by + bubble_h - _padding;

        for (var _i = 0; _i < _total_opts; _i++) {
            var _dot_x = _dot_start_x + (_i * _dot_gap);

            if _i == choice_index {
                draw_set_color(c_black);
                draw_set_alpha(1);
                draw_circle(_dot_x, _dot_y, _dot_radius, false);
            } else {
                draw_set_color(c_black);
                draw_set_alpha(0.4);
                draw_circle(_dot_x, _dot_y, _dot_radius, false);
                draw_set_color(c_white);
                draw_set_alpha(1);
                draw_circle(_dot_x, _dot_y, _dot_radius - 2, false);
            }
        }
    }

    // Reset after all choice drawing
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_font(-1);
}