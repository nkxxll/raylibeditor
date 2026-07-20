#+feature dynamic-literals
package restate

import "core:sync"
import "core:mem"

Shared_Render_State :: struct {
	mutex:     sync.Mutex,
	slides:    [dynamic]Slide,
	style:     Style,
	arena:     ^mem.Arena,
}

User_Data_State :: struct {
	render_state: ^Shared_Render_State,
}

Rendering_State :: struct {
	width:        i32,
	height:       i32,
	render_state: ^Shared_Render_State,
}

Text_Item :: struct {
	text:      string,
	style:     Style,
	overrides: Text_Style_Overrides,
}

Text_Alignment :: enum {
	LEFT,
	CENTER,
	RIGHT,
}

Color :: struct {
	r, g, b, a: u8,
}

Point :: struct {
	x, y: i32,
}

Style :: struct {
	background:       Color,
	title_color:      Color,
	text_color:       Color,
	title_position:   Point,
	text_position:    Point,
	title_font_size:  i32,
	text_font_size:   i32,
	text_spacing:     i32,
	text_margin:      i32,
	text_alignment:   Text_Alignment,
}

Text_Style_Overrides :: struct {
	text_color:     bool,
	text_font_size: bool,
	text_spacing:   bool,
	text_margin:    bool,
	text_alignment: bool,
}

default_style :: proc() -> Style {
	return Style {
		background = {20, 22, 27, 255},
		title_color = {166, 219, 255, 255},
		text_color = {224, 226, 234, 255},
		title_position = {40, 40},
		text_position = {40, 90},
		title_font_size = 24,
		text_font_size = 20,
		text_spacing = 28,
		text_margin = 96,
		text_alignment = .CENTER,
	}
}

delete_text_item :: proc(t: Text_Item) {
	delete(t.text)
}

Slide_Item :: union {
	Text_Item
}

Slide :: struct {
	title: string,
	items: [dynamic]Slide_Item
}
