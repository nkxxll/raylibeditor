package reray

import rl "vendor:raylib"
import "core:sync"
import "../restate"
import "core:strings"

@(private)
current_slide : int = 0

Render_Text_Item :: struct {
	text:      string,
	style:     restate.Style,
	overrides: restate.Text_Style_Overrides,
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

merge_text_style :: proc(global, local: restate.Style, overrides: restate.Text_Style_Overrides) -> restate.Style {
	style := global
	if overrides.text_color {
		style.text_color = local.text_color
	}
	if overrides.text_font_size {
		style.text_font_size = local.text_font_size
	}
	if overrides.text_spacing {
		style.text_spacing = local.text_spacing
	}
	if overrides.text_margin {
		style.text_margin = local.text_margin
	}
	if overrides.text_alignment {
		style.text_alignment = local.text_alignment
	}
	return style
}

make_render_text_item :: proc(text: string, allocator := context.temp_allocator) -> Render_Slide_Item {
	return Render_Slide_Item(Render_Text_Item {
		text = strings.clone(text, allocator),
	})
}

make_render_slide_item :: proc(item: restate.Slide_Item, allocator := context.temp_allocator) -> Render_Slide_Item {
	switch value in item {
	case restate.Text_Item:
		return Render_Slide_Item(Render_Text_Item {
			text = strings.clone(value.text, allocator),
			style = value.style,
			overrides = value.overrides,
		})
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

measure_text :: proc(text: string, font_size: i32) -> i32 {
	return rl.MeasureText(strings.clone_to_cstring(text, context.temp_allocator), font_size)
}

draw_text_boxed :: proc(text: string, bounds: rl.Rectangle, font_size: i32, spacing: i32, alignment: restate.Text_Alignment, color: rl.Color, allocator := context.temp_allocator) -> i32 {
	max_width := i32(bounds.width)
	line_start := 0
	line_end := 0
	start_y := i32(bounds.y)
	y := start_y
	for line_end <= len(text) {
		if line_end == len(text) || text[line_end] == '\n' {
			line := text[line_start:line_end]
			c_line := strings.clone_to_cstring(line, context.temp_allocator)
			line_width := rl.MeasureText(c_line, font_size)
			x := i32(bounds.x)
			switch alignment {
			case .LEFT:
			case .CENTER: x += (max_width - line_width) / 2
			case .RIGHT: x += max_width - line_width
			}
			rl.DrawText(c_line, x, y, font_size, color)
			y += spacing
			line_start = line_end + 1
			line_end = line_start
			continue
		}

		word_end := line_end
		for word_end < len(text) && text[word_end] != ' ' && text[word_end] != '\t' && text[word_end] != '\n' {
			word_end += 1
		}
		candidate := text[line_start:word_end]
		if line_end != line_start && measure_text(candidate, font_size) > max_width {
			line := text[line_start:line_end]
			c_line := strings.clone_to_cstring(line, context.temp_allocator)
			line_width := rl.MeasureText(c_line, font_size)
			x := i32(bounds.x)
			switch alignment {
			case .LEFT:
			case .CENTER: x += (max_width - line_width) / 2
			case .RIGHT: x += max_width - line_width
			}
			rl.DrawText(c_line, x, y, font_size, color)
			y += spacing
			line_start = line_end + 1
		}
		line_end = word_end
		if line_end < len(text) && (text[line_end] == ' ' || text[line_end] == '\t') {
			line_end += 1
		}
		if y >= i32(bounds.y + bounds.height) {
			break
		}
	}
	return y - start_y
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
		title := strings.clone_to_cstring(slide.title, context.temp_allocator)
		rl.DrawText(
			title,
			(state.width - rl.MeasureText(title, style.title_font_size)) / 2,
			style.text_margin,
			style.title_font_size,
			to_ray_color(style.title_color),
		)

		max_width := state.width - style.text_margin * 2
		text_bounds := rl.Rectangle {
			x = f32(style.text_margin),
			y = f32(style.text_margin * 2),
			width = f32(max_width),
			height = f32(state.height - style.text_margin * 3),
		}
		for item in slide.items {
			switch value in item {
			case Render_Text_Item:
				item_style := merge_text_style(style, value.style, value.overrides)
				item_bounds := text_bounds
				item_bounds.x = f32(item_style.text_margin)
				item_bounds.width = f32(state.width - item_style.text_margin * 2)
				item_bounds.height = f32(state.height) - item_bounds.y - f32(item_style.text_margin)
				used_height := draw_text_boxed(value.text, item_bounds, item_style.text_font_size, item_style.text_spacing, item_style.text_alignment, to_ray_color(item_style.text_color))
				advance := f32(used_height)
				if advance < f32(item_style.text_spacing) {
					advance = f32(item_style.text_spacing)
				}
				text_bounds.y += advance
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
