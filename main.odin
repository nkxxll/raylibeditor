package main

import lua "vendor:lua/5.4"
import "core:fmt"
import "core:os"
import "core:sys/linux"
import "core:time"
import "relua"

Event_Loop_Context :: struct {
	L: ^lua.State
}
start_event_loop :: proc(event_loop_context: ^Event_Loop_Context) {
	when ODIN_OS == .Linux {
		fd, errno := linux.inotify_init()
		if errno != .NONE {
			panic("setting up inotify_init1 did not work")
		}
		defer linux.close(fd)

		wd, watch_errno := linux.inotify_add_watch(
			fd,
			"script.lua",
			linux.Inotify_Event_Mask{.MODIFY},
		)
		if watch_errno != .NONE || wd < 0 {
			panic("setting up inotify watch for script.lua did not work")
		}

		relua.eval_script(event_loop_context.L, "script.lua")

		event_buf: [4096]u8
		for {
			fmt.println("event loop start")
			// this constantly reads this is not good we need poll here
			n, err := linux.read(fd, event_buf[:])
			if n > 0 {
				fmt.println("script.lua changed; re-evaluating")
				relua.eval_script(event_loop_context.L, "script.lua")
			} else if err != nil {
				fmt.println("inotify read error:", err)
			}
			fmt.println("event loop end")
		}
	} else when ODIN_OS == .Darwin {
		#assert(false, "have to implement darwin next")
	} else when ODIN_OS == .Windows {
		#assert(false, "what are you doing with your life")
	}
}

main :: proc() {
	L := relua.state_init()
	defer lua.close(L)

	event_loop_context := Event_Loop_Context { 
		L = L
	}

	start_event_loop(&event_loop_context)
}
// vim: set ts=4:
