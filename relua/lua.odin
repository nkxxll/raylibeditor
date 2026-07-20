package relua

import lua "vendor:lua/5.4"
import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:sync"
import "core:mem"
import "../restate"

/*
   this is the user data that is in odin state while the scripts are running
   this is the basis on which raylib data is sent
*/
User_Data :: restate.User_Data_State

lua_ctx: runtime.Context

state_init :: proc(user_data: ^User_Data) -> ^lua.State {
	lua_ctx = context

	L := lua.L_newstate()
	if L == nil {
		panic("ah no lua state")
	}

	lua.pushlightuserdata(L, user_data)

	// @todo we can modularize this so that we can push automatically a
	// centrally defined list of functions with names to the lua functions
	lua.pushcclosure(L, update_state, 1)
	lua.setglobal(L, "raylibeditor_update_state")

	lua.L_openlibs(L)
	return L
}

handle_text_slide_item :: proc(L: ^lua.State, absolute_item_index: i32, allocator := context.allocator) -> restate.Text_Item {
	lua.getfield(L, absolute_item_index, "value")
	text := lua.L_checkstring(L, -1)
	lua.pop(L, 1)

	style := restate.default_style()
	overrides: restate.Text_Style_Overrides
	lua.getfield(L, absolute_item_index, "style")
	if !lua.isnil(L, -1) {
		style_index := lua.absindex(L, -1)
		style = handle_style(L, style_index)

		lua.getfield(L, style_index, "text_color")
		overrides.text_color = !lua.isnil(L, -1)
		lua.pop(L, 1)
		lua.getfield(L, style_index, "text_font_size")
		overrides.text_font_size = !lua.isnil(L, -1)
		lua.pop(L, 1)
		lua.getfield(L, style_index, "text_spacing")
		overrides.text_spacing = !lua.isnil(L, -1)
		lua.pop(L, 1)
		lua.getfield(L, style_index, "text_margin")
		overrides.text_margin = !lua.isnil(L, -1)
		lua.pop(L, 1)
		lua.getfield(L, style_index, "text_alignment")
		overrides.text_alignment = !lua.isnil(L, -1)
		lua.pop(L, 1)
	}
	lua.pop(L, 1)

	return restate.Text_Item {
		text = strings.clone(string(text), allocator),
		style = style,
		overrides = overrides,
	}
}

// this reads the type and dispatches to the specific item handlers	
handle_slide_item :: proc(L: ^lua.State, index: i32, allocator := context.allocator) -> restate.Slide_Item {
	// { type = "<some type>", value = "<value>", ..args = special optional
	// keys for this item type

	absolute_item_index := lua.absindex(L, index);

	lua.getfield(L, absolute_item_index, "type");
	type := lua.L_checkstring(L, -1);
	lua.pop(L, 1);

	switch type {
	case "text":
		ti := handle_text_slide_item(L, absolute_item_index, allocator)
		return restate.Slide_Item(ti)
	case:
		lua.L_error(L, "unknown slide item type %s", type)
	}

	// todo might be better to use err here and dual return
	panic("this cannot happen actually")
}

handle_slide :: proc(L: ^lua.State, index: i32, allocator := context.allocator) -> restate.Slide {
	slide_index := lua.absindex(L, index)

	lua.getfield(L, slide_index, "title")
	title := lua.L_checkstring(L, -1)
	title_clone := strings.clone(string(title), allocator)
	lua.pop(L, 1)

	lua.getfield(L, slide_index, "slide_items")
	lua.L_checktype(L, -1, i32(lua.TTABLE))
	slide_items_index := lua.absindex(L, -1)
	items := make([dynamic]restate.Slide_Item, 0, int(lua.rawlen(L, slide_items_index)), allocator)

	for i in 1..=lua.rawlen(L, slide_items_index) {
		lua.geti(L, slide_items_index, lua.Integer(i))
		append(&items, handle_slide_item(L, -1, allocator))
		lua.pop(L, 1)
	}
	lua.pop(L, 1)

	return restate.Slide {
		title = title_clone,
		items = items,
	}
}

