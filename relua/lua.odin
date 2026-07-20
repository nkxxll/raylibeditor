package relua

import lua "vendor:lua/5.4"
import "base:runtime"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:sync"
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
	lua.setglobal(L, "update_state")

	lua.L_openlibs(L)
	return L
}

handle_text_slide_item :: proc(L: ^lua.State, absolute_item_index: i32, allocator := context.allocator) -> restate.Text_Item {
	lua.getfield(L, absolute_item_index, "value")
	text := lua.L_checkstring(L, -1)
	lua.pop(L, 1)

	return restate.Text_Item { text = strings.clone(string(text), allocator) }
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

handle_index :: proc(user_data: ^User_Data, L: ^lua.State, index: i32) {
	list_index := lua.absindex(L, index)
	allocator := user_data.render_state.allocator
	slides := make([dynamic]restate.Slide, 0, 16, allocator)
	
	for i in 1..=lua.rawlen(L, list_index) {
		lua.geti(L, list_index, lua.Integer(i))
		if !lua.istable(L, -1) {
			lua.L_error(L, "slide values must be tables, got %s", lua.L_typename(L, -1))
		}

		append(&slides, handle_slide(L, -1, allocator))
		lua.pop(L, 1)
	}

	sync.mutex_lock(&user_data.render_state.mutex)
	user_data.render_state.slides = slides
	sync.mutex_unlock(&user_data.render_state.mutex)
}

handle_value :: proc(user_data: ^User_Data, L: ^lua.State, key: cstring, index: i32) {
	switch key {
	case "index":
		if (lua.istable(L, index)) {
			handle_index(user_data, L, index)
		} else {
			lua.L_error(
				L,
				"configuration keys type is not the right one, got %s",
				lua.L_typename(L, -1),
			)
		}
	case:
		// Future top-level sections such as config can be added without breaking slide parsing.
	}
}

update_state :: proc "c" (L: ^lua.State) -> i32 {
	context = lua_ctx
	user_data := cast(^User_Data)lua.touserdata(L, lua.REGISTRYINDEX - 1)

	lua.L_checktype(L, 1, i32(lua.TTABLE));
	table_index := lua.absindex(L, 1)

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

		handle_value(user_data, L, key, -1)

		lua.pop(L, 1) /* Pop value, retain key. */

	}

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
