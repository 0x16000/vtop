module main

import os

fn get_processes() []Process {
	platform := detect_platform()
	
	if platform == .linux {
		return get_processes_linux()
	} else if platform == .freebsd {
		return get_processes_freebsd()
	}
	
	return []Process{}
}

fn get_processes_linux() []Process {
	mut processes := []Process{}
	
	proc_dirs := os.ls('/proc') or { return processes }
	
	for dir in proc_dirs {
		if dir.len > 0 && dir[0].is_digit() {
			pid := dir.int()
			process := read_process_info_linux(pid)
			if process.pid > 0 {
				processes << process
			}
		}
	}
	
	return processes
}

fn get_processes_freebsd() []Process {
	mut processes := []Process{}
	result := os.execute('ps -ax -o pid,user,pri,nice,vsz,rss,state,pcpu,pmem,time,command')
	if result.exit_code != 0 {
		return processes
	}
	
	lines := result.output.split('\n')
	
	for i, line in lines {
		if i == 0 || line.trim_space().len == 0 {
			continue
		}
		
		process := parse_ps_line_freebsd(line)
		if process.pid > 0 {
			processes << process
		}
	}
	
	return processes
}

fn parse_ps_line_freebsd(line string) Process {
	parts := line.split_any(' \t')
	mut values := []string{}
	
	for part in parts {
		if part.len > 0 {
			values << part
		}
	}
	
	if values.len < 11 {
		return Process{}
	}
	
	pid := values[0].int()
	user := values[1]
	priority := values[2].int()
	nice := values[3].int()
	virt_mem := values[4].u64() // VSZ in KB
	res_mem := values[5].u64()  // RSS in KB
	state := values[6]
	cpu_percent := values[7].f64()
	mem_percent := values[8].f64()
	time_str := values[9]
	
	mut command := ''
	for i := 10; i < values.len; i++ {
		command += values[i] + ' '
	}
	command = command.trim_space()
	
	return Process{
		pid: pid
		user: user
		priority: priority
		nice: nice
		virt_mem: virt_mem
		res_mem: res_mem
		shr_mem: 0 // FreeBSD ps doesn't provide shared mem easily
		state: state
		cpu_percent: cpu_percent
		mem_percent: mem_percent
		time_plus: time_str
		command: command
	}
}

fn read_process_info_linux(pid int) Process {
	stat_file := '/proc/${pid}/stat'
	status_file := '/proc/${pid}/status'
	
	stat_content := os.read_file(stat_file) or { return Process{} }
	status_content := os.read_file(status_file) or { return Process{} }
	
	stat_parts := parse_stat_file(stat_content)
	if stat_parts.len < 20 {
		return Process{}
	}
	
	user := get_process_user_linux(pid)
	command := get_process_command_linux(pid)
	
	utime := stat_parts[11].u64()
	stime := stat_parts[12].u64()
	total_time := utime + stime
	
	virt_mem, res_mem, shr_mem := parse_status_file(status_content)
	
	mem_info := get_memory_info()
	mem_percent := if mem_info.total_mem > 0 {
		f64(res_mem) / f64(mem_info.total_mem) * 100.0
	} else {
		0.0
	}
	
	return Process{
		pid: pid
		user: user
		priority: stat_parts[15].int()
		nice: stat_parts[16].int()
		virt_mem: virt_mem
		res_mem: res_mem
		shr_mem: shr_mem
		state: stat_parts[0]
		cpu_percent: f64(total_time) / 100.0
		mem_percent: mem_percent
		time_plus: format_time(total_time / 100)
		command: command
	}
}

fn parse_stat_file(content string) []string {
	end_cmd := content.last_index(')') or { return []string{} }
	
	if end_cmd + 2 >= content.len {
		return []string{}
	}
	
	after_cmd := content[end_cmd + 2..].trim_space()
	parts := after_cmd.split_any(' \t')
	
	mut result := []string{}
	for part in parts {
		if part.len > 0 {
			result << part
		}
	}
	
	return result
}

fn parse_status_file(content string) (u64, u64, u64) {
	mut virt_mem := u64(0)
	mut res_mem := u64(0)
	mut shr_mem := u64(0)
	
	lines := content.split('\n')
	for line in lines {
		if line.starts_with('VmSize:') {
			virt_mem = parse_mem_line(line)
		} else if line.starts_with('VmRSS:') {
			res_mem = parse_mem_line(line)
		} else if line.starts_with('RssFile:') {
			shr_mem = parse_mem_line(line)
		}
	}
	
	return virt_mem, res_mem, shr_mem
}

fn get_process_user_linux(pid int) string {
	status_file := '/proc/${pid}/status'
	content := os.read_file(status_file) or { return 'unknown' }
	
	lines := content.split('\n')
	for line in lines {
		if line.starts_with('Uid:') {
			parts := line.split_any(' \t')
			for part in parts {
				if part.len > 0 && part[0].is_digit() {
					uid := part.int()
					return get_username_from_uid(uid)
				}
			}
		}
	}
	
	return 'unknown'
}

fn get_username_from_uid(uid int) string {
	passwd_content := os.read_file('/etc/passwd') or { return uid.str() }
	
	lines := passwd_content.split('\n')
	for line in lines {
		parts := line.split(':')
		if parts.len >= 3 {
			if parts[2].int() == uid {
				return parts[0]
			}
		}
	}
	
	return uid.str()
}

fn get_process_command_linux(pid int) string {
	cmdline_file := '/proc/${pid}/cmdline'
	content := os.read_file(cmdline_file) or { return '' }
	
	mut cmd := ''
	for ch in content {
		if ch == 0 {
			cmd += ' '
		} else {
			cmd += ch.ascii_str()
		}
	}
	
	cmd = cmd.trim_space()
	if cmd.len == 0 {
		comm_file := '/proc/${pid}/comm'
		cmd = os.read_file(comm_file) or { return 'unknown' }
		cmd = cmd.trim_space()
	}
	
	return cmd
}

fn format_time(seconds u64) string {
	minutes := seconds / 60
	secs := int(seconds % 60)
	if minutes >= 60 {
		hours := minutes / 60
		mins := int(minutes % 60)
		return '${hours}:${mins:02d}:${secs:02d}'
	}
	mins := int(minutes)
	return '${mins}:${secs:02d}'
}