handle_color :: proc(L: ^lua.State, index: i32, fallback: restate.Color) -> restate.Color {
	if lua.isnil(L, index) {
		return fallback
	}
	lua.L_checktype(L, index, i32(lua.TTABLE))
	color := fallback
	color_index := lua.absindex(L, index)
	for key in 0..<4 {
		component: cstring
		switch key {
		case 0: component = "r"
		case 1: component = "g"
		case 2: component = "b"
		case 3: component = "a"
		}
		lua.getfield(L, color_index, component)
		if !lua.isnil(L, -1) {
			value := lua.L_checkinteger(L, -1)
			if value < 0 || value > 255 {
				lua.L_error(L, "style color component %s must be between 0 and 255", component)
			}
			switch key {
			case 0: color.r = u8(value)
			case 1: color.g = u8(value)
			case 2: color.b = u8(value)
			case 3: color.a = u8(value)
			}
		}
		lua.pop(L, 1)
	}
	return color
}

handle_point :: proc(L: ^lua.State, index: i32, fallback: restate.Point) -> restate.Point {
	if lua.isnil(L, index) {
		return fallback
	}
	lua.L_checktype(L, index, i32(lua.TTABLE))
	point := fallback
	point_index := lua.absindex(L, index)
	for key in 0..<2 {
		component: cstring
		switch key {
		case 0: component = "x"
		case 1: component = "y"
		}
		lua.getfield(L, point_index, component)
		if !lua.isnil(L, -1) {
			switch key {
			case 0: point.x = i32(lua.L_checkinteger(L, -1))
			case 1: point.y = i32(lua.L_checkinteger(L, -1))
			}
		}
		lua.pop(L, 1)
	}
	return point
}

handle_style :: proc(L: ^lua.State, index: i32) -> restate.Style {
	lua.L_checktype(L, index, i32(lua.TTABLE))
	style := restate.default_style()
	style_index := lua.absindex(L, index)

	lua.getfield(L, style_index, "background")
	style.background = handle_color(L, -1, style.background)
	lua.pop(L, 1)
	lua.getfield(L, style_index, "title_color")
	style.title_color = handle_color(L, -1, style.title_color)
	lua.pop(L, 1)
	lua.getfield(L, style_index, "text_color")
	style.text_color = handle_color(L, -1, style.text_color)
	lua.pop(L, 1)
	lua.getfield(L, style_index, "title_position")
	style.title_position = handle_point(L, -1, style.title_position)
	lua.pop(L, 1)
	lua.getfield(L, style_index, "text_position")
	style.text_position = handle_point(L, -1, style.text_position)
	lua.pop(L, 1)
	lua.getfield(L, style_index, "text_alignment")
	if !lua.isnil(L, -1) {
		alignment := lua.L_checkstring(L, -1)
		switch alignment {
		case "left": style.text_alignment = .LEFT
		case "center": style.text_alignment = .CENTER
		case "right": style.text_alignment = .RIGHT
		case:
			lua.L_error(L, "style.text_alignment must be left, center, or right")
		}
	}
	lua.pop(L, 1)

	for key in 0..<4 {
		field: cstring
		switch key {
		case 0: field = "title_font_size"
		case 1: field = "text_font_size"
		case 2: field = "text_spacing"
		case 3: field = "text_margin"
		}
		lua.getfield(L, style_index, field)
		if !lua.isnil(L, -1) {
			value := lua.L_checkinteger(L, -1)
			if value <= 0 {
				lua.L_error(L, "style.%s must be greater than zero", field)
			}
			switch key {
			case 0: style.title_font_size = i32(value)
			case 1: style.text_font_size = i32(value)
			case 2: style.text_spacing = i32(value)
			case 3: style.text_margin = i32(value)
			}
		}
		lua.pop(L, 1)
	}
	return style
}

Parsed_State :: struct {
	slides:    [dynamic]restate.Slide,
	style:     restate.Style,
	has_index: bool,
	has_style: bool,
}

