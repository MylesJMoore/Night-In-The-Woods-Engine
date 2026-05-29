/// @description Dialogue Box — Initialize

#region Core
chars        = [];        // char struct array from parser
speaker_name = "";        // display name shown in name tag
portrait_spr = -1;        // sprite index for portrait, -1 = none
is_choice    = false;
choice_options  = [];
choice_index    = 0;
choice_style    = "vertical";
choice_title_text = "";
#endregion

#region Layout
// "full" | "portrait" | "name_only"
box_layout = "full";
#endregion

#region Box Dimensions — in screen space
box_h       = 180;        // height of the dialogue box
box_padding = 20;         // inner padding
portrait_w  = 140;        // width of portrait area
name_tag_h  = 36;         // height of name tag above text
box_margin = 60;          // pixels of padding around the box ex: 60
#endregion

#region Text Padding Within Box
text_padding_horizontal = 40;
text_padding_vertical = 20;
#endregion

#region Box Style
box_sprite  = spr_box_default;  // swappable 9-slice background sprite
box_alpha   = 1;
name_bg_color   = make_color_rgb(30, 30, 80);  // dark blue name tag
name_text_color = c_white;
text_color      = c_white;      // text color — white on dark bg
box_style = "default"
box_position = "bottom"; // "bottom" or "top"
#endregion

#region Advance Key
// Configurable — defaults to same as bubble system
advance_key = ord("E"); // swap to ord("Z") for Undertale style
#endregion

#region Extended Choice
choice_display_chars    = [];
choice_typewriter_index = 0;
choice_typewriter_timer = 0;
choice_typewriter_speed = 2;
#endregion