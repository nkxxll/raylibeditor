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
	lua.pushcclosure(L, update_state, 1)
	lua.setglobal(L, "update_state")

	lua.L_openlibs(L)
	return L
}

update_state :: proc "c" (L: ^lua.State) -> i32 {
	context = lua_ctx
	user_data := cast(^User_Data)lua.touserdata(L, lua.REGISTRYINDEX - 1)

	lua.L_checktype(L, 1, i32(lua.TTABLE));
	table_index := lua.absindex(L, 1)

	lua.pushnil(L)

	lua.next(L, table_index)

	key := lua.tostring(L, -2);


	// int table_index = lua_upvalueindex(1);
	//
	//    luaL_checktype(L, table_index, LUA_TTABLE);
	//
	//    lua_pushnil(L);
	//
	//    while (lua_next(L, table_index) != 0) {
	//        /* key is at -2, value is at -1 */
	//
	//        printf("key type: %s, value type: %s\n",
	//               luaL_typename(L, -2),
	//               luaL_typename(L, -1));
	//
	//        lua_pop(L, 1); /* Pop value, retain key. */
	//    }
	//
	//    return 0;

	sync.mutex_lock(&user_data.render_state.mutex)
	user_data.render_state.slides = string(key)
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
