#+feature dynamic-literals
package restate

import "core:sync"
import "core:mem"

Shared_Render_State :: struct {
	mutex:     sync.Mutex,
	slides:    [dynamic]Slide,
	style:     Style,
	allocator: mem.Allocator,
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
	text: string
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
}

default_style :: proc() -> Style {
	return Style {
		background = {245, 245, 245, 255},
		title_color = {35, 75, 125, 255},
		text_color = {20, 20, 20, 255},
		title_position = {40, 40},
		text_position = {40, 90},
		title_font_size = 24,
		text_font_size = 20,
		text_spacing = 28,
		text_margin = 96,
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
