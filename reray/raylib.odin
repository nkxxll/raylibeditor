package reray

import rl "vendor:raylib"
import "core:fmt"
import "core:sync"
import "../restate"

State :: restate.Rendering_State

update_state_from_user_data :: proc(state: ^State) {
	if state.user_data == nil || state.user_data.mutex == nil {
		return
	}

	if sync.mutex_try_lock(state.user_data.mutex) {
		state.time = state.user_data.counter
		sync.mutex_unlock(state.user_data.mutex)
	}
}

init :: proc(width: i32, height: i32, user_data: ^restate.User_Data_State) -> State {
	return State {
		time = 0,
		width = width,
		height = height,
		user_data = user_data,
	}
}

update :: proc(state: ^State) {
	// receive
	update_state_from_user_data(state)
	rl.DrawRectangleV(
		{ cast(f32)state.width / 4, cast(f32)state.height / 4 },
		{ 100, 100 },
		rl.RED
	)
	rl.DrawText(
		fmt.ctprintf("hello world %d", state.time),
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
