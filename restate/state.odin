package restate

import "core:sync"
import "core:mem"

Shared_Render_State :: struct {
	mutex:     sync.Mutex,
	slides:    string,
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
