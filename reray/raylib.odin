package reray

import rl "vendor:raylib"
import "core:fmt"
import "core:sync/chan"
import "../restate"

State :: restate.Rendering_State

handle_message :: proc(state: ^State, message: restate.Rendering_Message) {
	switch msg in message {
	case restate.Update_Counter:
		state.counter = msg.counter
	}
}

receive_messages :: proc(state: ^State) {
	for message in chan.try_recv(state.render_messages) {
		handle_message(state, message)
	}
}

init :: proc(width: i32, height: i32, render_messages: restate.Rendering_Message_Channel) -> State {
	return State {
		counter = 0,
		width = width,
		height = height,
		render_messages = render_messages,
	}
}

update :: proc(state: ^State) {
	receive_messages(state)
	rl.DrawRectangleV(
		{ cast(f32)state.width / 4, cast(f32)state.height / 4 },
		{ 100, 100 },
		rl.RED
	)
	rl.DrawText(
		fmt.ctprintf("hello world %d", state.counter),
		state.width / 2,
		state.height / 2,
		10,
		rl.BLUE
	)
}

run :: proc(state: rawptr) {
	s := cast(^State)state
	rl.SetConfigFlags({ .WINDOW_RESIZABLE });
	rl.InitWindow(s.width, s.height, "raylib editor")
	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		if rl.IsWindowResized() {
			width := rl.GetScreenWidth()
			height := rl.GetScreenHeight()
			s.width = width
			s.height = height
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		update(s)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()
}
