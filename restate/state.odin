package restate

import "core:sync"

User_Data_State :: struct {
	counter: int,
	mutex: ^sync.Mutex,
}

Rendering_State :: struct {
	time: int,
	width: i32,
	height: i32,
	user_data: ^User_Data_State,
}
