# NITW Dialogue System

### A Night in the Woods-Inspired Dialogue Engine for GameMaker Studio 2

**Author:** Myles Moore / LoafCentral  
**Version:** 1.2  
**Engine:** GameMaker Studio 2 (GML)

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Object Reference](#object-reference)
   - [obj_dialogue_manager](#obj_dialogue_manager)
   - [obj_dialogue_bubble](#obj_dialogue_bubble)
   - [obj_dialogue_box](#obj_dialogue_box)
   - [obj_dialogue_prompt](#obj_dialogue_prompt)
   - [oMae (Player)](#omae-player)
   - [oNPC](#onpc)
4. [Script Reference](#script-reference)
5. [JSON Schema](#json-schema)
6. [Inline Tags](#inline-tags)
7. [Choice Styles](#choice-styles)
8. [Flag System](#flag-system)
9. [Adding a New NPC](#adding-a-new-npc)
10. [Porting to a New Game](#porting-to-a-new-game)
11. [Tuning Reference](#tuning-reference)

---

## System Overview

This is a fully data-driven dialogue system inspired by Night in the Woods and Undertale. Dialogue lives in external JSON files — no hardcoded strings in objects. The engine supports:

- Speech bubbles that dynamically follow speakers
- Bottom-screen fixed textbox renderer (Undertale / Mother 3 / Lisa style)
- Swappable 9-slice box sprites — drop in any textbox art
- Portrait support with name tag (Mother 3 layout)
- Typewriter text reveal with snap-to-full on input
- Inline text effects (`[wave]`, `[shake]`, `[i]`, `[color]`, `[br]`)
- Three choice styles: vertical list, horizontal side-by-side, NITW-style dot navigation
- Per-node renderer selection — bubble or box, per node or per NPC default
- Per-NPC conversation memory via a flag system
- Press and auto-trigger modes
- Proximity prompt that appears when Mae is near an NPC
- Typewriter sound with pitch variation

---

## Architecture

```
obj_dialogue_manager        Singleton. Loads JSON, owns dialogue state,
                            drives typewriter and input handling.
                            Tracks current renderer (bubble or box).

obj_dialogue_bubble         Spawned per line. Renders speech bubble above
                            speaker in room space. Follows speaker position.

obj_dialogue_box            Spawned per line. Renders fixed bottom-screen
                            textbox in GUI space. Supports portrait, name tag,
                            and full layouts. Swappable 9-slice sprite background.

obj_dialogue_prompt         Spawned by each NPC on Create. Shows a small
                            floating bubble hint when Mae is nearby.

oNPC                        Any NPC in the world. Holds its own config
                            (npc_id, trigger_type, trigger_range,
                            default_renderer) and drives proximity detection.

oMae                        Player. Input is locked during active dialogue.

scr_dialogue_parser         Converts tagged text strings into character
                            struct arrays used by both renderers.

scr_dialogue_functions      All dialogue lifecycle functions:
                            start, show_line, next_line, end,
                            set_flag, get_flag, bubble_set_option,
                            count_lines, get_speaker_name.
```

### Data Flow

```
JSON File
   └─► obj_dialogue_manager (loads on Create)
            └─► dialogue_start(node_id)
                     └─► reads "renderer" field from node
                     └─► dialogue_show_line()
                              └─► scr_dialogue_parser → char structs
                              └─► obj_dialogue_bubble  (room space)
                                OR obj_dialogue_box    (GUI space)
                                       └─► Draw / Draw GUI (renders text + choices)
                                       └─► Step (text effects + extended typewriter)
                              └─► obj_dialogue_manager Step
                                       └─► typewriter + input
                                       └─► dialogue_next_line() / dialogue_end()
```

---

## Object Reference

---

### obj_dialogue_manager

**Persistent singleton.** Place one instance in your first room or init room. Handles all dialogue state.

#### Create Event

```gml
/// @description Dialogue Manager — Initialize

#region Singleton + Persistence
// Destroy any duplicate instances — only one manager allowed
if instance_number(obj_dialogue_manager) > 1 {
    instance_destroy();
    exit;
}
instance_persistent = true; // survive room transitions

// Initialize flags struct only once — persists across rooms
if !variable_struct_exists(self, "flags") {
    flags = {}; // key/value store for dialogue memory
}
#endregion

#region State
active          = false;     // true while dialogue is running
dialogue_data   = undefined; // parsed JSON data
current_node    = undefined; // active node struct
line_index      = 0;         // which line in the node we're on
char_index      = 0;         // how many chars have been typewritten
typewriter_speed = 2;        // chars revealed per game step
typewriter_timer = 0;        // accumulator for fractional speed
interact_key    = ord("E");  // key to advance dialogue / confirm choices
bubble_inst     = noone;     // reference to the active bubble instance
#endregion

#region Load Dialogue JSON
// Loads dialogue_test.json from Included Files
// Swap filename here when porting to a new game
var _buffer = buffer_load(working_directory + "dialogue_test.json");
if _buffer != -1 {
    var _json_string = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);
    dialogue_data = json_parse(_json_string);
} else {
    show_debug_message("ERROR: Could not load dialogue JSON");
}
#endregion

#region Sound
typewriter_sound      = snd_typewriter; // swap per game
typewriter_pitch_vary = true;           // randomize pitch slightly for personality
#endregion
```

#### Step Event

```gml
/// @description Dialogue Manager — Typewriter + Input

if !active exit;

var _bubble = bubble_inst;
if !instance_exists(_bubble) exit;

#region Typewriter
// Reveals characters one by one from the active bubble's char array
var _chars = _bubble.chars;
var _total  = array_length(_chars);

if char_index < _total {
    typewriter_timer += typewriter_speed;
    while typewriter_timer >= 1 && char_index < _total {
        _chars[char_index].revealed = true;
        _chars[char_index].alpha    = 1;
        char_index++;
        typewriter_timer--;

        // Play typewriter sound — skip spaces and punctuation
        var _revealed_char = _chars[char_index - 1].char;
        if _revealed_char != " "  && _revealed_char != "."
        && _revealed_char != ","  && _revealed_char != "!"
        && _revealed_char != "?" {
            var _pitch = typewriter_pitch_vary
                         ? random_range(0.9, 1.1)
                         : 1.0;
            audio_play_sound(typewriter_sound, 1, false);
            audio_sound_pitch(typewriter_sound, _pitch);
        }
    }
}
#endregion

#region Advance / Dismiss / Choices
if instance_exists(bubble_inst) {
    var _is_choice = bubble_inst.is_choice;
    var _opts       = bubble_inst.choice_options;
    var _count      = array_length(_opts);
    var _style      = bubble_inst.choice_style;

    if _is_choice {
        // Capture index before navigation to detect changes
        var _prev_index = bubble_inst.choice_index;

        // Navigation — vertical uses W/S, horizontal uses A/D
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

        // If index changed in extended mode — reload option text with fresh typewriter
        if bubble_inst.choice_index != _prev_index && _style == "horizontal_extended" {
            dialogue_bubble_set_option(bubble_inst, _opts[bubble_inst.choice_index].text);
        }

        // Confirm selection
        if keyboard_check_pressed(interact_key) {
            var _chosen = _opts[bubble_inst.choice_index];
            dialogue_start(_chosen.goto);
        }

    } else {
        // Normal line — E snaps typewriter or advances to next line
        var _line_chars = bubble_inst.chars;
        var _line_total = array_length(_line_chars);

        if keyboard_check_pressed(interact_key) {
            if char_index < _line_total {
                // Snap all chars to revealed
                for (var _i = 0; _i < _line_total; _i++) {
                    _line_chars[_i].revealed = true;
                    _line_chars[_i].alpha    = 1;
                }
                char_index = _line_total;
            } else {
                dialogue_next_line();
            }
        }
    }
}
#endregion
```

---

### obj_dialogue_bubble

**Spawned per dialogue line** by `dialogue_show_line()`. Never place manually in a room.

#### Create Event

```gml
/// @description Dialogue Bubble — Initialize

#region Core
speaker_inst = noone; // instance this bubble floats above
chars        = [];    // array of character structs from scr_dialogue_parser
bubble_offset_y = 550; // pixels above speaker origin — tune per sprite size
#endregion

#region Bubble Dimensions (recalculated each Draw)
bubble_w    = 100;  // recalculated dynamically
bubble_h    = 100;  // recalculated dynamically
max_bubble_w = 700; // maximum bubble width before text wraps — tune per game
bubble_padding = 24;
line_height    = 38; // match to font size
char_width     = 22; // approximate char width — tune to your font
#endregion

#region Choice State
is_choice        = false;     // true when this bubble shows a choice
choice_options   = [];        // array of option structs from JSON
choice_index     = 0;         // currently highlighted option
choice_style     = "vertical"; // "vertical" | "horizontal" | "horizontal_extended"
choice_title_text = "";       // raw title string — used for word-aware sizing
#endregion

#region Horizontal Extended Typewriter
// Only used for horizontal_extended choice style
choice_display_chars   = []; // char structs for currently displayed option
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;
#endregion
```

#### Step Event

```gml
/// @description Dialogue Bubble — Follow Speaker + Text Effects

#region Follow Speaker
// Bubble tracks its speaker every frame
if instance_exists(speaker_inst) {
    x = speaker_inst.x;
    y = speaker_inst.y - bubble_offset_y;
}
#endregion

#region Text Effects
// Drives per-character animation offsets based on effect tag
var _time = current_time * 0.005;
for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;

    switch (_c.effect) {
        case "wave":
            // Sine wave on Y axis — smooth ripple
            _c.y_off = sin(_time + _i * 0.4) * 3;
        break;
        case "shake":
            // Random offset on X and Y — jitter effect
            _c.x_off = random_range(-1.5, 1.5);
            _c.y_off = random_range(-1.5, 1.5);
        break;
        default:
            _c.x_off = 0;
            _c.y_off = 0;
        break;
    }
}
#endregion

#region Horizontal Extended Typewriter
// Drives the per-option typewriter for horizontal_extended choice style
if is_choice && choice_style == "horizontal_extended" {
    if choice_typewriter_index < array_length(choice_display_chars) {
        choice_typewriter_timer += choice_typewriter_speed;
        while choice_typewriter_timer >= 1
              && choice_typewriter_index < array_length(choice_display_chars) {
            choice_display_chars[choice_typewriter_index].revealed = true;
            choice_display_chars[choice_typewriter_index].alpha    = 1;
            choice_typewriter_index++;
            choice_typewriter_timer--;
        }
    }
}
#endregion
```

#### Draw Event

```gml
/// @description Dialogue Bubble — Draw

if array_length(chars) == 0 exit;

#region Colors — tweak per game
var _bubble_fill    = c_white;
var _bubble_outline = c_white;
var _tail_color     = c_white;
var _text_color     = c_black;
#endregion

#region Settings — tune to match your font
var _font_w          = 22;   // approximate character width in pixels
var _font_h          = 38;   // approximate line height in pixels
var _padding         = 24;   // inner padding on all sides
var _max_bubble_w    = max_bubble_w;
var _chars_per_line  = floor((_max_bubble_w - _padding * 2) / _font_w);
#endregion

#region Dynamic Bubble Sizing — normal lines
// Count lines needed based on revealed chars and wrapping
var _total_revealed = 0;
var _lines_needed   = 1;
var _col_count      = 0;

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
#endregion

#region Choice Sizing — overrides bubble dimensions for choice bubbles
if is_choice {
    // Word-aware title line count using dialogue_count_lines()
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
#endregion

#region Bubble Position
var _bx = x - bubble_w / 2;
var _by = y - bubble_h;
#endregion

#region Draw Tail
// Tail drawn first so bubble paints over its base — no gap
draw_set_color(_tail_color);
draw_set_alpha(1);
draw_triangle(
    x - 8, _by + bubble_h,
    x + 8, _by + bubble_h,
    x,     _by + bubble_h + 14,
    false
);
#endregion

#region Draw Bubble Fill
draw_set_color(_bubble_fill);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, false);
#endregion

#region Draw Bubble Outline
draw_set_color(_bubble_outline);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, true);
#endregion

#region Draw Text — normal lines and choice titles
var _draw_x = _bx + _padding;
var _draw_y = _by + _padding;
var _col    = 0;

draw_set_font(fnt_dialogue);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;

    // Wrap on column overflow or explicit newline
    if _col >= _chars_per_line || _c.char == "\n" {
        _col    = 0;
        _draw_x = _bx + _padding;
        _draw_y += _font_h;
    }

    draw_set_color(_c.color); // per-character color from [color] tag
    draw_set_alpha(_c.alpha);

    var _ix = _c.italic ? 2 : 0; // fake italic via x offset

    draw_text(
        _draw_x + _c.x_off + _ix,
        _draw_y + _c.y_off,
        _c.char
    );

    _draw_x += _font_w;
    _col++;
}
#endregion

#region Reset Draw State
draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);
#endregion

#region Draw Choices
if is_choice {
    var _title_lines    = dialogue_count_lines(choice_title_text, _chars_per_line);
    var _choice_start_y = _by + _padding + (_title_lines * _font_h) + 12;

    if choice_style == "vertical" {
        // Stacked list with highlight box on selected option
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
        // Side by side options centered in bubble
        var _total_opts = array_length(choice_options);
        var _opt_widths = array_create(_total_opts, 0);
        var _total_w    = 0;

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
        // NITW-style: one option displayed at a time with dot row navigation
        var _total_opts = array_length(choice_options);

        // Word-aware drawing — stays in choice_display_chars, no cursor sync issues
        var _text_y    = _choice_start_y;
        var _text_x    = _bx + _padding;
        var _wcol      = 0;
        var _total_disp = array_length(choice_display_chars);

        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        for (var _i = 0; _i < _total_disp; _i++) {
            var _c = choice_display_chars[_i];
            if !_c.revealed continue;

            if _c.char == " " {
                // Space — advance without drawing
                _text_x += _font_w;
                _wcol++;
            } else {
                // Lookahead — measure word length before deciding to wrap
                var _word_len = 0;
                var _j = _i;
                while _j < _total_disp && choice_display_chars[_j].char != " " {
                    _word_len++;
                    _j++;
                }

                // Wrap if word doesn't fit on current line
                if _wcol + _word_len > _chars_per_line && _wcol > 0 {
                    _text_y += _font_h;
                    _text_x = _bx + _padding;
                    _wcol   = 0;
                }

                draw_set_color(c_black);
                draw_set_alpha(_c.alpha);
                draw_text(_text_x + _c.x_off, _text_y + _c.y_off, _c.char);
                _text_x += _font_w;
                _wcol++;
            }
        }

        // Dot row — filled circle = selected, hollow = unselected
        var _dot_radius  = 7;
        var _dot_gap     = 22;
        var _dot_total_w = _total_opts * _dot_gap;
        var _dot_start_x = x - _dot_total_w / 2 + _dot_gap / 2;
        var _dot_y       = _by + bubble_h - _padding;

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

    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_set_font(-1);
}
#endregion
```

---

### obj_dialogue_box

**Spawned per dialogue line** by `dialogue_show_line()` when the active node uses `"renderer": "box"`. Draws in **GUI space** so it stays locked to the bottom of the screen regardless of camera position. Never place manually in a room.

#### Create Event

```gml
/// @description Dialogue Box — Initialize

#region Core
chars             = [];        // char struct array from scr_dialogue_parser
speaker_name      = "";        // display name shown in name tag
portrait_spr      = -1;        // sprite index for portrait — -1 = none
is_choice         = false;
choice_options    = [];
choice_index      = 0;
choice_style      = "vertical";
choice_title_text = "";
#endregion

#region Layout
// "full"      — text only, full width (Undertale style)
// "portrait"  — portrait left, name tag + text right (Mother 3 style)
// "name_only" — name tag above text, no portrait (EarthBound style)
box_layout = "full";
#endregion

#region Box Dimensions — in GUI/screen space
box_h      = 180;  // height of the dialogue box
box_padding = 20;  // inner padding between box edge and content
portrait_w  = 140; // width of portrait area when box_layout = "portrait"
name_tag_h  = 36;  // height of name tag when using portrait or name_only layout
box_margin  = 60;  // pixels of padding around the box on sides and bottom
#endregion

#region Text Padding Within Box
// Additional offset inside the box — use to fine-tune text position
text_padding_horizontal = 40;
text_padding_vertical   = 20;
#endregion

#region Box Style
box_sprite      = spr_box_default;          // swappable 9-slice background sprite
box_alpha       = 1;                         // box opacity
name_bg_color   = make_color_rgb(30, 30, 80); // name tag background color
name_text_color = c_white;                   // name tag text color
text_color      = c_white;                   // main text color — white for dark backgrounds
#endregion

#region Advance Key
advance_key = ord("E"); // swap to ord("Z") for Undertale style
#endregion

#region Extended Choice Typewriter
// Only used for horizontal_extended choice style
choice_display_chars    = [];
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;
#endregion
```

#### Step Event

```gml
/// @description Dialogue Box — Text Effects + Extended Typewriter

#region Text Effects
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
#endregion

#region Extended Choice Typewriter
if is_choice && choice_style == "horizontal_extended" {
    if choice_typewriter_index < array_length(choice_display_chars) {
        choice_typewriter_timer += choice_typewriter_speed;
        while choice_typewriter_timer >= 1
              && choice_typewriter_index < array_length(choice_display_chars) {
            choice_display_chars[choice_typewriter_index].revealed = true;
            choice_display_chars[choice_typewriter_index].alpha    = 1;
            choice_typewriter_index++;
            choice_typewriter_timer--;
        }
    }
}
#endregion
```

#### Draw GUI Event

```gml
/// @description Dialogue Box — Draw GUI
// Draws in GUI/screen space — stays fixed to bottom regardless of camera

#region Settings
var _font_w  = 22;        // tune to match your font
var _font_h  = 38;        // tune to match your font
var _padding = box_padding;
var _gui_w   = display_get_gui_width();
var _gui_h   = display_get_gui_height();
#endregion

#region Box Position
// box_margin adds padding around all sides so the box doesn't touch screen edges
var _box_margin = box_margin;
var _bx = _box_margin;
var _by = _gui_h - box_h - _box_margin;
var _bw = _gui_w - (_box_margin * 2);
var _bh = box_h;
#endregion

#region Draw Box Background
// 9-slice sprite stretches cleanly — swap spr_box_default for any styled sprite
draw_set_alpha(box_alpha);
draw_sprite_stretched(box_sprite, 0, _bx, _by, _bw, _bh);
draw_set_alpha(1);
#endregion

#region Layout — Portrait
var _text_x = _bx + _padding + text_padding_horizontal;
var _text_y = _by + _padding + text_padding_vertical;
var _text_w = _bw - _padding * 2;

if box_layout == "portrait" && portrait_spr != -1 {
    var _port_x = _bx + _padding;
    var _port_y = _by + (_bh - portrait_w) / 2;
    draw_sprite_stretched(portrait_spr, 0, _port_x, _port_y, portrait_w, portrait_w);
    _text_x = _bx + portrait_w + _padding * 2;
    _text_w = _bw - portrait_w - _padding * 3;
}
#endregion

#region Layout — Name Tag
if box_layout == "portrait" || box_layout == "name_only" {
    if speaker_name != "" {
        var _name_w = string_length(speaker_name) * _font_w + _padding * 2;
        draw_set_color(name_bg_color);
        draw_set_alpha(1);
        draw_roundrect_ext(_text_x - 4, _text_y - 4, _text_x + _name_w, _text_y + name_tag_h, 4, 4, false);
        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_color(name_text_color);
        draw_set_alpha(1);
        draw_text(_text_x + 4, _text_y + 4, speaker_name);
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

    // Swap default black to white for dark backgrounds — preserve explicit [color] tags
    draw_set_color(_c.color == c_black ? c_white : _c.color);
    draw_set_alpha(_c.alpha);

    var _ix = _c.italic ? 2 : 0;
    draw_text(_draw_x + _c.x_off + _ix, _draw_y + _c.y_off, _c.char);

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
                draw_roundrect_ext(_text_x - 4, _cy - 2, _text_x + _text_w + 4, _cy + _font_h, 4, 4, false);
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
                draw_roundrect_ext(_cx - 4, _cy - 2, _cx + _opt_widths[_i], _cy + _font_h, 4, 4, false);
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
    }
}
#endregion

#region Advance Indicator
// Blinking triangle at bottom right — signals line is fully revealed, press E to advance
if !is_choice {
    var _blink = (current_time mod 800) < 400;
    if _blink {
        draw_set_color(c_white);
        draw_set_alpha(1);
        var _ax = _bx + _bw - _padding - 80; // shift left by increasing last value
        var _ay = _by + _bh - _padding - 16;
        draw_triangle(_ax, _ay, _ax + 14, _ay, _ax + 7, _ay + 10, false);
    }
}
#endregion

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);
```

**Notes:**

- Uses `Draw GUI` event not `Draw` — this is what keeps it fixed to screen regardless of camera
- `display_set_gui_size(1920, 1080)` must be called in `obj_dialogue_manager` Create to match your viewport
- Swap `box_sprite` to any 9-slice sprite to completely change the visual style — no code changes needed
- `box_layout = "full"` for Undertale style, `"portrait"` for Mother 3 style, `"name_only"` for EarthBound style
- The advance triangle is drawn with code — no font glyph dependency

**Spawned by each NPC on Create.** Shows a small floating bubble hint when Mae is in range.

#### Create Event

```gml
/// @description Dialogue Prompt — Initialize

follow_inst    = noone; // NPC instance this prompt belongs to — set by oNPC Create
bob_timer      = 0;     // drives sine wave bobbing animation
bob_speed      = 0.05;  // speed of bob cycle
bob_amount     = 6;     // pixels of vertical bob travel
alpha          = 0;     // current opacity — 0 = invisible, 1 = fully visible
fade_speed     = 0.08;  // how fast it fades in
visible_target = false; // set by oNPC Step — true when Mae is in range
instant_hide   = true;  // true = disappear instantly, false = fade out
```

#### Step Event

```gml
/// @description Dialogue Prompt — Follow NPC + Fade

#region Follow NPC
if instance_exists(follow_inst) {
    x = follow_inst.x;
    y = follow_inst.y - 620; // sits above where the full bubble appears
}
#endregion

#region Bob Animation
bob_timer += bob_speed;
var _bob_offset = sin(bob_timer) * bob_amount;
y += _bob_offset;
#endregion

#region Fade In / Out
if visible_target {
    alpha = min(alpha + fade_speed, 1);
} else {
    if instant_hide {
        alpha = 0; // instant disappear
    } else {
        alpha = max(alpha - fade_speed, 0); // soft fade out
    }
}
#endregion

#region Cleanup
if !instance_exists(follow_inst) {
    instance_destroy();
}
#endregion
```

#### Draw Event

```gml
/// @description Dialogue Prompt — Draw small hint bubble

if alpha <= 0 exit;

#region Bubble Shape
var _bw = 60;
var _bh = 36;
var _bx = x - _bw / 2;
var _by = y - _bh;

// Dark fill
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);

// White fill over dark — creates translucent look
draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);
#endregion

#region Tail
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_triangle(x - 5, _by + _bh, x + 5, _by + _bh, x, _by + _bh + 10, false);

draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_triangle(x - 5, _by + _bh, x + 5, _by + _bh, x, _by + _bh + 10, false);
#endregion

#region Three Dots
var _dot_r     = 3;
var _dot_gap   = 14;
var _dot_start = x - _dot_gap;
var _dot_y     = _by + _bh / 2;

for (var _i = 0; _i < 3; _i++) {
    draw_set_color(c_black);
    draw_set_alpha(alpha);
    draw_circle(_dot_start + (_i * _dot_gap), _dot_y, _dot_r, false);
}
#endregion

draw_set_alpha(1);
draw_set_color(c_white);
```

---

### oNPC

#### Create Event

```gml
/// @description NPC — Initialize
// Override npc_id and dialogue_node in Room Creation Code per instance

sprite_index = spr_npc_idle;
facing       = -1;           // -1 = faces left toward Mae by default
image_xscale = facing;

#region Dialogue Config
// These are defaults — override in Room Creation Code per NPC instance
npc_id         = "npc_01";       // unique ID — must match speaker in JSON
dialogue_node  = "npc_01_greet"; // starting node — auto-updated by flag check
trigger_type   = "press";        // "press" = needs E input | "auto" = fires on proximity
trigger_range  = 300;            // pixel distance that activates trigger
triggered_auto = false;          // prevents auto trigger from firing more than once
dialogue_was_active = false;     // tracks dialogue state to detect end-of-conversation
#endregion

#region Prompt
// Spawn the floating hint bubble — follows this NPC automatically
prompt_inst = instance_create_layer(x, y, "Instances", obj_dialogue_prompt);
prompt_inst.follow_inst = id;
#endregion
```

#### Step Event

```gml
/// @description NPC — Proximity Detection + Dialogue Trigger

if !instance_exists(obj_dialogue_manager) exit;
var _mgr = obj_dialogue_manager;

#region Dynamic Flag Check
// Automatically switches between greet and return node based on met flag
// Convention: npc_01 -> flag "met_npc_01" -> nodes "npc_01_greet" / "npc_01_greet_return"
var _met_flag    = "met_" + npc_id;
var _first_node  = npc_id + "_greet";
var _return_node = npc_id + "_greet_return";
dialogue_node = dialogue_get_flag(_met_flag, false) ? _return_node : _first_node;
#endregion

#region Prompt Visibility
// Must run before exits so prompt always updates regardless of trigger state
var _dist = point_distance(x, y, oMae.x, oMae.y);
if instance_exists(prompt_inst) {
    prompt_inst.visible_target = (_dist < trigger_range) && !_mgr.active;
}
#endregion

if _mgr.active exit;
if _dist > trigger_range exit;

#region Closest NPC Check
// Only the NPC closest to Mae can trigger — prevents double-firing
var _closest      = noone;
var _closest_dist = 999999;
with (oNPC) {
    var _d = point_distance(x, y, oMae.x, oMae.y);
    if _d < _closest_dist {
        _closest_dist = _d;
        _closest = id;
    }
}
if _closest != id exit;
#endregion

#region Trigger
if trigger_type == "auto" && !triggered_auto {
    triggered_auto = true;
    dialogue_start(dialogue_node);
}

if trigger_type == "press" {
    if keyboard_check_pressed(ord("E")) {
        dialogue_start(dialogue_node);
    }
}
#endregion

#region Flag Setting
// Detects when dialogue ends and sets the met flag for this NPC
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
}
dialogue_was_active = _mgr.active;
#endregion
```

---

### oMae (Player)

**The player character.** Controls movement, jumping, collision, animation, and camera. Input is locked when `obj_dialogue_manager.active` is true.

#### Create Event

```gml
/// @description Mae — Initialize

#region Movement
hsp = 0;              // current horizontal speed (pixels per frame, calculated each step)
vsp = 0;              // current vertical speed (pixels per frame, positive = falling)
move_speed = 12.0;    // top walking speed — raise for faster movement
accel = 1.4;          // how quickly you reach move_speed — higher = snappier startup
friction_ground = 0.6; // how quickly you stop on the ground — LOWER = stops faster
friction_air = 0.58;  // how quickly horizontal speed bleeds in the air — lower = less air control
#endregion

#region Jump
jump_force = -13;     // initial upward velocity on jump — more negative = higher jump
gravity_val = 0.43;   // gravity added to vsp each frame — LOWER = floatier, higher = snappier fall
max_fall_speed = 12;  // terminal velocity — caps how fast you fall
#endregion

#region Coyote Time + Jump Buffer
coyote_time = 0;      // internal counter, do not set manually
coyote_max = 6;       // frames after walking off a ledge you can still jump — feels forgiving
jump_buffer = 0;      // internal counter, do not set manually
jump_buffer_max = 8;  // frames before landing that a jump input is remembered and fires on touch
#endregion

#region State
on_ground = false;    // true when standing on oPhysicalObject — drives jump logic and animation
facing = 1;           // 1 = right, -1 = left — controls sprite flip via image_xscale
sprite_scale = 1;     // uniform scale applied to image_xscale and image_yscale — 1 = native size
mask_index = spr_mae_idle; // lock collision mask permanently so sprite swaps don't change hitbox
#endregion

#region Camera Zoom Presets
// Switch CAMERA_ZOOM to change zoom level — useful per room type
#macro ZOOM_CLOSE   0
#macro ZOOM_NORMAL  1
#macro ZOOM_FAR     2

var CAMERA_ZOOM = ZOOM_NORMAL; // change this to switch presets

var _zoom_w, _zoom_h;
switch (CAMERA_ZOOM) {
    case ZOOM_CLOSE:
        _zoom_w = 1280; _zoom_h = 720;   // close up, good for indoors
    break;
    case ZOOM_NORMAL:
        _zoom_w = 1920; _zoom_h = 1080;  // default outdoor feel
    break;
    case ZOOM_FAR:
        _zoom_w = 2560; _zoom_h = 1440;  // very zoomed out
    break;
}
#endregion

#region Camera — Snap to Mae on Spawn
// Set camera size from zoom preset, then snap position immediately
// so the lerp in Step doesn't slide in from 0,0
var _cam = view_camera[0];
camera_set_view_size(_cam, _zoom_w, _zoom_h);
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);
var _start_x = clamp(x - _cam_w / 2, 0, room_width - _cam_w);
var _start_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);
camera_set_view_pos(_cam, _start_x, _start_y);
#endregion
```

#### Step Event

```gml
/// @description Mae Movement

#region Input
// All input locked to false during active dialogue — Mae can't move while talking
var _dialogue_active = instance_exists(obj_dialogue_manager)
                       && obj_dialogue_manager.active;
if !_dialogue_active {
    key_left         = keyboard_check(vk_left)          || keyboard_check(ord("A"));
    key_right        = keyboard_check(vk_right)         || keyboard_check(ord("D"));
    key_jump_pressed = keyboard_check_pressed(vk_space);
    key_jump_held    = keyboard_check(vk_space);
} else {
    key_left         = false;
    key_right        = false;
    key_jump_pressed = false;
    key_jump_held    = false;
}
#endregion

#region Movement Calculations
var _move = key_right - key_left;

// Horizontal speed — accelerate toward move_speed or apply friction when no input
if _move != 0 {
    hsp = approach(hsp, move_speed * _move, accel);
    facing = sign(_move); // update facing only when moving
} else {
    var _fric = on_ground ? friction_ground : friction_air;
    hsp = lerp(hsp, 0, _fric);
    if abs(hsp) < 0.05 hsp = 0; // snap to zero to prevent micro-drift
}

// Gravity — applied every frame, capped at max_fall_speed
vsp = min(vsp + gravity_val, max_fall_speed);

// Variable jump height — releasing jump early bleeds upward momentum
if !key_jump_held && vsp < -2 {
    vsp += 0.4;
}

// Coyote time — counts down frames after leaving ground
// allows jumping briefly after walking off a ledge
if on_ground {
    coyote_time = coyote_max;
} else {
    coyote_time--;
}

// Jump buffer — remembers a jump press for several frames before landing
if key_jump_pressed {
    jump_buffer = jump_buffer_max;
} else {
    jump_buffer--;
}

// Jump fires if a buffered press meets the coyote window
if jump_buffer > 0 && coyote_time > 0 {
    vsp = jump_force;
    jump_buffer = 0;
    coyote_time = 0;
}
#endregion

#region Collisions
// Horizontal — resolve wall collisions before applying movement
if hsp != 0 {
    if place_meeting(x + hsp, y, oPhysicalObject) {
        while !place_meeting(x + sign(hsp), y, oPhysicalObject) {
            x += sign(hsp);
        }
        hsp = 0;
    } else {
        x += hsp;
    }
}

// Vertical — resolve floor/ceiling collisions before applying movement
if vsp != 0 {
    if place_meeting(x, y + vsp, oPhysicalObject) {
        while !place_meeting(x, y + sign(vsp), oPhysicalObject) {
            y += sign(vsp);
        }
        vsp = 0;
    } else {
        y += vsp;
    }
}

// Ground check runs after collision resolution
on_ground = place_meeting(x, y + 1, oPhysicalObject);
#endregion

#region Animation
// Drive sprite from input state, not hsp — prevents idle flicker when against a wall
var _moving  = (key_right || key_left);
var _rising  = vsp < -1;  // clearly going up
var _falling = vsp > 1;   // clearly going down

if !on_ground {
    sprite_index = spr_mae_jump; // single air sprite — swap for separate rise/fall if available
} else {
    if _moving {
        sprite_index = spr_mae_walk;
    } else {
        sprite_index = spr_mae_idle;
    }
}

// Apply facing — sprite_scale preserves size while sign controls flip direction
image_xscale = facing * sprite_scale;
image_yscale = sprite_scale;
#endregion

#region Camera
// Smooth lerp follow — camera tracks Mae every frame
var _cam   = view_camera[0];
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);

var _target_x = clamp(x - _cam_w / 2, 0, room_width  - _cam_w);
var _target_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);

var _curr_x = camera_get_view_x(_cam);
var _curr_y = camera_get_view_y(_cam);

// 0.12 = smooth follow with slight lag — raise toward 1.0 for snappier tracking
camera_set_view_pos(_cam,
    lerp(_curr_x, _target_x, 0.12),
    lerp(_curr_y, _target_y, 0.12)
);
#endregion
```

**Notes:**

- `mask_index = spr_mae_idle` in Create is critical — without it, swapping between sprites with different bounding boxes causes collision stutter against walls
- The `approach()` function must exist as a script asset — see Script Reference
- `ZOOM_CLOSE` / `ZOOM_NORMAL` / `ZOOM_FAR` can be set per-room by changing `CAMERA_ZOOM` in Create

---

### oNPC

**Any NPC in the world.** Configure per instance via Room Creation Code. The Step event handles proximity, prompt visibility, trigger logic, and flag tracking automatically for any `npc_id`.

#### Create Event

```gml
/// @description NPC — Initialize
// All values below can be overridden in Room Creation Code per instance

sprite_index = spr_npc_idle;
facing       = -1;           // faces left toward Mae by default
image_xscale = facing;

#region Dialogue Config
npc_id              = "npc_01";       // unique ID — must match speaker in JSON and follow naming convention
dialogue_node       = "npc_01_greet"; // current node — auto-updated each Step by flag check
trigger_type        = "press";        // "press" = requires E input | "auto" = fires on proximity
trigger_range       = 300;            // pixel distance that activates trigger and shows prompt
triggered_auto      = false;          // prevents auto trigger from repeating
dialogue_was_active = false;          // tracks manager state to detect end-of-conversation
#endregion

#region Prompt
// Spawn the floating hint bubble — it follows this NPC and manages its own visibility
prompt_inst = instance_create_layer(x, y, "Instances", obj_dialogue_prompt);
prompt_inst.follow_inst = id;
#endregion
```

**Room Creation Code per NPC instance:**

```gml
// Override these values for each NPC placed in the room
npc_id              = "npc_02";       // must be unique per NPC
trigger_type        = "press";
trigger_range       = 300;
triggered_auto      = false;
dialogue_was_active = false;
dialogue_node       = "npc_02_greet"; // starting node
```

#### Step Event

```gml
/// @description NPC — Proximity Detection + Dialogue Trigger

if !instance_exists(obj_dialogue_manager) exit;
var _mgr = obj_dialogue_manager;

#region Dynamic Flag Check
// Automatically switches between first-visit and return node based on met flag
// Convention: npc_id "npc_02" → flag "met_npc_02" → nodes "npc_02_greet" / "npc_02_greet_return"
// No hardcoding needed — adding a new NPC requires zero changes here
var _met_flag    = "met_" + npc_id;
var _first_node  = npc_id + "_greet";
var _return_node = npc_id + "_greet_return";
dialogue_node = dialogue_get_flag(_met_flag, false) ? _return_node : _first_node;
#endregion

#region Prompt Visibility
// Runs before any exits — prompt always updates regardless of trigger eligibility
var _dist = point_distance(x, y, oMae.x, oMae.y);
if instance_exists(prompt_inst) {
    prompt_inst.visible_target = (_dist < trigger_range) && !_mgr.active;
}
#endregion

if _mgr.active exit;        // don't trigger if dialogue already running
if _dist > trigger_range exit; // don't trigger if Mae is out of range

#region Closest NPC Check
// Only the NPC physically closest to Mae can trigger
// Prevents two nearby NPCs from both firing simultaneously
var _closest      = noone;
var _closest_dist = 999999;
with (oNPC) {
    var _d = point_distance(x, y, oMae.x, oMae.y);
    if _d < _closest_dist {
        _closest_dist = _d;
        _closest = id;
    }
}
if _closest != id exit;
#endregion

#region Trigger
// AUTO — fires once when Mae enters range, never repeats
if trigger_type == "auto" && !triggered_auto {
    triggered_auto = true;
    dialogue_start(dialogue_node);
}

// PRESS — requires E input while in range
if trigger_type == "press" {
    if keyboard_check_pressed(ord("E")) {
        dialogue_start(dialogue_node);
    }
}
#endregion

#region Flag Setting
// Detects the moment dialogue ends and permanently records that Mae met this NPC
// On next visit, Dynamic Flag Check above will route to the _greet_return node
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
}
dialogue_was_active = _mgr.active;
#endregion
```

---

---

## Script Reference

---

### `approach(val, target, amount)` — scr_approach

Required utility used by oMae for smooth horizontal acceleration. GameMaker doesn't have this built in — create it as a Script asset.

```gml
/// @description Moves val toward target by amount without overshooting
function approach(val, target, amount) {
    if val < target {
        return min(val + amount, target);
    } else {
        return max(val - amount, target);
    }
}
```

---

### scr_dialogue_parser — `dialogue_parse_text(text)`

Converts a tagged text string into an array of character structs.

**Each struct contains:**

```
char      — single character string
italic    — bool, true if inside [i][/i]
effect    — string: "none" | "wave" | "shake"
color     — GM color value, set by [color] tag, defaults to c_black
x_off     — float, driven by effect each frame
y_off     — float, driven by effect each frame
alpha     — float 0-1, starts at 0, set to 1 when typewriter reveals it
revealed  — bool, false until typewriter fires
```

---

### scr_dialogue_functions

#### `dialogue_start(node_id)`

Finds a node by ID in the loaded JSON, sets it as current, locks Mae, and calls `dialogue_show_line()`.

#### `dialogue_show_line()`

Reads the current line from the active node. Spawns a bubble above the speaker. Handles both normal lines and choice lines. Calls `dialogue_end()` when lines are exhausted.

#### `dialogue_next_line()`

Increments `line_index` and calls `dialogue_show_line()`.

#### `dialogue_end()`

Resets manager state, destroys the active bubble, sets `active = false`.

#### `dialogue_set_flag(flag_name, value)`

Stores a value in the manager's `flags` struct.

```gml
dialogue_set_flag("met_npc_01", true);
dialogue_set_flag("player_chose_bad", true);
```

#### `dialogue_get_flag(flag_name, default_val)`

Reads a value from the manager's `flags` struct. Returns `default_val` if not set.

```gml
if dialogue_get_flag("met_npc_01", false) { ... }
```

#### `dialogue_bubble_set_option(bubble, option_text)`

Parses `option_text` and loads it into `bubble.choice_display_chars` with a fresh typewriter. Used by horizontal_extended when navigating options.

#### `dialogue_count_lines(text, chars_per_line)`

Word-aware line counter. Returns how many lines `text` needs when wrapped at `chars_per_line`. Used for dynamic bubble height calculation.

#### `dialogue_get_speaker_name(speaker_id)`

Maps a speaker ID string to a display name shown in the name tag. Add entries per character in your game:

```gml
function dialogue_get_speaker_name(speaker_id) {
    switch (speaker_id) {
        case "mae":    return "Mae";
        case "npc_01": return "Character Name";
        default:       return speaker_id; // fallback to raw id
    }
}
```

#### `dialogue_box_set_undertale_style(box_inst)`

Applies Undertale-style visual config to a box instance. Called automatically in `dialogue_show_line` when `current_box_style == "undertale"`. Draws a black rectangle with white border in code — no sprite dependency. Reads `current_box_position` from the manager so JSON position is respected.

```gml
function dialogue_box_set_undertale_style(box_inst) {
    box_inst.box_style               = "undertale";
    box_inst.box_layout              = "full";
    box_inst.box_position            = obj_dialogue_manager.current_box_position;
    box_inst.box_h                   = 200;
    box_inst.box_margin              = 100;
    box_inst.box_padding             = 24;
    box_inst.box_alpha               = 1;
    box_inst.text_padding_horizontal = 24;
    box_inst.text_padding_vertical   = 20;
    box_inst.advance_key             = ord("Z");
}
```

---

## JSON Schema

### Full Node Example

```json
{
  "nodes": [
    {
      "id": "npc_01_greet",
      "trigger": "press",
      "lines": [
        {
          "speaker": "npc_01",
          "text": "Oh hey. You're back."
        },
        {
          "speaker": "mae",
          "text": "Yeah I just... [wave]needed to walk.[/wave]"
        },
        {
          "type": "choice",
          "style": "vertical",
          "title": "What do you say?",
          "options": [
            { "text": "I'm fine.", "goto": "node_fine" },
            { "text": "Not really.", "goto": "node_bad" }
          ]
        }
      ]
    }
  ]
}
```

### Node Fields

| Field          | Type   | Required | Description                                                                |
| -------------- | ------ | -------- | -------------------------------------------------------------------------- |
| `id`           | string | yes      | Unique node identifier                                                     |
| `trigger`      | string | no       | `"press"` or `"auto"` — used by NPC                                        |
| `renderer`     | string | no       | `"bubble"` or `"box"` — overrides NPC default                              |
| `box_layout`   | string | no       | `"full"` \| `"portrait"` \| `"name_only"` — only used when renderer is box |
| `box_style`    | string | no       | `"undertale"` — applies Undertale visual preset to the box                 |
| `box_position` | string | no       | `"bottom"` (default) \| `"top"` — where the box sits on screen             |
| `lines`        | array  | yes      | Array of line objects                                                      |

### Normal Line Fields

| Field      | Type   | Required | Description                                                   |
| ---------- | ------ | -------- | ------------------------------------------------------------- |
| `speaker`  | string | yes      | Must match `npc_id` or `"mae"`                                |
| `text`     | string | yes      | Dialogue text, supports inline tags                           |
| `portrait` | string | no       | Sprite asset name for portrait — only used in portrait layout |

### Choice Line Fields

| Field     | Type   | Required | Description                                                         |
| --------- | ------ | -------- | ------------------------------------------------------------------- |
| `type`    | string | yes      | Must be `"choice"`                                                  |
| `style`   | string | no       | `"vertical"` (default) \| `"horizontal"` \| `"horizontal_extended"` |
| `title`   | string | no       | Text shown above options — blank if omitted                         |
| `options` | array  | yes      | Array of option objects                                             |

### Option Fields

| Field  | Type   | Required | Description                     |
| ------ | ------ | -------- | ------------------------------- |
| `text` | string | yes      | Option label shown to player    |
| `goto` | string | yes      | Node ID to jump to on selection |

---

## Inline Tags

All tags are parsed by `scr_dialogue_parser` at line-load time.

| Tag                           | Effect                      |
| ----------------------------- | --------------------------- |
| `[wave]text[/wave]`           | Sine wave Y oscillation     |
| `[shake]text[/shake]`         | Random X/Y jitter per frame |
| `[i]text[/i]`                 | Fake italic via X offset    |
| `[color=#rrggbb]text[/color]` | Per-character hex color     |
| `[color=name]text[/color]`    | Per-character named color   |
| `[br]`                        | Force line break            |

### Supported Named Colors

`red` `green` `blue` `yellow` `white` `black` `orange` `purple` `gray` `grey` `lime` `aqua` `pink`

### Example

```json
"text": "I'm [i]really[/i] not [wave]okay[/wave] right now."
"text": "This is [color=#ff0000]important[/color]."
"text": "Feeling [color=red]angry[/color] today."
"text": "First thought.[br]Second thought."
```

---

## Choice Styles

### `vertical`

Stacked options navigated with W/S or Up/Down. Best for 2-5 options with short-to-medium text.

```
What do you say?
> I'm fine.
  Not really.
```

### `horizontal`

Side by side options navigated with A/D or Left/Right. Best for 2 short options — binary decisions.

```
You enjoying this?   > Yep!   Nope.
```

### `horizontal_extended`

NITW-style. One option displayed at a time with dot row navigation. Best for 3+ options or long option text. Navigate with A/D or Left/Right, confirm with E.

```
What do you think?
This looks really great actually.
● ○ ○
```

---

## Flag System

Flags are key/value pairs stored on `obj_dialogue_manager`. They persist across rooms as long as the manager persists (it's marked `instance_persistent = true`).

### Setting Flags

Flags are set automatically when dialogue ends with any NPC:

```gml
// In oNPC Step — fires when dialogue ends
dialogue_set_flag("met_" + npc_id, true);
```

Set manually anywhere in your game:

```gml
dialogue_set_flag("player_chose_bad_ending", true);
dialogue_set_flag("opened_secret_door", true);
dialogue_set_flag("quest_complete", true);
```

### Reading Flags

```gml
if dialogue_get_flag("met_npc_01", false) {
    // player has spoken to NPC 01 before
}
```

### NPC Return Dialogue Convention

The system automatically builds node names from `npc_id`:

```
npc_id "npc_01"  →  first visit:  "npc_01_greet"
                 →  return visit: "npc_01_greet_return"
                 →  flag key:     "met_npc_01"
```

Add a `_greet_return` node to your JSON for any NPC you want to remember.

---

## Adding a New NPC

1. **Add nodes to JSON:**

```json
{
  "id": "npc_05_greet",
  "trigger": "press",
  "lines": [
    { "speaker": "npc_05", "text": "Hey." },
    { "speaker": "mae",    "text": "Hey." }
  ]
},
{
  "id": "npc_05_greet_return",
  "lines": [
    { "speaker": "npc_05", "text": "You again." }
  ]
}
```

2. **Place oNPC in the room**

3. **Set Room Creation Code:**

```gml
npc_id         = "npc_05";
trigger_type   = "press";
trigger_range  = 300;
triggered_auto = false;
dialogue_was_active = false;
dialogue_node  = "npc_05_greet";
```

4. **Done.** The flag system handles return visits automatically.

---

## Porting to a New Game

The minimum set of assets to copy:

```
obj_dialogue_manager
obj_dialogue_bubble
obj_dialogue_box
obj_dialogue_prompt
oMae (player — swap sprites and tune physics per game)
oNPC (as a template)
oPhysicalObject (parent for all solid collision objects)
scr_dialogue_parser
scr_dialogue_functions
scr_approach
fnt_dialogue
snd_typewriter
spr_box_default        (9-slice sprite — swap for styled art per game)
your_dialogue_file.json  (new per game)
```

### Per-game config to update

In `obj_dialogue_manager` Create:

```gml
// Change filename to match your game
var _buffer = buffer_load(working_directory + "your_game_dialogue.json");

// Swap sound asset
typewriter_sound = snd_your_typewriter;
```

In `obj_dialogue_bubble` Create:

```gml
bubble_offset_y = 550; // tune to your sprite heights
max_bubble_w    = 700; // tune to your camera/room size
```

In `obj_dialogue_bubble` Draw settings block:

```gml
var _font_w = 22; // tune to your font
var _font_h = 38; // tune to your font
```

In `obj_dialogue_prompt` Create:

```gml
instant_hide = true; // or false for soft fade
```

---

## Tuning Reference

### Mae Physics

| Variable          | Location    | Effect                                                       |
| ----------------- | ----------- | ------------------------------------------------------------ |
| `move_speed`      | oMae Create | Top walking speed in pixels per frame                        |
| `accel`           | oMae Create | How quickly Mae reaches top speed. Higher = snappier startup |
| `friction_ground` | oMae Create | How quickly Mae stops on ground. Lower = stops faster        |
| `friction_air`    | oMae Create | Horizontal bleed in air. Lower = less air control            |
| `jump_force`      | oMae Create | Initial upward velocity. More negative = higher jump         |
| `gravity_val`     | oMae Create | Gravity per frame. Lower = floatier arc                      |
| `max_fall_speed`  | oMae Create | Terminal velocity cap                                        |
| `coyote_max`      | oMae Create | Frames after leaving ledge you can still jump                |
| `jump_buffer_max` | oMae Create | Frames before landing that a jump press is remembered        |
| `CAMERA_ZOOM`     | oMae Create | `ZOOM_CLOSE` / `ZOOM_NORMAL` / `ZOOM_FAR` — set per room     |

### Dialogue Box

| Variable                  | Location   | Effect                                                                     |
| ------------------------- | ---------- | -------------------------------------------------------------------------- |
| `box_h`                   | box Create | Height of the textbox in GUI pixels                                        |
| `box_padding`             | box Create | Inner padding between box edge and content                                 |
| `box_margin`              | box Create | Outer margin — space between box and screen edges                          |
| `text_padding_horizontal` | box Create | Additional horizontal text offset inside box                               |
| `text_padding_vertical`   | box Create | Additional vertical text offset inside box                                 |
| `box_sprite`              | box Create | Swap to any 9-slice sprite to change box visual                            |
| `box_alpha`               | box Create | Box opacity — 1 = fully opaque                                             |
| `portrait_w`              | box Create | Width and height of portrait image area                                    |
| `name_tag_h`              | box Create | Height of name tag background                                              |
| `name_bg_color`           | box Create | Name tag background color                                                  |
| `advance_key`             | box Create | Key to advance lines — `ord("E")` or `ord("Z")`                            |
| `box_layout`              | box Create | `"full"` \| `"portrait"` \| `"name_only"`                                  |
| `box_style`               | box Create | `"default"` or `"undertale"` — undertale draws with code, no sprite needed |
| `box_position`            | box Create | `"bottom"` or `"top"` — which edge of screen the box sits on               |

### Dialogue + Bubble

| Variable                | Location       | Effect                                       |
| ----------------------- | -------------- | -------------------------------------------- |
| `typewriter_speed`      | manager Create | Chars revealed per frame. Higher = faster    |
| `typewriter_pitch_vary` | manager Create | Random pitch on sound. `true` = personality  |
| `bubble_offset_y`       | bubble Create  | How far above speaker origin bubble appears  |
| `max_bubble_w`          | bubble Create  | Max bubble width before text wraps           |
| `_font_w`               | bubble Draw    | Char width estimate. Must match actual font  |
| `_font_h`               | bubble Draw    | Line height estimate. Must match actual font |
| `trigger_range`         | NPC Create     | Pixel distance for proximity detection       |
| `bob_speed`             | prompt Create  | Speed of floating bob animation              |
| `bob_amount`            | prompt Create  | Pixels of vertical travel in bob             |
| `instant_hide`          | prompt Create  | `true` = prompt disappears instantly on exit |
| `dot_radius`            | bubble Draw    | Size of dots in horizontal_extended          |
| `dot_gap`               | bubble Draw    | Spacing between dots in horizontal_extended  |

---

_NITW Dialogue System — LoafCentral / Myles Moore_  
_Built as a reusable prototype foundation for GMS2 projects._
