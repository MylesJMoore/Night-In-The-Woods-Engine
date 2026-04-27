// Follow the NPC
if instance_exists(follow_inst) {
    x = follow_inst.x;
    y = follow_inst.y - 620; // above the NPC, above where bubble appears
}

// Bob up and down gently
bob_timer += bob_speed;
var _bob_offset = sin(bob_timer) * bob_amount;
y += _bob_offset;

// Fade in/out based on visibility target
if visible_target {
    alpha = min(alpha + fade_speed, 1);
} else {
    if instant_hide {
        alpha = 0;
    } else {
        alpha = max(alpha - fade_speed, 0);
    }
}

// Destroy self if NPC gone
if !instance_exists(follow_inst) {
    instance_destroy();
}