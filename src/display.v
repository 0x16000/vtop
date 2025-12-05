module main

import term

fn display_header(sys_info SystemInfo, mem_info MemoryInfo, cpu_info CpuInfo) {
	term_width, _ := term.get_terminal_size()
	
	draw_line(term_width, '═')
	
	uptime_str := format_uptime(sys_info.uptime)
	load_str := 'Load: ${sys_info.load_avg.one_min:.2f}, ${sys_info.load_avg.five_min:.2f}, ${sys_info.load_avg.fifteen_min:.2f}'
	title_line := '  VTOP - ${sys_info.hostname}     Uptime: ${uptime_str}     ${load_str}'
	println(title_line)
	
	draw_line(term_width, '─')
	
	println('  Tasks: ${sys_info.num_processes} total  |  ${sys_info.num_running} running  |  ${sys_info.num_sleeping} sleeping  |  ${sys_info.num_stopped} stopped  |  ${sys_info.num_zombie} zombie')
	
	cpu_used := 100.0 - cpu_info.idle
	println('  CPU (${cpu_info.num_cores} cores): ${cpu_used:5.1f}% user  |  ${cpu_info.system:5.1f}% sys  |  ${cpu_info.idle:5.1f}% idle  |  ${cpu_info.iowait:5.1f}% wait')
	print('  ')
	draw_bar(cpu_used, 60, '█', '░')
	
	mem_used := mem_info.total_mem - mem_info.free_mem - mem_info.buffers - mem_info.cached
	mem_total_gb := f64(mem_info.total_mem) / 1048576.0
	mem_used_gb := f64(mem_used) / 1048576.0
	mem_free_gb := f64(mem_info.free_mem) / 1048576.0
	mem_percent := (f64(mem_used) / f64(mem_info.total_mem)) * 100.0
	
	println('  Memory: ${mem_used_gb:5.2f}/${mem_total_gb:5.2f} GiB used  |  ${mem_free_gb:5.2f} GiB free  |  ${mem_percent:5.1f}% used')
	print('  ')
	draw_bar(mem_percent, 60, '█', '░')
	
	swap_used := mem_info.swap_total - mem_info.swap_free
	swap_total_gb := f64(mem_info.swap_total) / 1048576.0
	swap_used_gb := f64(swap_used) / 1048576.0
	swap_percent := if mem_info.swap_total > 0 {
		(f64(swap_used) / f64(mem_info.swap_total)) * 100.0
	} else {
		0.0
	}
	
	if swap_total_gb > 0.0 {
		println('  Swap: ${swap_used_gb:5.2f}/${swap_total_gb:5.2f} GiB used  |  ${swap_percent:5.1f}% used')
		print('  ')
		draw_bar(swap_percent, 60, '█', '░')
	}
	
	draw_line(term_width, '═')
	
	println('   PID USER        PR  NI    VIRT    RES    SHR S  %CPU  %MEM    TIME+ COMMAND')
	draw_line(term_width, '─')
}

fn display_processes(processes []Process) {
	_, term_height := term.get_terminal_size()
	
	max_procs := max(0, term_height - 16)
	
	for i, proc in processes {
		if i >= max_procs {
			break
		}
		
		println('${proc.pid:6d} ${lpad(proc.user, 8)} ${proc.priority:4d} ${proc.nice:3d} ${rpad(format_mem(proc.virt_mem), 7)} ${rpad(format_mem(proc.res_mem), 7)} ${rpad(format_mem(proc.shr_mem), 7)} ${proc.state} ${proc.cpu_percent:5.1f} ${proc.mem_percent:5.1f} ${rpad(proc.time_plus, 9)} ${truncate_command(proc.command, 40)}')
	}
}

fn draw_line(width int, ch string) {
	println(ch.repeat(width))
}

fn draw_bar(percent f64, width int, filled_ch string, empty_ch string) {
	mut filled := int((percent / 100.0) * f64(width))
	if filled > width {
		filled = width
	}
	empty := width - filled
	bar := filled_ch.repeat(filled) + empty_ch.repeat(empty)
	println('[${bar}] ${percent:5.1f}%')
}

fn format_uptime(seconds u64) string {
	hours := seconds / 3600
	minutes := (seconds % 3600) / 60
	
	if hours > 24 {
		days := hours / 24
		hrs := hours % 24
		mins := int(minutes)
		return '${days}d ${hrs}h ${mins}m'
	}
	hrs := int(hours)
	mins := int(minutes)
	return '${hrs}h ${mins}m'
}

fn format_mem(kb u64) string {
	if kb >= 1048576 {
		return '${kb / 1048576}g'
	} else if kb >= 1024 {
		return '${kb / 1024}m'
	}
	return '${kb}k'
}

fn truncate_command(cmd string, max_len int) string {
	if cmd.len <= max_len {
		return cmd
	}
	return cmd[..max_len - 3] + '...'
}

fn max(a int, b int) int {
	return if a > b { a } else { b }
}

fn rpad(s string, width int) string {
	if s.len >= width {
		return s
	}
	return ' '.repeat(width - s.len) + s
}

fn lpad(s string, width int) string {
	if s.len >= width {
		return s[..width]
	}
	return s + ' '.repeat(width - s.len)
}