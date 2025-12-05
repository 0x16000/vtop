module main

import time
import term

#flag linux -include termios.h
#flag linux -include unistd.h
#flag linux -include sys/select.h
#flag linux -include sys/time.h

fn C.tcgetattr(int, voidptr) int
fn C.tcsetattr(int, int, voidptr) int
fn C.read(int, voidptr, usize) int
fn C.FD_ZERO(voidptr)
fn C.FD_SET(int, voidptr)
fn C.select(int, voidptr, voidptr, voidptr, voidptr) int

struct C.termios {
mut:
	c_iflag u32
	c_oflag u32
	c_cflag u32
	c_lflag u32
	c_line  u8
	c_cc    [32]u8
}

__global (
	original_termios C.termios
	termios_saved = false
)

const refresh_rate = 2 * time.second

fn main() {
	term.clear()
	print('\x1b[?25l')
	defer {
		print('\x1b[?25h')
		restore_terminal()
	}
	setup_terminal()

	mut exit_requested := false

	for !exit_requested {
		term.set_cursor_position(term.Coord{1,1})

		sys_info := get_system_info()
		mem_info := get_memory_info()
		cpu_info := get_cpu_info()
		mut procs := get_processes()

		procs.sort(a.cpu_percent > b.cpu_percent)

		display_header(sys_info, mem_info, cpu_info)
		display_processes(procs)

		if check_quit_key() {
			exit_requested = true
			break
		}

		time.sleep(refresh_rate)
	}

	term.clear()
}

fn setup_terminal() {
	C.tcgetattr(0, &original_termios)
	termios_saved = true

	mut raw := original_termios
	raw.c_lflag &= ~u32(2 | 8)
	raw.c_cc[6] = 0
	raw.c_cc[5] = 0
	C.tcsetattr(0, 0, &raw)
}

fn restore_terminal() {
	if termios_saved {
		C.tcsetattr(0, 0, &original_termios)
	}
}

fn check_quit_key() bool {
	mut buf := [1]u8{}
	mut readfds := C.fd_set{}

	unsafe {
		C.FD_ZERO(&readfds)
		C.FD_SET(0, &readfds)

		mut tv := C.timeval{
			tv_sec: 0
			tv_usec: 0
		}

		res := C.select(1, &readfds, C.NULL, C.NULL, &tv)
		if res > 0 {
			n := C.read(0, &buf[0], 1)
			if n > 0 {
				return buf[0] == `q` || buf[0] == `Q`
			}
		}
	}
	return false
}