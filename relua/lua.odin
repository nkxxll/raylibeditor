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
	L := lua.L_newstate()
	if L == nil {
		panic("ah no lua state")
	}

	lua.pushlightuserdata(L, user_data)

	// @todo we can modularize this so that we can push automatically a
	// centrally defined list of functions with names to the lua functions
	lua.pushcclosure(L, lua_my_func, 1)
	lua.setglobal(L, "odin_print")

	lua.L_openlibs(L)
	return L
}

lua_my_func :: proc "c" (L: ^lua.State) -> i32 {
	context = lua_ctx
	user_data := cast(^User_Data)lua.touserdata(L, lua.REGISTRYINDEX - 1)

	sync.mutex_lock(&user_data.render_state.mutex)
	user_data.render_state.counter += 1
	sync.mutex_unlock(&user_data.render_state.mutex)

	fmt.println("hello odin", user_data.render_state.counter)
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