handle_index :: proc(L: ^lua.State, index: i32, allocator: mem.Allocator) -> [dynamic]restate.Slide {
	list_index := lua.absindex(L, index)
	slides := make([dynamic]restate.Slide, 0, 16, allocator)
	
	for i in 1..=lua.rawlen(L, list_index) {
		lua.geti(L, list_index, lua.Integer(i))
		if !lua.istable(L, -1) {
			lua.L_error(L, "slide values must be tables, got %s", lua.L_typename(L, -1))
		}

		append(&slides, handle_slide(L, -1, allocator))
		lua.pop(L, 1)
	}

	return slides
}

clone_slide_item :: proc(item: restate.Slide_Item, allocator: mem.Allocator) -> restate.Slide_Item {
	switch value in item {
	case restate.Text_Item:
		return restate.Slide_Item(restate.Text_Item {
			text = strings.clone(value.text, allocator),
			style = value.style,
			overrides = value.overrides,
		})
	}
	panic("unknown slide item type")
}

clone_slide :: proc(slide: restate.Slide, allocator: mem.Allocator) -> restate.Slide {
	items := make([dynamic]restate.Slide_Item, 0, len(slide.items), allocator)
	for item in slide.items {
		append(&items, clone_slide_item(item, allocator))
	}
	return restate.Slide {
		title = strings.clone(slide.title, allocator),
		items = items,
	}
}

clone_slides :: proc(slides: []restate.Slide, allocator: mem.Allocator) -> [dynamic]restate.Slide {
	result := make([dynamic]restate.Slide, 0, len(slides), allocator)
	for slide in slides {
		append(&result, clone_slide(slide, allocator))
	}
	return result
}

handle_value :: proc(parsed: ^Parsed_State, L: ^lua.State, key: cstring, index: i32, allocator: mem.Allocator) {
	switch key {
	case "index":
		if (lua.istable(L, index)) {
			parsed.slides = handle_index(L, index, allocator)
			parsed.has_index = true
		} else {
			lua.L_error(
				L,
				"configuration keys type is not the right one, got %s",
				lua.L_typename(L, -1),
			)
		}
	case "style":
		parsed.style = handle_style(L, index)
		parsed.has_style = true
	case:
		// Future top-level sections such as config can be added without breaking slide parsing.
	}
}

update_state :: proc "c" (L: ^lua.State) -> i32 {
	context = lua_ctx
	user_data := cast(^User_Data)lua.touserdata(L, lua.REGISTRYINDEX - 1)

	lua.L_checktype(L, 1, i32(lua.TTABLE));
	table_index := lua.absindex(L, 1)
	// Keep all allocations made while parsing separate from the published
	// document. This memory is discarded on the next update, including after
	// a Lua error, without affecting the last valid render state.
	free_all(context.temp_allocator)
	parsed := Parsed_State { style = restate.default_style() }

	lua.pushnil(L)

	for lua.next(L, table_index) != 0 {

		key := lua.tostring(L, -2)
		if (lua.type(L, -2) != lua.TSTRING) {
			lua.L_error(
				L,
				"configuration keys must be strings, got %s",
				lua.L_typename(L, -2),
			)
		}

		handle_value(&parsed, L, key, -1, context.temp_allocator)

		lua.pop(L, 1) /* Pop value, retain key. */

	}

	// The Lua table has been fully parsed and validated. Clone the temporary
	// document before publishing it, then swap all requested fields together.
	allocator := mem.arena_allocator(user_data.render_state.arena)
	slides: [dynamic]restate.Slide
	sync.mutex_lock(&user_data.render_state.mutex)
	if parsed.has_index {
		// Published slides live in this arena. The mutex keeps the renderer
		// from reading the old arena contents while they are discarded.
		mem.arena_free_all(user_data.render_state.arena)
		slides = clone_slides(parsed.slides[:], allocator)
		user_data.render_state.slides = slides
	}
	if parsed.has_style {
		user_data.render_state.style = parsed.style
	}
	sync.mutex_unlock(&user_data.render_state.mutex)

	return 0
}

eval_script :: proc(L: ^lua.State, path: string) {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.println("failed to read", path)
		return
	}
	defer delete(data)

	c_script := strings.clone_to_cstring(string(data))
	defer delete(c_script)

	if lua.L_dostring(L, c_script) != 0 {
		fmt.println("lua error:", lua.tostring(L, -1))
		lua.pop(L, 1)
	}
}
