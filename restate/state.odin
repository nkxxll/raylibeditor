#+feature dynamic-literals
package restate

import "core:sync"
import "core:mem"

Shared_Render_State :: struct {
	mutex:     sync.Mutex,
	slides:    [dynamic]Slide,
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
