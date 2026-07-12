package main

import lua "vendor:lua/5.4"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:sys/linux"
import "core:sys/kqueue"
import "core:sys/posix"
import "core:time"
import "relua"
import "restate"
import "reray"
import "core:sync/chan"
import "core:thread"

Event_Loop_Context :: struct {
	L: ^lua.State
}
start_event_loop :: proc(event_loop_context: ^Event_Loop_Context) {
	when ODIN_OS == .Linux {
		fd, errno := linux.inotify_init()
		if errno != .NONE {
			panic("setting up inotify_init1 did not work")
		}
		defer posix.close(posix.FD(fd))

		wd, watch_errno := linux.inotify_add_watch(
			fd,
			"script.lua",
			linux.Inotify_Event_Mask{.MODIFY},
		)
		if watch_errno != .NONE || wd < 0 {
			panic("setting up inotify watch for script.lua did not work")
		}

		relua.eval_script(event_loop_context.L, "script.lua")

		EVENT_BUF_SIZE :: 4096
		event_buf: [EVENT_BUF_SIZE]u8
		for {
			fmt.println("event loop start")
			// this constantly reads this is not good we need poll here
			n := posix.read(posix.FD(fd), raw_data(event_buf[:]), EVENT_BUF_SIZE)
			if n > 0 {
				fmt.println("script.lua changed; re-evaluating")
				relua.eval_script(event_loop_context.L, "script.lua")
			} else {
				fmt.println("inotify read error")
			}
			fmt.println("event loop end")
		}
	} else when ODIN_OS == .Darwin {
		fd := posix.open("script.lua", {})
		defer posix.close(fd)
		if fd == -1 {
			panic("fuck this is not good fd -1")
		}

		queue, err := kqueue.kqueue()
		if err != nil {
			panic("handle the error here with grace kqeue out")
		}
		defer posix.close(queue)

		change := kqueue.KEvent {
			ident  = uintptr(fd),
			filter = .VNode,
			flags  = {.Add, .Clear},
		}

		change.fflags.vnode = {.Write}

		changes := [?]kqueue.KEvent{change}

		_, err = kqueue.kevent(queue, changes[:], nil, nil)
		if err != nil {
			panic("ahhhhhh ahhhhh aaaaahhhhh kevent does not work")
		}

		events: [1]kqueue.KEvent
		for {
			fmt.println("event loop start")
			n, err := kqueue.kevent(queue, nil, events[:], nil)
			if err != nil {
				fmt.println("kqueue read error:", err)
			} else if n > 0 {
				fmt.println("script.lua changed; re-evaluating")
				relua.eval_script(event_loop_context.L, "script.lua")
			}
			fmt.println("event loop end")
		}
	} else when ODIN_OS == .Windows {
		#assert(false, "what are you doing with your life")
	}
}

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

	render_messages, channel_err := chan.create(restate.Rendering_Message_Channel, 64, context.allocator)
	if channel_err != .None {
		panic("failed to create render message channel")
	}
	defer chan.destroy(render_messages)

	user_data_state := restate.User_Data_State {
		counter = 0,
		render_messages = render_messages,
	}

	ray_state := reray.init(800, 800, render_messages)
	_ = thread.create_and_start_with_data(&ray_state, reray.run)


	L := relua.state_init(&user_data_state)
	defer lua.close(L)

	event_loop_context := Event_Loop_Context { 
		L = L
	}

	start_event_loop(&event_loop_context)
}
// vim: set ts=4:
