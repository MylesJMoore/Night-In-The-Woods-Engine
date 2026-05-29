/// @description Mae Movement

#region Input
var _dialogue_active = instance_exists(obj_dialogue_manager) 
                       && obj_dialogue_manager.active;

if !_dialogue_active {
    key_left  = keyboard_check(vk_left)  || keyboard_check(ord("A"));
    key_right = keyboard_check(vk_right) || keyboard_check(ord("D"));
    key_jump_pressed = keyboard_check_pressed(vk_space);
    key_jump_held    = keyboard_check(vk_space);
} else {
    key_left  = false;
    key_right = false;
    key_jump_pressed = false;
    key_jump_held    = false;
}
#endregion

#region Movement Calculations
var _move = key_right - key_left;

// Horizontal speed
if _move != 0 {
    hsp = approach(hsp, move_speed * _move, accel);
    facing = sign(_move);
} else {
    var _fric = on_ground ? friction_ground : friction_air;
    hsp = lerp(hsp, 0, _fric);
    if abs(hsp) < 0.05 hsp = 0;
}

// Gravity
vsp = min(vsp + gravity_val, max_fall_speed);

// Variable jump height — cutting jump early bleeds upward momentum
if !key_jump_held && vsp < -2 {
    vsp += 0.4;
}

// Coyote time — counts down after leaving ground
if on_ground {
    coyote_time = coyote_max;
} else {
    coyote_time--;
}

// Jump buffer — counts down after pressing jump
if key_jump_pressed {
    jump_buffer = jump_buffer_max;
} else {
    jump_buffer--;
}

// Jump fires if buffered input meets coyote window
if jump_buffer > 0 && coyote_time > 0 {
    vsp = jump_force;
    jump_buffer = 0;
    coyote_time = 0;
}
#endregion

#region Collisions
// Horizontal
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

// Vertical
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
#endregion

#region Animation
var _moving = (key_right || key_left);
var _rising = vsp < -1;   // clearly going up
var _falling = vsp > 1;   // clearly going down

if !on_ground {
    sprite_index = spr_mae_jump; // use jump sprite for both rise and fall for now
} else {
    if _moving {
        sprite_index = spr_mae_walk;
    } else {
        sprite_index = spr_mae_idle;
    }
}

image_xscale = facing * sprite_scale;
image_yscale = sprite_scale;
#endregion

#region Camera
var _cam = view_camera[0];
var _cam_w = camera_get_view_width(_cam);
var _cam_h = camera_get_view_height(_cam);

var _target_x = clamp(x - _cam_w / 2, 0, room_width - _cam_w);
var _target_y = clamp(y - _cam_h / 2, 0, room_height - _cam_h);

var _curr_x = camera_get_view_x(_cam);
var _curr_y = camera_get_view_y(_cam);

camera_set_view_pos(_cam,
    lerp(_curr_x, _target_x, 0.12),
    lerp(_curr_y, _target_y, 0.12)
);
#endregion

