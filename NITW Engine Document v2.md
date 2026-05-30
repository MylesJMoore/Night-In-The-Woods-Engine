# NITW Dialogue System — v2

### A Night in the Woods-Inspired Dialogue Engine for GameMaker Studio 2026

**Author:** Myles Moore / LoafCentral  
**Version:** 2.0  
**Engine:** GameMaker Studio 2026 (GML)

---

## Table of Contents

1. [What's New in v2](#whats-new-in-v2)
2. [Known Bugs](#known-bugs)
3. [System Overview](#system-overview)
4. [Architecture](#architecture)
5. [Object Reference](#object-reference)
   - [obj_dialogue_manager](#obj_dialogue_manager)
   - [obj_dialogue_bubble](#obj_dialogue_bubble)
   - [obj_dialogue_box](#obj_dialogue_box)
   - [obj_dialogue_prompt](#obj_dialogue_prompt)
   - [oMae (Player)](#omae-player)
   - [oNPC](#onpc)
6. [Script Reference](#script-reference)
7. [JSON Schema](#json-schema)
8. [Inline Tags](#inline-tags)
9. [Choice Styles](#choice-styles)
10. [Flag System](#flag-system)
11. [Adding a New NPC](#adding-a-new-npc)
12. [Porting to a New Game](#porting-to-a-new-game)
13. [Tuning Reference](#tuning-reference)

---

## What's New in v2

These features are present in this version that were not in or were only partially present in v1:

- **Undertale box renderer:** `box_style = "undertale"` draws the black fill + white border rectangle in code — no sprite needed. Activated via `"box_style": "undertale"` in the JSON node.
- **Top-position box:** `box_position = "top"` moves the dialogue box to the top of the screen. Works with any box style. Set per-node via `"box_position": "top"` in JSON.
- **`dialogue_box_set_undertale_style()`:** Dedicated helper that applies all Undertale dimensions, margins, and Z-key binding in one call. Reads `current_box_position` from the manager so top/bottom is respected.
- **Persistent flag init guard:** `obj_dialogue_manager` only initializes `flags = {}` if the struct doesn't already exist, preventing flag resets on room transitions.
- **`display_set_gui_size` in manager Create:** GUI dimensions are now explicitly set in Create — previously this was a manual setup step. Still defaults to 1920×1080.
- **Collision mask lock on Mae:** `mask_index = spr_mae_idle` in oMae Create locks the hitbox permanently, preventing collision stutter when sprite changes.
- **Camera zoom defaults to `ZOOM_CLOSE`:** `oMae` Create now defaults to 1280×720. Change `CAMERA_ZOOM` in oMae Create to switch.

---

## Known Bugs

### BUG 1 — Infinite Chat (the main reported bug)

**What happens:** After pressing E to close the last line of a conversation, the dialogue box immediately reopens.

**Root cause:** `keyboard_check_pressed` in GML returns `true` to *every caller* in the same frame — it is not consumed. The execution order is: `obj_dialogue_manager` Step runs first (created first, lower instance ID), processes E, and calls `dialogue_end()` which sets `active = false`. Then `oNPC` Step runs in the same frame, sees `active == false`, bypasses the `if _mgr.active exit;` guard, detects the same E press, and immediately calls `dialogue_start()` again.

**Affected file:** `oNPC/Step_0.gml`

**Fix:** Add a one-frame "just ended" buffer in the manager so the NPC knows not to retrigger on that frame. In `obj_dialogue_manager`:

```gml
// Add to Create:
dialogue_just_ended = false;
```

```gml
// In dialogue_end():
_mgr.dialogue_just_ended = true;
```

```gml
// In manager Step, at the very start, clear it each step:
dialogue_just_ended = false;
// (Set to true during the same step by dialogue_end if called — stays true for the NPC to read)
```

Then in `oNPC/Step_0.gml`, change the guard to:

```gml
if _mgr.active || _mgr.dialogue_just_ended exit;
```

This prevents the NPC from seeing the same E press that just closed dialogue.

---

### BUG 2 — Met Flag Never Set (NPCs Never Show Return Dialogue)

**What happens:** NPCs always play `npc_id_greet`, never `npc_id_greet_return`, even after talking to them once.

**Root cause:** In `oNPC/Step_0.gml`, the flag-setting code sits after the early exit:

```gml
if _mgr.active exit;   // <-- EXITS HERE while dialogue is running
...
// These lines are never reached when active == true:
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
}
dialogue_was_active = _mgr.active;
```

Because the NPC always exits before `dialogue_was_active = _mgr.active` can run, `dialogue_was_active` is permanently `false`. The flag condition `dialogue_was_active && !_mgr.active` can never be true.

**Affected file:** `oNPC/Step_0.gml`

**Fix:** Move the `dialogue_was_active` update lines to BEFORE the early exit — keep them in the section that always runs regardless of active state:

```gml
// Move this block to run before the early exits, after prompt visibility:
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
}
dialogue_was_active = _mgr.active;

if _mgr.active exit;   // early exit after tracking, not before
```

---

### BUG 3 — Advance Indicator Visible During Typewriter

**What happens:** The blinking "press to advance" arrow at the bottom right of `obj_dialogue_box` shows even while the typewriter is still typing.

**Root cause:** In `obj_dialogue_box/Draw_64.gml`, the indicator draws unconditionally any time `!is_choice`:

```gml
if !is_choice {
    var _blink = (current_time mod 800) < 400;
    if _blink { /* draw arrow */ }
}
```

There is no check against whether all characters are revealed. The manager's `char_index` lives on the manager, not the box, so the box can't read it directly.

**Affected file:** `obj_dialogue_box/Draw_64.gml`

**Fix:** Add a `fully_revealed` flag to the box that the manager sets when typewriting completes:

In `obj_dialogue_box/Create_0.gml`, add:
```gml
fully_revealed = false;
```

In `obj_dialogue_manager/Step_0.gml`, after `char_index` reaches `_total`:
```gml
if char_index >= _total {
    bubble_inst.fully_revealed = true;
}
```

In `obj_dialogue_box/Draw_64.gml`, gate the indicator:
```gml
if !is_choice && fully_revealed {
    ...draw arrow...
}
```

---

### MINOR — npc_04 Speaker Name Mapped to "Mae"

**Location:** `scr_dialogue_functions.gml`, `dialogue_get_speaker_name()`

```gml
case "npc_04": return "Mae";  // looks like the wrong name
```

`npc_04` is a separate NPC from the player. This is likely a placeholder that was never updated. Change it to the correct character name for npc_04.

---

## System Overview

A fully data-driven dialogue system inspired by Night in the Woods and Undertale. Dialogue lives in external JSON files — no hardcoded strings in objects. The engine supports:

- Speech bubbles that dynamically follow speakers in room space
- Bottom-screen (or top-screen) fixed textbox renderer
- Undertale-style box drawn in code (no sprite) with white border on black
- Swappable 9-slice box sprites — drop in any textbox art
- Portrait support with name tag (Mother 3 layout)
- Typewriter text reveal with snap-to-full on input
- Typewriter sound with per-character pitch variation
- Inline text effects (`[wave]`, `[shake]`, `[i]`, `[color]`, `[br]`)
- Three choice styles: vertical list, horizontal side-by-side, NITW-style dot navigation
- Per-node renderer selection — bubble or box, per node or per NPC default
- Per-node box position — bottom (default) or top of screen
- Per-NPC conversation memory via a flag system (currently bugged — see Bug 2)
- Press and auto-trigger modes
- Proximity prompt that appears when Mae is near an NPC
- Closest-NPC priority — only one NPC can trigger at a time

---

## Architecture

```
obj_dialogue_manager        Singleton. Loads JSON, owns all dialogue state,
                            drives typewriter, handles input.
                            Tracks current renderer, box layout, box style,
                            and box position per active node.

obj_dialogue_bubble         Spawned per dialogue line by dialogue_show_line().
                            Renders speech bubble above speaker in room space.
                            Follows speaker position each Step.

obj_dialogue_box            Spawned per dialogue line when renderer is "box".
                            Renders fixed-position textbox in GUI space.
                            Supports portrait, name tag, full, and undertale layouts.
                            Swappable 9-slice sprite background.
                            Drawn in Draw GUI event — stays fixed regardless of camera.

obj_dialogue_prompt         Spawned by each NPC on Create. Shows a small
                            floating bubble hint when Mae is nearby and
                            dialogue is not active.

oNPC                        Any NPC in the world. Holds its own config
                            (npc_id, trigger_type, trigger_range,
                            default_renderer). Drives proximity detection
                            and flag tracking.

oMae                        Player character. Input is locked to zero during
                            active dialogue.

scr_dialogue_parser         Converts tagged text strings into character
                            struct arrays consumed by both renderers.

scr_dialogue_functions      All dialogue lifecycle functions:
                            start, show_line, next_line, end,
                            set_flag, get_flag, bubble_set_option,
                            count_lines, get_speaker_name,
                            box_set_undertale_style.

Approach (script)           Utility: moves a value toward a target
                            without overshooting. Used by oMae for
                            horizontal acceleration.
```

### Data Flow

```
JSON File (dialogue_test.json — Included Files)
   └─► obj_dialogue_manager Create — buffer_load → json_parse → dialogue_data

Player presses E near NPC
   └─► oNPC Step — dialogue_start(node_id)
            └─► reads "renderer", "box_layout", "box_style", "box_position" from node
            └─► dialogue_show_line()
                     └─► scr_dialogue_parser → char struct array
                     └─► obj_dialogue_bubble  (room space, follows speaker)
                       OR obj_dialogue_box    (GUI space, locked to screen)
                              └─► Step: text effects + extended typewriter
                              └─► Draw / Draw GUI: bubble/box + choices
                     └─► obj_dialogue_manager Step
                              └─► typewriter reveal + sound
                              └─► E press → snap typewriter or dialogue_next_line()
                              └─► dialogue_end() when lines exhausted
```

---

## Object Reference

---

### obj_dialogue_manager

**Persistent singleton.** Place one instance in your first or init room. Handles all dialogue state — do not place more than one.

#### Create Event

```gml
/// @description Dialogue Manager — Initialize

// Singleton + persistence
if instance_number(obj_dialogue_manager) > 1 {
    instance_destroy();
    exit;
}
instance_persistent = true;

// Initialize flags only once — persists across rooms
if !variable_struct_exists(self, "flags") {
    flags = {};
}

// -------------------------
// STATE
// -------------------------
active           = false;     // true while dialogue is running
dialogue_data    = undefined; // parsed JSON
current_node     = undefined; // active node struct
line_index       = 0;         // which line in the node
char_index       = 0;         // typewriter progress
typewriter_speed = 2;         // chars revealed per frame
typewriter_timer = 0;

// Input
interact_key = ord("E");

// Reference to active bubble or box
bubble_inst = noone;

// -------------------------
// LOAD DIALOGUE FILE
// -------------------------
var _buffer = buffer_load(working_directory + "dialogue_test.json");
if _buffer != -1 {
    var _json_string = buffer_read(_buffer, buffer_text);
    buffer_delete(_buffer);
    dialogue_data = json_parse(_json_string);
}

// -------------------------
// SOUND
// -------------------------
typewriter_sound      = snd_typewriter;
typewriter_pitch_vary = true;

// -------------------------
// RENDERER STATE
// -------------------------
current_renderer     = "bubble";  // "bubble" or "box"
current_box_layout   = "full";    // "full" | "portrait" | "name_only"
current_box_style    = "default"; // "default" | "undertale"
current_box_position = "bottom";  // "bottom" | "top"

// -------------------------
// GUI DIMENSIONS
// -------------------------
display_set_gui_size(1920, 1080); // match to ZOOM_NORMAL / your target resolution
```

#### Step Event

```gml
/// @description Dialogue Manager — Typewriter + Input

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
        _chars[char_index].alpha    = 1;
        char_index++;
        typewriter_timer--;

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
        var _prev_index = bubble_inst.choice_index;

        // Navigation
        if _style == "vertical" {
            if keyboard_check_pressed(vk_up)   || keyboard_check_pressed(ord("W"))
                bubble_inst.choice_index = (bubble_inst.choice_index - 1 + _count) mod _count;
            if keyboard_check_pressed(vk_down) || keyboard_check_pressed(ord("S"))
                bubble_inst.choice_index = (bubble_inst.choice_index + 1) mod _count;
        } else { // horizontal and horizontal_extended both use A/D
            if keyboard_check_pressed(vk_left)  || keyboard_check_pressed(ord("A"))
                bubble_inst.choice_index = (bubble_inst.choice_index - 1 + _count) mod _count;
            if keyboard_check_pressed(vk_right) || keyboard_check_pressed(ord("D"))
                bubble_inst.choice_index = (bubble_inst.choice_index + 1) mod _count;
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
```

**Notes:**

- `display_set_gui_size(1920, 1080)` must match your camera viewport size — if you change `ZOOM_NORMAL` in oMae, update this too
- `interact_key` defaults to E. Change here to change globally, or override per box instance with `advance_key`
- `instance_persistent = true` means flags survive room transitions as long as the manager was created first

---

### obj_dialogue_bubble

**Spawned per dialogue line** by `dialogue_show_line()` when the active renderer is `"bubble"`. Never place manually in a room.

#### Create Event

```gml
/// @description Dialogue Bubble — Initialize

speaker_inst = noone; // instance this bubble floats above — set by dialogue_show_line
chars        = [];    // char struct array from scr_dialogue_parser

bubble_padding  = 24;
bubble_offset_y = 550;  // pixels above speaker origin — tune per sprite height
bubble_w        = 100;  // recalculated in Draw
bubble_h        = 100;  // recalculated in Draw
line_height     = 38;   // match to font size
char_width      = 22;   // approximate width per char at your font size
max_bubble_w    = 700;  // max width before text wraps

is_choice         = false;
choice_options    = [];
choice_index      = 0;
choice_style      = "vertical";
choice_title_text = "";

// Horizontal extended specific
choice_display_chars    = [];
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;
```

#### Step Event

```gml
/// @description Dialogue Bubble — Follow Speaker + Text Effects

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
            choice_display_chars[choice_typewriter_index].alpha    = 1;
            choice_typewriter_index++;
            choice_typewriter_timer--;
        }
    }
}
```

#### Draw Event

```gml
/// @description Dialogue Bubble — Draw

if array_length(chars) == 0 exit;

// Colors — tweak per game
var _bubble_fill    = c_white;
var _bubble_outline = c_white;
var _tail_color     = c_white;
var _text_color     = c_black;

// Settings — tune to match your font
var _font_w          = 22;
var _font_h          = 38;
var _padding         = 24;
var _max_bubble_w    = max_bubble_w;
var _chars_per_line  = floor((_max_bubble_w - _padding * 2) / _font_w);

// Dynamic bubble sizing — count lines needed
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

// Choice sizing overrides bubble dimensions
if is_choice {
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

var _bx = x - bubble_w / 2;
var _by = y - bubble_h;

// 1. Tail (drawn behind bubble)
draw_set_color(_tail_color);
draw_set_alpha(1);
draw_triangle(x - 8, _by + bubble_h, x + 8, _by + bubble_h, x, _by + bubble_h + 14, false);

// 2. Filled bubble
draw_set_color(_bubble_fill);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, false);

// 3. Outline
draw_set_color(_bubble_outline);
draw_set_alpha(1);
draw_roundrect_ext(_bx, _by, _bx + bubble_w, _by + bubble_h, 8, 8, true);

// 4. Text
var _draw_x = _bx + _padding;
var _draw_y = _by + _padding;
var _col    = 0;

draw_set_font(fnt_dialogue);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

for (var _i = 0; _i < array_length(chars); _i++) {
    var _c = chars[_i];
    if !_c.revealed continue;

    if _col >= _chars_per_line || _c.char == "\n" {
        _col    = 0;
        _draw_x = _bx + _padding;
        _draw_y += _font_h;
    }

    draw_set_color(_text_color);
    draw_set_alpha(_c.alpha);

    var _ix = _c.italic ? 2 : 0;
    draw_text(_draw_x + _c.x_off + _ix, _draw_y + _c.y_off, _c.char);

    _draw_x += _font_w;
    _col++;
}

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);

// 5. Choices
if is_choice {
    var _title_lines    = dialogue_count_lines(choice_title_text, _chars_per_line);
    var _choice_start_y = _by + _padding + (_title_lines * _font_h) + 12;

    if choice_style == "vertical" {
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
                draw_roundrect_ext(_cx - 4, _cy - 2, _cx + _opt_widths[_i], _cy + _font_h, 4, 4, false);
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
        var _total_opts = array_length(choice_options);
        var _text_y     = _choice_start_y;
        var _text_x     = _bx + _padding;
        var _wcol       = 0;
        var _total_disp = array_length(choice_display_chars);

        draw_set_font(fnt_dialogue);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        for (var _i = 0; _i < _total_disp; _i++) {
            var _c = choice_display_chars[_i];
            if !_c.revealed continue;

            if _c.char == " " {
                _text_x += _font_w;
                _wcol++;
            } else {
                var _word_len = 0;
                var _j = _i;
                while _j < _total_disp && choice_display_chars[_j].char != " " {
                    _word_len++;
                    _j++;
                }
                if _wcol + _word_len > _chars_per_line && _wcol > 0 {
                    _text_y += _font_h;
                    _text_x  = _bx + _padding;
                    _wcol    = 0;
                }
                draw_set_color(c_black);
                draw_set_alpha(_c.alpha);
                draw_text(_text_x + _c.x_off, _text_y + _c.y_off, _c.char);
                _text_x += _font_w;
                _wcol++;
            }
        }

        // Dot row
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
```

---

### obj_dialogue_box

**Spawned per dialogue line** by `dialogue_show_line()` when the active renderer is `"box"`. Draws in **GUI space** so it stays fixed to the bottom (or top) of the screen regardless of camera. Never place manually in a room.

#### Create Event

```gml
/// @description Dialogue Box — Initialize

#region Core
chars             = [];
speaker_name      = "";
portrait_spr      = -1;        // sprite index — -1 = none
is_choice         = false;
choice_options    = [];
choice_index      = 0;
choice_style      = "vertical";
choice_title_text = "";
#endregion

#region Layout
// "full"      — text only, full width (Undertale / default)
// "portrait"  — portrait left, name tag + text right (Mother 3)
// "name_only" — name tag above text, no portrait (EarthBound)
box_layout = "full";
#endregion

#region Box Dimensions — GUI/screen space pixels
box_h      = 180;
box_padding = 20;
portrait_w  = 140;
name_tag_h  = 36;
box_margin  = 60;
#endregion

#region Text Padding
text_padding_horizontal = 40;
text_padding_vertical   = 20;
#endregion

#region Box Style
box_sprite      = spr_box_default;
box_alpha       = 1;
box_style       = "default";   // "default" uses sprite | "undertale" draws in code
box_position    = "bottom";    // "bottom" | "top"
name_bg_color   = make_color_rgb(30, 30, 80);
name_text_color = c_white;
text_color      = c_white;
#endregion

#region Advance Key
advance_key = ord("E"); // ord("Z") for Undertale style — set by dialogue_box_set_undertale_style
#endregion

#region Extended Choice Typewriter
choice_display_chars    = [];
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;
#endregion
```

#### Step Event

```gml
/// @description Dialogue Box — Text Effects + Extended Typewriter

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
```

#### Draw GUI Event

```gml
/// @description Dialogue Box — Draw GUI
// Draws in GUI space — locked to screen regardless of camera position

var _font_w  = 22;
var _font_h  = 38;
var _padding = box_padding;
var _gui_w   = display_get_gui_width();
var _gui_h   = display_get_gui_height();

// Box position — bottom or top
var _box_margin = box_margin;
var _bx = _box_margin;
var _bw = _gui_w - (_box_margin * 2);
var _bh = box_h;

if box_position == "top" {
    var _by = _box_margin;
} else {
    var _by = _gui_h - box_h - _box_margin;
}

// Draw box background
if box_style == "undertale" {
    // White border rectangle
    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);

    // Black fill inset by border thickness
    var _border = 12;
    draw_set_color(c_black);
    draw_set_alpha(1);
    draw_rectangle(
        _bx + _border, _by + _border,
        _bx + _bw - _border, _by + _bh - _border,
        false
    );
} else {
    draw_set_alpha(box_alpha);
    draw_sprite_stretched(box_sprite, 0, _bx, _by, _bw, _bh);
    draw_set_alpha(1);
}

// Layout — Portrait
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

// Layout — Name Tag
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
        draw_text(_text_x + 4, _text_y - 2, speaker_name);
        _text_y += name_tag_h + 8;
    }
}

// Draw Text
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

    // Default color is c_black from parser — swap to white for dark bg
    draw_set_color(_c.color == c_black ? c_white : _c.color);
    draw_set_alpha(_c.alpha);

    var _ix = _c.italic ? 2 : 0;
    draw_text(_draw_x + _c.x_off + _ix, _draw_y + _c.y_off, _c.char);

    _draw_x += _font_w;
    _col++;
}

// Choices
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
                    _text_draw_x  = _text_x;
                    _wcol         = 0;
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
    }
}

// Advance indicator — blinking arrow (NOTE: shows during typewriter, see Bug 3)
if !is_choice {
    var _blink = (current_time mod 800) < 400;
    if _blink {
        draw_set_color(c_white);
        draw_set_alpha(1);
        var _ax = _bx + _bw - _padding - 80;
        var _ay = _by + _bh - _padding - 16;
        draw_triangle(_ax, _ay, _ax + 14, _ay, _ax + 7, _ay + 10, false);
    }
}

draw_set_alpha(1);
draw_set_color(c_white);
draw_set_font(-1);
```

**Notes:**

- Uses `Draw GUI` event — this is what keeps the box fixed to the screen regardless of camera position
- `box_style = "undertale"` draws a white rectangle then a black inset — no sprite needed
- `box_position = "top"` moves the box to the top of the screen — useful for Undertale-style upper encounters
- `box_layout = "full"` for Undertale/text-only, `"portrait"` for Mother 3, `"name_only"` for EarthBound
- When `box_layout == "portrait"`, `portrait_spr` must be set to a valid sprite index — the box reads it from the line's `"portrait"` field
- The advance indicator blinking arrow is currently always visible during typewriter animation (see Bug 3)

---

### obj_dialogue_prompt

**Spawned by each NPC on Create.** Shows a small floating `...` bubble when Mae is in range and no dialogue is active.

#### Create Event

```gml
follow_inst    = noone; // NPC instance — set by oNPC Create
bob_timer      = 0;
bob_speed      = 0.05;
bob_amount     = 6;     // pixels of vertical travel
alpha          = 0;
fade_speed     = 0.08;
visible_target = false; // set by oNPC Step each frame
instant_hide   = true;  // true = disappear instantly when out of range
```

#### Step Event

```gml
// Follow NPC
if instance_exists(follow_inst) {
    x = follow_inst.x;
    y = follow_inst.y - 620;
}

// Bob
bob_timer += bob_speed;
var _bob_offset = sin(bob_timer) * bob_amount;
y += _bob_offset;

// Fade
if visible_target {
    alpha = min(alpha + fade_speed, 1);
} else {
    if instant_hide {
        alpha = 0;
    } else {
        alpha = max(alpha - fade_speed, 0);
    }
}

// Cleanup
if !instance_exists(follow_inst) {
    instance_destroy();
}
```

#### Draw Event

```gml
if alpha <= 0 exit;

var _bw = 60;
var _bh = 36;
var _bx = x - _bw / 2;
var _by = y - _bh;

// Translucent fill — dark then white overlay
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);

draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);

// Tail
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_triangle(x - 5, _by + _bh, x + 5, _by + _bh, x, _by + _bh + 10, false);

draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_triangle(x - 5, _by + _bh, x + 5, _by + _bh, x, _by + _bh + 10, false);

// Three dots
var _dot_r     = 3;
var _dot_gap   = 14;
var _dot_start = x - _dot_gap;
var _dot_y     = _by + _bh / 2;

for (var _i = 0; _i < 3; _i++) {
    draw_set_color(c_black);
    draw_set_alpha(alpha);
    draw_circle(_dot_start + (_i * _dot_gap), _dot_y, _dot_r, false);
}

draw_set_alpha(1);
draw_set_color(c_white);
```

---

### oMae (Player)

**The player character.** Controls movement, physics, collision, animation, and camera. All input is set to false while `obj_dialogue_manager.active` is true.

#### Create Event

```gml
/// @description Mae — Initialize

// Movement
hsp = 0;
vsp = 0;
move_speed      = 12.0;
accel           = 1.4;
friction_ground = 0.6;   // LOWER stops faster
friction_air    = 0.58;

// Jump
jump_force     = -13;
gravity_val    = 0.43;
max_fall_speed = 12;

// Coyote time + jump buffer
coyote_time    = 0;
coyote_max     = 6;
jump_buffer    = 0;
jump_buffer_max = 8;

// State
on_ground    = false;
facing       = 1;        // 1 = right, -1 = left
sprite_scale = 1;
mask_index   = spr_mae_idle; // locks hitbox — prevents collision stutter on sprite swap

// Camera zoom presets
#macro ZOOM_CLOSE   0
#macro ZOOM_NORMAL  1
#macro ZOOM_FAR     2

var CAMERA_ZOOM = ZOOM_CLOSE; // currently defaults to ZOOM_CLOSE — change per room

var _zoom_w, _zoom_h;
switch (CAMERA_ZOOM) {
    case ZOOM_CLOSE:  _zoom_w = 1280; _zoom_h = 720;   break;
    case ZOOM_NORMAL: _zoom_w = 1920; _zoom_h = 1080;  break;
    case ZOOM_FAR:    _zoom_w = 2560; _zoom_h = 1440;  break;
}

// Camera — snap to Mae on spawn
var _cam = view_camera[0];
camera_set_view_size(_cam, _zoom_w, _zoom_h);
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);
var _start_x = clamp(x - _cam_w / 2, 0, room_width  - _cam_w);
var _start_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);
camera_set_view_pos(_cam, _start_x, _start_y);
```

#### Step Event

```gml
/// @description Mae Movement

// Input — locked during dialogue
var _dialogue_active = instance_exists(obj_dialogue_manager)
                       && obj_dialogue_manager.active;

if !_dialogue_active {
    key_left         = keyboard_check(vk_left)  || keyboard_check(ord("A"));
    key_right        = keyboard_check(vk_right) || keyboard_check(ord("D"));
    key_jump_pressed = keyboard_check_pressed(vk_space);
    key_jump_held    = keyboard_check(vk_space);
} else {
    key_left         = false;
    key_right        = false;
    key_jump_pressed = false;
    key_jump_held    = false;
}

// Horizontal speed
var _move = key_right - key_left;
if _move != 0 {
    hsp    = approach(hsp, move_speed * _move, accel);
    facing = sign(_move);
} else {
    var _fric = on_ground ? friction_ground : friction_air;
    hsp = lerp(hsp, 0, _fric);
    if abs(hsp) < 0.05 hsp = 0;
}

// Gravity
vsp = min(vsp + gravity_val, max_fall_speed);

// Variable jump height — release jump early to cut arc
if !key_jump_held && vsp < -2 {
    vsp += 0.4;
}

// Coyote time
if on_ground {
    coyote_time = coyote_max;
} else {
    coyote_time--;
}

// Jump buffer
if key_jump_pressed {
    jump_buffer = jump_buffer_max;
} else {
    jump_buffer--;
}

// Jump fires when buffer and coyote window overlap
if jump_buffer > 0 && coyote_time > 0 {
    vsp          = jump_force;
    jump_buffer  = 0;
    coyote_time  = 0;
}

// Horizontal collision
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

// Vertical collision
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

on_ground = place_meeting(x, y + 1, oPhysicalObject);

// Animation — driven from input, not hsp (prevents idle flicker at walls)
var _moving  = (key_right || key_left);
if !on_ground {
    sprite_index = spr_mae_jump;
} else {
    sprite_index = _moving ? spr_mae_walk : spr_mae_idle;
}

image_xscale = facing * sprite_scale;
image_yscale = sprite_scale;

// Camera — smooth lerp follow
var _cam   = view_camera[0];
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);

var _target_x = clamp(x - _cam_w / 2, 0, room_width  - _cam_w);
var _target_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);

var _curr_x = camera_get_view_x(_cam);
var _curr_y = camera_get_view_y(_cam);

camera_set_view_pos(_cam,
    lerp(_curr_x, _target_x, 0.12),
    lerp(_curr_y, _target_y, 0.12)
);
```

**Notes:**

- `mask_index = spr_mae_idle` in Create is critical — without it, swapping walk/jump/idle sprites with different bounding boxes causes wall collision stutter
- `approach()` must exist as a Script asset (see Script Reference)
- Camera lerp factor `0.12` — raise toward `1.0` for snappier tracking, lower for more lag
- Camera defaults to `ZOOM_CLOSE` (1280×720) in this version. Change `CAMERA_ZOOM` in Create to switch per room — also update `display_set_gui_size` in manager if you change the resolution

---

### oNPC

**Any NPC in the world.** Base defaults are in Create. Override per instance with Room Creation Code.

#### Create Event

```gml
/// @description NPC — Initialize

sprite_index = spr_npc_idle;
facing       = -1;           // faces left toward Mae by default
image_xscale = facing;

// Dialogue config — override in Room Creation Code per instance
npc_id              = "npc_01";
dialogue_node       = "npc_01_greet"; // auto-updated each Step by flag check
trigger_type        = "press";        // "press" | "auto"
trigger_range       = 300;
triggered_auto      = false;
dialogue_was_active = false;

// Renderer config — overrideable per NPC
default_renderer   = "bubble"; // used if node doesn't specify a renderer
default_box_layout = "full";

// Spawn prompt bubble
prompt_inst = instance_create_layer(x, y, "Instances", obj_dialogue_prompt);
prompt_inst.follow_inst = id;
```

**Room Creation Code per NPC instance:**

```gml
npc_id              = "npc_02";   // unique per NPC — must match JSON speaker + follow naming convention
trigger_type        = "press";
trigger_range       = 300;
triggered_auto      = false;
dialogue_was_active = false;
dialogue_node       = "npc_02_greet";
```

#### Step Event

```gml
/// @description NPC — Proximity Detection + Dialogue Trigger

if !instance_exists(obj_dialogue_manager) exit;
var _mgr = obj_dialogue_manager;

// Dynamic flag check
// Convention: npc_id "npc_02" → flag "met_npc_02" → nodes "npc_02_greet" / "npc_02_greet_return"
var _met_flag    = "met_" + npc_id;
var _first_node  = npc_id + "_greet";
var _return_node = npc_id + "_greet_return";
dialogue_node = dialogue_get_flag(_met_flag, false) ? _return_node : _first_node;

// Prompt visibility — runs before exits so prompt always updates
var _dist = point_distance(x, y, oMae.x, oMae.y);
if instance_exists(prompt_inst) {
    prompt_inst.visible_target = (_dist < trigger_range) && !_mgr.active;
}

// NOTE: dialogue_was_active tracking MUST be here, before early exits (see Bug 2)
if _mgr.active exit;
if _dist > trigger_range exit;

// Only closest NPC triggers — prevents double-firing when two NPCs overlap
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

// Trigger
if trigger_type == "auto" && !triggered_auto {
    triggered_auto = true;
    dialogue_start(dialogue_node);
}

if trigger_type == "press" {
    if keyboard_check_pressed(ord("E")) {
        dialogue_start(dialogue_node);
    }
}

// Flag setting — currently bugged (see Bug 2) because this code is after early exits
if dialogue_was_active && !_mgr.active {
    dialogue_set_flag("met_" + npc_id, true);
}
dialogue_was_active = _mgr.active;
```

---

## Script Reference

---

### `approach(val, target, amount)` — Approach (script)

Moves `val` toward `target` by `amount` without overshooting. Required by oMae for acceleration. GML does not have this built in.

```gml
function approach(val, target, amount) {
    if val < target {
        return min(val + amount, target);
    } else {
        return max(val - amount, target);
    }
}
```

---

### `dialogue_parse_text(text)` — scr_dialogue_parser

Converts a tagged text string into an array of character structs. Called by `dialogue_show_line()` for every line.

**Each struct:**

```
char      — single character string
italic    — bool, true if inside [i][/i]
effect    — "none" | "wave" | "shake"
color     — GM color value — defaults to c_black (box renderer swaps to white)
x_off     — float — driven by effect animation each Step
y_off     — float — driven by effect animation each Step
alpha     — float 0–1 — starts at 0, set to 1 when typewriter reveals
revealed  — bool — false until typewriter fires
```

The parser scans left to right, character by character. Tags are consumed and do not produce char structs. The `[br]` tag emits a `\n` struct directly.

---

### scr_dialogue_functions

#### `dialogue_start(node_id)`

Finds the node matching `node_id` in `dialogue_data.nodes`, sets it as `current_node`, sets `line_index = 0`, sets `active = true`, locks Mae (`hsp = 0`, `vsp = 0`), reads `renderer`, `box_layout`, `box_style`, and `box_position` from the node, then calls `dialogue_show_line()`.

If the node doesn't specify `renderer`, it searches for the calling NPC by matching `dialogue_node == node_id` and uses that NPC's `default_renderer`. Falls back to `"bubble"` if no NPC is found.

#### `dialogue_show_line()`

Reads `current_node.lines[line_index]`. Destroys the previous bubble/box if one exists. Spawns a new `obj_dialogue_bubble` (room space) or `obj_dialogue_box` (GUI space) depending on `current_renderer`. Parses the line's text with `dialogue_parse_text`. For choice lines, all title chars are immediately revealed (no typewriter). For box renderer, applies Undertale style if `current_box_style == "undertale"`. Calls `dialogue_end()` if `line_index >= array_length(lines)`.

#### `dialogue_next_line()`

Increments `line_index` and calls `dialogue_show_line()`.

#### `dialogue_end()`

Sets `active = false`, sets `current_node = undefined`, destroys `bubble_inst`, sets `bubble_inst = noone`.

#### `dialogue_set_flag(flag_name, value)`

```gml
variable_struct_set(obj_dialogue_manager.flags, flag_name, value);
```

#### `dialogue_get_flag(flag_name, default_val)`

Returns the stored flag value, or `default_val` if not set.

#### `dialogue_bubble_set_option(bubble, option_text)`

Parses `option_text` and loads it into `bubble.choice_display_chars` with all chars hidden (`revealed = false`, `alpha = 0`). Resets the extended typewriter counters. Used by the manager when the player navigates between `horizontal_extended` options.

#### `dialogue_count_lines(text, chars_per_line)`

Word-aware line counter. Splits `text` on spaces, wraps at `chars_per_line`. Returns the number of lines needed. Used for dynamic bubble and box height calculation before drawing choices.

#### `dialogue_get_speaker_name(speaker_id)`

Maps speaker ID strings to display names shown in the name tag. Currently mapped:

```
"mae"     → "Mae"
"bruce"   → "Bruce"
"npc_02"  → "Gregg"
"npc_03"  → "Angus"
"npc_04"  → "Mae"   ← (BUG: wrong name, see Known Bugs)
default   → raw speaker_id string
```

Add entries here for every named character in your game.

#### `dialogue_box_set_undertale_style(box_inst)`

Applies Undertale visual and dimension config to a box instance. Called automatically from `dialogue_show_line()` when `current_box_style == "undertale"`. Reads `current_box_position` from the manager for top/bottom placement.

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
      "renderer": "box",
      "box_layout": "portrait",
      "lines": [
        {
          "speaker": "bruce",
          "text": "Oh hey. You're back.",
          "portrait": "spr_portrait_placeholder"
        },
        {
          "speaker": "mae",
          "text": "Yeah I just... [wave]needed to walk.[/wave]",
          "portrait": "spr_portrait_placeholder2"
        }
      ]
    },
    {
      "id": "npc_undertale_greet",
      "renderer": "box",
      "box_layout": "full",
      "box_style": "undertale",
      "lines": [
        { "speaker": "npc_undertale", "text": "Feelin' [color=#ff0000]determined[/color]." }
      ]
    },
    {
      "id": "npc_undertale_greet_return",
      "renderer": "box",
      "box_layout": "full",
      "box_style": "undertale",
      "box_position": "top",
      "lines": [
        { "speaker": "npc_undertale", "text": "Can feel it in my heart." }
      ]
    },
    {
      "id": "npc_02_greet",
      "trigger": "press",
      "lines": [
        { "speaker": "npc_02", "text": "Feelin' a bit down today." },
        {
          "type": "choice",
          "style": "vertical",
          "title": "You doing [i]okay[/i]?",
          "options": [
            { "text": "Yeah I'm fine.", "goto": "npc_02_fine" },
            { "text": "Not really.",    "goto": "npc_02_bad"  }
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
| `renderer`     | string | no       | `"bubble"` or `"box"` — overrides NPC default                              |
| `box_layout`   | string | no       | `"full"` \| `"portrait"` \| `"name_only"` — only applies when renderer is box |
| `box_style`    | string | no       | `"undertale"` — applies Undertale visual preset                            |
| `box_position` | string | no       | `"bottom"` (default) \| `"top"` — which edge of screen                    |
| `lines`        | array  | yes      | Array of line objects                                                      |

### Normal Line Fields

| Field      | Type   | Required | Description                                                   |
| ---------- | ------ | -------- | ------------------------------------------------------------- |
| `speaker`  | string | yes      | Must match `npc_id` of an NPC in the room, or `"mae"`         |
| `text`     | string | yes      | Dialogue text — supports inline tags                          |
| `portrait` | string | no       | Sprite asset name — only used when `box_layout = "portrait"`. Empty string = no portrait |

### Choice Line Fields

| Field     | Type   | Required | Description                                                         |
| --------- | ------ | -------- | ------------------------------------------------------------------- |
| `type`    | string | yes      | Must be `"choice"`                                                  |
| `style`   | string | no       | `"vertical"` (default) \| `"horizontal"` \| `"horizontal_extended"` |
| `title`   | string | no       | Text shown above options — supports inline tags. Empty if omitted   |
| `options` | array  | yes      | Array of option objects                                             |

### Option Fields

| Field  | Type   | Required | Description                     |
| ------ | ------ | -------- | ------------------------------- |
| `text` | string | yes      | Option label shown to player    |
| `goto` | string | yes      | Node ID to jump to on selection |

---

## Inline Tags

All tags are parsed by `scr_dialogue_parser`. They work in both bubble and box renderers, and in choice titles.

| Tag                           | Effect                          |
| ----------------------------- | ------------------------------- |
| `[wave]text[/wave]`           | Sine wave Y oscillation         |
| `[shake]text[/shake]`         | Random X/Y jitter per frame     |
| `[i]text[/i]`                 | Fake italic via X offset (+2px) |
| `[color=#rrggbb]text[/color]` | Per-character hex color         |
| `[color=name]text[/color]`    | Per-character named color       |
| `[br]`                        | Force line break                |

### Supported Named Colors

`red` `green` `blue` `yellow` `white` `black` `orange` `purple` `gray` `grey` `lime` `aqua` `pink`

### Examples

```json
"text": "I'm [i]really[/i] not [wave]okay[/wave] right now."
"text": "This is [color=#ff0000]very important[/color]."
"text": "Feeling [color=red]angry[/color] today."
"text": "First thought.[br]Second thought on a new line."
```

---

## Choice Styles

### `vertical`

Stacked options navigated with **W/S** or **Up/Down**. Selected option gets a highlight background box. Best for 2–5 options with short-to-medium text.

```
You doing okay?
[▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓]
> Yeah I'm fine.
  Not really.
```

### `horizontal`

Side-by-side options centered in the bubble, navigated with **A/D** or **Left/Right**. Best for binary decisions with short text.

```
You enjoying this weather?
> Yep! Love rain.    Nope.
```

### `horizontal_extended`

NITW-style. One option's full text is shown at a time with a typewriter reveal. Navigate between options with **A/D** or **Left/Right** — each option wipes in fresh. A dot row at the bottom shows position. Best for 3+ options or long option text.

```
What do you think?
I don't know. Game development is really hard
and you never know when you've done enough.

● ○ ○
```

---

## Flag System

Flags are key/value pairs stored on `obj_dialogue_manager.flags`. They persist across rooms as long as the manager is persistent.

### Setting Flags

Set automatically when dialogue ends with an NPC (currently bugged — see Bug 2):

```gml
dialogue_set_flag("met_npc_02", true);
```

Set manually anywhere:

```gml
dialogue_set_flag("player_chose_bad_ending", true);
dialogue_set_flag("opened_cave_door", true);
```

### Reading Flags

```gml
if dialogue_get_flag("met_npc_02", false) {
    // player has spoken to NPC 02 before
}
```

### NPC Return Dialogue Convention

The NPC Step automatically derives node names from `npc_id`:

```
npc_id "npc_02"  →  first visit:  "npc_02_greet"
                 →  return visit: "npc_02_greet_return"
                 →  flag key:     "met_npc_02"
```

Add both nodes to your JSON. The system routes between them automatically once Bug 2 is fixed.

---

## Adding a New NPC

1. **Add nodes to JSON:**

```json
{
  "id": "npc_05_greet",
  "renderer": "box",
  "box_layout": "portrait",
  "lines": [
    {
      "speaker": "npc_05",
      "text": "Hey.",
      "portrait": "spr_portrait_npc05"
    },
    {
      "speaker": "mae",
      "text": "Hey.",
      "portrait": "spr_portrait_mae"
    }
  ]
},
{
  "id": "npc_05_greet_return",
  "renderer": "box",
  "box_layout": "portrait",
  "lines": [
    {
      "speaker": "npc_05",
      "text": "You again.",
      "portrait": "spr_portrait_npc05"
    }
  ]
}
```

2. **Place an `oNPC` instance in the room.**

3. **Set Room Creation Code:**

```gml
npc_id              = "npc_05";
trigger_type        = "press";
trigger_range       = 300;
triggered_auto      = false;
dialogue_was_active = false;
dialogue_node       = "npc_05_greet";
```

4. **Add the speaker name to `dialogue_get_speaker_name` in scr_dialogue_functions:**

```gml
case "npc_05": return "Bea";
```

5. **Done.** Once Bug 2 is fixed, return dialogue will work automatically.

---

## Porting to a New Game

Minimum assets to copy:

```
obj_dialogue_manager
obj_dialogue_bubble
obj_dialogue_box
obj_dialogue_prompt
oMae                    (swap sprites, tune physics per game)
oNPC                    (template — override per instance)
oPhysicalObject         (parent for all solid collision objects)
scr_dialogue_parser
scr_dialogue_functions
Approach                (script)
fnt_dialogue
snd_typewriter
spr_box_default         (9-slice sprite — swap for game-specific art)
your_dialogue.json      (new per game — place in Included Files)
```

### Per-game config

In `obj_dialogue_manager` Create:

```gml
var _buffer = buffer_load(working_directory + "your_game.json");
typewriter_sound = snd_your_typewriter;
display_set_gui_size(1920, 1080); // match your camera resolution
```

In `obj_dialogue_bubble` Create:

```gml
bubble_offset_y = 550; // tune per sprite height
max_bubble_w    = 700; // tune per camera/room size
```

In `obj_dialogue_bubble` Draw:

```gml
var _font_w = 22; // tune to your font
var _font_h = 38; // tune to your font
```

In `oMae` Create:

```gml
var CAMERA_ZOOM = ZOOM_NORMAL; // change to match your game's scale
```

---

## Tuning Reference

### Mae Physics

| Variable          | Location    | Effect                                                  |
| ----------------- | ----------- | ------------------------------------------------------- |
| `move_speed`      | oMae Create | Top walking speed in pixels per frame                   |
| `accel`           | oMae Create | How quickly Mae reaches top speed. Higher = snappier    |
| `friction_ground` | oMae Create | How quickly Mae stops on ground. Lower = stops faster   |
| `friction_air`    | oMae Create | Horizontal bleed in air. Lower = less air control       |
| `jump_force`      | oMae Create | Initial upward velocity. More negative = higher jump    |
| `gravity_val`     | oMae Create | Gravity per frame. Lower = floatier arc                 |
| `max_fall_speed`  | oMae Create | Terminal velocity cap                                   |
| `coyote_max`      | oMae Create | Frames after leaving ledge where jump still fires       |
| `jump_buffer_max` | oMae Create | Frames before landing that a jump press is remembered   |
| `CAMERA_ZOOM`     | oMae Create | `ZOOM_CLOSE` (1280×720) / `ZOOM_NORMAL` (1920×1080) / `ZOOM_FAR` (2560×1440) |

### Dialogue Box

| Variable                  | Location          | Effect                                                        |
| ------------------------- | ----------------- | ------------------------------------------------------------- |
| `box_h`                   | box Create        | Height of the textbox in GUI pixels                           |
| `box_padding`             | box Create        | Inner padding between box edge and content                    |
| `box_margin`              | box Create        | Outer margin — space between box and screen edges             |
| `text_padding_horizontal` | box Create        | Additional horizontal text inset inside box                   |
| `text_padding_vertical`   | box Create        | Additional vertical text inset inside box                     |
| `box_sprite`              | box Create        | Swap to any 9-slice sprite to change box visual               |
| `box_alpha`               | box Create        | Box opacity — 1 = fully opaque                                |
| `portrait_w`              | box Create        | Width and height of portrait image area                       |
| `name_tag_h`              | box Create        | Height of name tag background                                 |
| `name_bg_color`           | box Create        | Name tag background color                                     |
| `advance_key`             | box Create        | Key to advance lines — `ord("E")` or `ord("Z")` for Undertale |
| `box_layout`              | box Create        | `"full"` \| `"portrait"` \| `"name_only"`                     |
| `box_style`               | box Create        | `"default"` uses sprite \| `"undertale"` draws in code        |
| `box_position`            | box Create        | `"bottom"` or `"top"`                                         |
| `_border`                 | box Draw GUI      | Undertale border thickness in pixels (currently hardcoded 12) |

### Dialogue + Bubble

| Variable                | Location       | Effect                                       |
| ----------------------- | -------------- | -------------------------------------------- |
| `typewriter_speed`      | manager Create | Chars revealed per frame. Higher = faster    |
| `typewriter_pitch_vary` | manager Create | Random pitch on sound. `true` = personality  |
| `interact_key`          | manager Create | Key to advance dialogue globally             |
| `bubble_offset_y`       | bubble Create  | How far above speaker origin bubble appears  |
| `max_bubble_w`          | bubble Create  | Max bubble width before text wraps           |
| `_font_w`               | bubble Draw    | Char width estimate — must match actual font |
| `_font_h`               | bubble Draw    | Line height estimate — must match actual font |
| `trigger_range`         | NPC Create     | Pixel distance for proximity detection       |
| `bob_speed`             | prompt Create  | Speed of floating bob animation              |
| `bob_amount`            | prompt Create  | Pixels of vertical travel in bob             |
| `instant_hide`          | prompt Create  | `true` = prompt disappears instantly on exit |

---

_NITW Dialogue System v2 — LoafCentral / Myles Moore_  
_Built as a reusable prototype foundation for GMS2 projects._
