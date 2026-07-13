package reray

import rl "vendor:raylib"
import "core:fmt"
import "core:sync"
import "../restate"
import "core:strings"

init :: proc(width: i32, height: i32, render_state: ^restate.Shared_Render_State) -> restate.Rendering_State {
	return restate.Rendering_State {
		width = width,
		height = height,
		render_state = render_state,
	}
}

update :: proc(state: ^restate.Rendering_State) {
	text : string
	if sync.mutex_try_lock(&state.render_state.mutex) {
		text = state.render_state.slides
		sync.mutex_unlock(&state.render_state.mutex)
	}

	rl.DrawRectangleV(
		{ cast(f32)state.width / 4, cast(f32)state.height / 4 },
		{ 100, 100 },
		rl.RED
	)
	rl.DrawText(
		strings.clone_to_cstring(text, context.temp_allocator),
		state.width / 2,
		state.height / 2,
		10,
		rl.BLUE
	)
}

run :: proc(state: rawptr) {
	s := cast(^restate.Rendering_State)state
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
