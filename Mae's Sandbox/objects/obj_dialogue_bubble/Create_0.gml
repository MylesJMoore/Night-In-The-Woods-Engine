speaker_inst = noone;
chars = [];

bubble_padding = 24;
bubble_offset_y = 550;
bubble_w = 100; // will be recalculated
bubble_h = 100; // will be recalculated
line_height = 38;    // match to your font size
char_width = 22;     // approximate width per character at your font size
max_bubble_w = 700;  // max width before text wraps

is_choice = false;
choice_options = [];
choice_index = 0;
choice_style = "vertical";
choice_title_text = ""; // raw title string for word-aware sizing

// Horizontal extended specific
choice_display_chars = [];
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;