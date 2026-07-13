package reray

import rl "vendor:raylib"
import "core:fmt"
import "core:sync"
import "../restate"

State :: restate.Rendering_State

init :: proc(width: i32, height: i32, render_state: ^restate.Shared_Render_State) -> State {
	return State {
		width = width,
		height = height,
		render_state = render_state,
	}
}

update :: proc(state: ^State) {
	sync.mutex_lock(&state.render_state.mutex)
	counter := state.render_state.counter
	sync.mutex_unlock(&state.render_state.mutex)

	rl.DrawRectangleV(
		{ cast(f32)state.width / 4, cast(f32)state.height / 4 },
		{ 100, 100 },
		rl.RED
	)
	rl.DrawText(
		fmt.ctprintf("hello world %d", counter),
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
