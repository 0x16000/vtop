module main

import time
import term

const refresh_rate = 2 * time.second

fn main() {
	term.clear()
	print('\x1b[?25l')
	
	defer {
		print('\x1b[?25h')
	}
	
	mut should_exit := false
	
	for !should_exit {
		term.set_cursor_position(term.Coord{x: 1, y: 1})
		
		system_info := get_system_info()
		mem_info := get_memory_info()
		cpu_info := get_cpu_info()
		mut processes := get_processes()
		
		processes.sort(a.cpu_percent > b.cpu_percent)
		
		display_header(system_info, mem_info, cpu_info)
		display_processes(processes)
		
		if check_quit_key() {
			should_exit = true
			break
		}
		
		time.sleep(refresh_rate)
	}
	
	term.clear()
}

fn check_quit_key() bool {
	// Non-blocking key check - just return false for now
	// V's term module doesn't have non-blocking read_char
	return false
}