package restate

import "core:sync/chan"

Rendering_Message_Channel :: chan.Chan(Rendering_Message)

Update_Counter :: struct {
	counter: int,
}

Rendering_Message :: union {
	Update_Counter,
}

User_Data_State :: struct {
	counter: int,
	render_messages: Rendering_Message_Channel,
}

Rendering_State :: struct {
	counter: int,
	width: i32,
	height: i32,
	render_messages: Rendering_Message_Channel,
}
