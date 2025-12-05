module main

import os
import time

fn get_system_info() SystemInfo {
	platform := detect_platform()
	
	hostname := os.hostname() or { 'unknown' }
	uptime := read_uptime(platform)
	load_avg := read_load_average(platform)
	
	mut num_processes := 0
	mut num_running := 0
	mut num_sleeping := 0
	mut num_stopped := 0
	mut num_zombie := 0
	
	if platform == .linux {
		proc_dirs := os.ls('/proc') or { []string{} }
		for dir in proc_dirs {
			if dir.len > 0 && dir[0].is_digit() {
				num_processes++
				state := read_process_state_linux(dir.int())
				match state {
					'R' { num_running++ }
					'S', 'D' { num_sleeping++ }
					'T' { num_stopped++ }
					'Z' { num_zombie++ }
					else {}
				}
			}
		}
	} else if platform == .freebsd {
		// Use ps command for FreeBSD
		result := os.execute('ps -ax -o state')
		if result.exit_code == 0 {
			lines := result.output.split('\n')
			for line in lines[1..] {
				if line.len > 0 {
					num_processes++
					state := line.trim_space()
					if state.len > 0 {
						first_char := state[0].ascii_str()
						match first_char {
							'R' { num_running++ }
							'S', 'D', 'I' { num_sleeping++ }
							'T' { num_stopped++ }
							'Z' { num_zombie++ }
							else {}
						}
					}
				}
			}
		}
	}
	
	return SystemInfo{
		hostname: hostname
		uptime: uptime
		load_avg: load_avg
		num_processes: num_processes
		num_running: num_running
		num_sleeping: num_sleeping
		num_stopped: num_stopped
		num_zombie: num_zombie
	}
}

fn read_uptime(platform Platform) u64 {
	if platform == .linux {
		content := os.read_file('/proc/uptime') or { return 0 }
		parts := content.split(' ')
		if parts.len > 0 {
			return u64(parts[0].f64())
		}
	} else if platform == .freebsd {
		result := os.execute('sysctl -n kern.boottime')
		if result.exit_code == 0 {
			// Parse: { sec = 1234567890, usec = 0 }
			output := result.output
			if output.contains('sec =') {
				sec_start := output.index('sec = ') or { return 0 }
				sec_str := output[sec_start + 6..].split(',')[0].trim_space()
				boot_time := sec_str.u64()
				current_time := u64(time.now().unix())
				return current_time - boot_time
			}
		}
	}
	return 0
}

fn read_load_average(platform Platform) LoadAvg {
	if platform == .linux {
		content := os.read_file('/proc/loadavg') or { return LoadAvg{} }
		parts := content.split(' ')
		if parts.len >= 3 {
			return LoadAvg{
				one_min: parts[0].f64()
				five_min: parts[1].f64()
				fifteen_min: parts[2].f64()
			}
		}
	} else if platform == .freebsd {
		result := os.execute('sysctl -n vm.loadavg')
		if result.exit_code == 0 {
			// Parse: { 0.50 0.75 0.66 }
			output := result.output.replace('{', '').replace('}', '').trim_space()
			parts := output.split(' ')
			if parts.len >= 3 {
				return LoadAvg{
					one_min: parts[0].f64()
					five_min: parts[1].f64()
					fifteen_min: parts[2].f64()
				}
			}
		}
	}
	return LoadAvg{}
}

fn read_process_state_linux(pid int) string {
	stat_file := '/proc/${pid}/stat'
	content := os.read_file(stat_file) or { return '' }
	
	start := content.index(')') or { return '' }
	if start + 2 < content.len {
		return content[start + 2..start + 3]
	}
	return ''
}