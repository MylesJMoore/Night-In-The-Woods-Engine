if alpha <= 0 exit;

var _bw = 60;  // small bubble width
var _bh = 36;  // small bubble height
var _bx = x - _bw / 2;
var _by = y - _bh;

// Hollow bubble outline only — hinting at dialogue
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);

// White fill slightly transparent
draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, false);

// Outline
/*
draw_set_color(c_black);
draw_set_alpha(alpha);
draw_roundrect_ext(_bx, _by, _bx + _bw, _by + _bh, 8, 8, true);*/

// Small tail
draw_set_color(c_black);
draw_set_alpha(alpha * 0.8);
draw_triangle(
    x - 5, _by + _bh,
    x + 5, _by + _bh,
    x,     _by + _bh + 10,
    false
);
draw_set_color(c_white);
draw_set_alpha(alpha * 0.6);
draw_triangle(
    x - 5, _by + _bh,
    x + 5, _by + _bh,
    x,     _by + _bh + 10,
    false
);

// Three dots inside — classic "..." indicator
var _dot_r = 3;
var _dot_gap = 14;
var _dot_start = x - _dot_gap;
var _dot_y = _by + _bh / 2;

for (var _i = 0; _i < 3; _i++) {
    draw_set_color(c_black);
    draw_set_alpha(alpha);
    draw_circle(_dot_start + (_i * _dot_gap), _dot_y, _dot_r, false);
}

draw_set_alpha(1);
draw_set_color(c_white);