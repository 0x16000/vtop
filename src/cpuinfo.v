module main

import os

struct CpuStat {
	user u64
	nice u64
	system u64
	idle u64
	iowait u64
	irq u64
	softirq u64
}

fn get_cpu_info() CpuInfo {
	platform := detect_platform()
	
	if platform == .linux {
		return get_cpu_info_linux()
	} else if platform == .freebsd {
		return get_cpu_info_freebsd()
	}
	
	return CpuInfo{}
}

fn get_cpu_info_linux() CpuInfo {
	content := os.read_file('/proc/stat') or { return CpuInfo{} }
	
	mut num_cores := 0
	lines := content.split('\n')
	for line in lines {
		if line.starts_with('cpu') && !line.starts_with('cpu ') {
			num_cores++
		}
	}
	
	for line in lines {
		if line.starts_with('cpu ') {
			stat := parse_cpu_line(line)
			total := stat.user + stat.nice + stat.system + stat.idle + 
			        stat.iowait + stat.irq + stat.softirq
			if total > 0 {
				return CpuInfo{
					user: f64(stat.user) / f64(total) * 100.0
					system: f64(stat.system) / f64(total) * 100.0
					idle: f64(stat.idle) / f64(total) * 100.0
					iowait: f64(stat.iowait) / f64(total) * 100.0
					num_cores: num_cores
				}
			}
		}
	}
	
	return CpuInfo{num_cores: num_cores}
}

fn get_cpu_info_freebsd() CpuInfo {
	mut num_cores := 0
	
	ncpu_result := os.execute('sysctl -n hw.ncpu')
	if ncpu_result.exit_code == 0 {
		num_cores = ncpu_result.output.trim_space().int()
	}
	
	user_result := os.execute('sysctl -n kern.cp_time')
	if user_result.exit_code == 0 {
		output := user_result.output.replace('{', '').replace('}', '').trim_space()
		parts := output.split_any(' ,\t')
		
		mut values := []u64{}
		for part in parts {
			trimmed := part.trim_space()
			if trimmed.len > 0 && trimmed[0].is_digit() {
				values << trimmed.u64()
			}
		}
		
		if values.len >= 5 {
			user := values[0]
			nice := values[1]
			system := values[2]
			interrupt := values[3]
			idle := values[4]
			
			total := user + nice + system + interrupt + idle
			
			if total > 0 {
				return CpuInfo{
					user: f64(user + nice) / f64(total) * 100.0
					system: f64(system + interrupt) / f64(total) * 100.0
					idle: f64(idle) / f64(total) * 100.0
					iowait: 0.0 // FreeBSD doesn't track iowait separately
					num_cores: num_cores
				}
			}
		}
	}
	
	return CpuInfo{num_cores: num_cores}
}

fn parse_cpu_line(line string) CpuStat {
	parts := line.split_any(' \t')
	mut values := []u64{}
	
	for part in parts {
		if part.len > 0 && part[0].is_digit() {
			values << part.u64()
		}
	}
	
	if values.len >= 7 {
		return CpuStat{
			user: values[0]
			nice: values[1]
			system: values[2]
			idle: values[3]
			iowait: values[4]
			irq: values[5]
			softirq: values[6]
		}
	}
	
	return CpuStat{}
}