package reray

import rl "vendor:raylib"
import "core:sync"
import "../restate"
import "core:strings"

@(private)
current_slide : int = 0

Render_Text_Item :: struct {
	text: string
}

Render_Slide_Item :: union {
	Render_Text_Item
}

Render_Slide :: struct {
	title: string,
	items: [dynamic]Render_Slide_Item
}

to_ray_color :: proc(color: restate.Color) -> rl.Color {
	return rl.Color{color.r, color.g, color.b, color.a}
}

make_render_text_item :: proc(text: string, allocator := context.temp_allocator) -> Render_Slide_Item {
	return Render_Slide_Item(Render_Text_Item {
		text = strings.clone(text, allocator),
	})
}

make_render_slide_item :: proc(item: restate.Slide_Item, allocator := context.temp_allocator) -> Render_Slide_Item {
	switch value in item {
	case restate.Text_Item:
		return make_render_text_item(value.text, allocator)
	}

	panic("unknown slide item type")
}

make_render_slide :: proc(slide: restate.Slide, allocator := context.temp_allocator) -> Render_Slide {
	items := make([dynamic]Render_Slide_Item, 0, len(slide.items), allocator)
	for item in slide.items {
		append(&items, make_render_slide_item(item, allocator))
	}

	return Render_Slide {
		title = strings.clone(slide.title, allocator),
		items = items,
	}
}

init :: proc(width: i32, height: i32, render_state: ^restate.Shared_Render_State) -> restate.Rendering_State {
	return restate.Rendering_State {
		width = width,
		height = height,
		render_state = render_state,
	}
}

update :: proc(state: ^restate.Rendering_State) {
	slides := make([dynamic]Render_Slide, 0, 16, context.temp_allocator)
	sync.mutex_lock(&state.render_state.mutex)
	style := state.render_state.style
	for slide in state.render_state.slides {
		append(&slides, make_render_slide(slide, context.temp_allocator))
	}
	sync.mutex_unlock(&state.render_state.mutex)

	rl.ClearBackground(to_ray_color(style.background))
	if len(slides) > 0 {
		if rl.IsKeyPressed(.SPACE) {
			shift_is_down := rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)
			if shift_is_down {
				if current_slide > 0 {
					current_slide -= 1
				}
			} else if current_slide + 1 < len(slides) {
				current_slide += 1
			}
		}

		if current_slide >= len(slides) {
			current_slide = len(slides) - 1
		}

		slide := slides[current_slide]
		rl.DrawText(
			strings.clone_to_cstring(slide.title, context.temp_allocator),
			style.title_position.x,
			style.title_position.y,
			style.title_font_size,
			to_ray_color(style.title_color),
		)

		y := style.text_position.y
		for item in slide.items {
			switch value in item {
			case Render_Text_Item:
				rl.DrawText(
					strings.clone_to_cstring(value.text, context.temp_allocator),
					style.text_position.x,
					y,
					style.text_font_size,
					to_ray_color(style.text_color),
				)
				y += style.text_spacing
			}
		}
	}
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
