// -------------------------
// MOVEMENT
// -------------------------

hsp = 0; // current horizontal speed (pixels per frame, calculated each step)
vsp = 0; // current vertical speed (pixels per frame, positive = falling)

move_speed = 12.0;   // top walking speed — raise for faster movement
accel = 1.4;        // how quickly you reach move_speed — higher = snappier startup
friction_ground = 0.6; // how quickly you stop on the ground — LOWER = stops faster
friction_air = 0.58;   // how quickly horizontal speed bleeds off in the air — lower = less air control

// -------------------------
// JUMP
// -------------------------

jump_force = -13;  // initial upward velocity on jump — more negative = higher jump
gravity_val = 0.43; // gravity added to vsp each frame — LOWER = floatier, higher = snappier fall
max_fall_speed = 12; // terminal velocity — caps how fast you fall

// -------------------------
// COYOTE TIME + JUMP BUFFER
// -------------------------

coyote_time = 0;        // internal counter, do not set manually
coyote_max = 6;         // frames after walking off a ledge you can still jump — feels forgiving
jump_buffer = 0;        // internal counter, do not set manually
jump_buffer_max = 8;    // frames before landing that a jump input is remembered and fires on touch

// -------------------------
// STATE
// -------------------------

on_ground = false; // true when standing on oPhysicalObject — drives jump logic and animation
facing = 1;        // 1 = right, -1 = left — controls sprite flip via image_xscale
sprite_scale = 1;  // uniform scale applied to image_xscale and image_yscale — 1 = native size
mask_index = spr_mae_idle; // Lock collision mask permanently



// -------------------------
// CAMERA ZOOM PRESETS
// Switch CAMERA_ZOOM to change zoom level
// -------------------------
#macro ZOOM_CLOSE   0
#macro ZOOM_NORMAL  1
#macro ZOOM_FAR     2

var CAMERA_ZOOM = ZOOM_CLOSE; // change this to switch presets

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

// -------------------------
// CAMERA
// -------------------------
var _cam = view_camera[0];
camera_set_view_size(_cam, _zoom_w, _zoom_h);
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);
var _start_x = clamp(x - _cam_w / 2, 0, room_width - _cam_w);
var _start_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);
camera_set_view_pos(_cam, _start_x, _start_y);