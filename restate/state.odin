package restate

import "core:sync"

Shared_Render_State :: struct {
	mutex:   sync.Mutex,
	counter: int,
}

User_Data_State :: struct {
	render_state: ^Shared_Render_State,
}

Rendering_State :: struct {
	width:        i32,
	height:       i32,
	render_state: ^Shared_Render_State,
}
