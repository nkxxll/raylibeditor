package main

import lua "vendor:lua/5.4"
import "core:fmt"
import "base:runtime"
import "core:os"
import "core:strings"

lua_ctx: runtime.Context

User_Data :: struct {
	counter: int
}

lua_my_func :: proc "c" (L: ^lua.State) -> i32 {
	context = lua_ctx
	user_data := cast(^User_Data)lua.touserdata(L, lua.REGISTRYINDEX - 1)
	user_data.counter += 1;

	fmt.println("hello odin", user_data.counter)
	return 0
}

main :: proc() {
	L := lua.L_newstate()
	if L == nil {
		panic("ah no lua state")
	}
	defer lua.close(L)

	user_data := cast(^User_Data)lua.newuserdata(L, size_of(User_Data))
	user_data^ = User_Data{ 0 }

	lua.pushcclosure(L, lua_my_func, 1)
	lua.setglobal(L, "odin_print")

	lua.L_openlibs(L)

	data, err := os.read_entire_file("script.lua", context.allocator)
	if err != nil {
		fmt.println("Failed to read file")
		return
	}
	defer delete(data)

	script_text := string(data)
	c_script := strings.clone_to_cstring(script_text)

	if lua.L_dostring(L, c_script) != 0 {
		fmt.println("lua error:", lua.tostring(L, -1))
	}
}
// vim: set ts=4:
