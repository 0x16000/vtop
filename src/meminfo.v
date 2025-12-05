module main

import os

fn get_memory_info() MemoryInfo {
	platform := detect_platform()
	
	if platform == .linux {
		return get_memory_info_linux()
	} else if platform == .freebsd {
		return get_memory_info_freebsd()
	}
	
	return MemoryInfo{}
}

fn get_memory_info_linux() MemoryInfo {
	content := os.read_file('/proc/meminfo') or { return MemoryInfo{} }
	
	mut mem_info := MemoryInfo{}
	
	lines := content.split('\n')
	for line in lines {
		if line.starts_with('MemTotal:') {
			mem_info.total_mem = parse_mem_line(line)
		} else if line.starts_with('MemFree:') {
			mem_info.free_mem = parse_mem_line(line)
		} else if line.starts_with('MemAvailable:') {
			mem_info.available_mem = parse_mem_line(line)
		} else if line.starts_with('Buffers:') {
			mem_info.buffers = parse_mem_line(line)
		} else if line.starts_with('Cached:') {
			mem_info.cached = parse_mem_line(line)
		} else if line.starts_with('SwapTotal:') {
			mem_info.swap_total = parse_mem_line(line)
		} else if line.starts_with('SwapFree:') {
			mem_info.swap_free = parse_mem_line(line)
		}
	}
	
	return mem_info
}

fn get_memory_info_freebsd() MemoryInfo {
	mut mem_info := MemoryInfo{}
	
	pagesize_result := os.execute('sysctl -n hw.pagesize')
	pagesize := if pagesize_result.exit_code == 0 {
		pagesize_result.output.trim_space().u64()
	} else {
		u64(4096)
	}
	
	physmem_result := os.execute('sysctl -n hw.physmem')
	if physmem_result.exit_code == 0 {
		bytes := physmem_result.output.trim_space().u64()
		mem_info.total_mem = bytes / 1024 // Convert to KB
	}
	
	free_result := os.execute('sysctl -n vm.stats.vm.v_free_count')
	if free_result.exit_code == 0 {
		pages := free_result.output.trim_space().u64()
		mem_info.free_mem = (pages * pagesize) / 1024 // Convert to KB
	}
	
	inactive_result := os.execute('sysctl -n vm.stats.vm.v_inactive_count')
	if inactive_result.exit_code == 0 {
		pages := inactive_result.output.trim_space().u64()
		mem_info.cached = (pages * pagesize) / 1024
	}
	
	cache_result := os.execute('sysctl -n vm.stats.vm.v_cache_count')
	if cache_result.exit_code == 0 {
		pages := cache_result.output.trim_space().u64()
		mem_info.buffers = (pages * pagesize) / 1024
	}
	
	mem_info.available_mem = mem_info.free_mem + mem_info.cached + mem_info.buffers
	
	swap_result := os.execute('swapinfo -k')
	if swap_result.exit_code == 0 {
		lines := swap_result.output.split('\n')
		for line in lines {
			if line.starts_with('/dev/') || line.contains('Device') {
				continue
			}
			if line.len > 0 && !line.starts_with('Total') {
				parts := line.split_any(' \t')
				mut values := []string{}
				for part in parts {
					if part.len > 0 {
						values << part
					}
				}
				if values.len >= 2 {
					mem_info.swap_total = values[1].u64()
					if values.len >= 3 {
						mem_info.swap_free = mem_info.swap_total - values[2].u64()
					}
				}
			}
		}
	}
	
	return mem_info
}

fn parse_mem_line(line string) u64 {
	parts := line.split_any(' \t')
	for part in parts {
		if part.len > 0 && part[0].is_digit() {
			return u64(part.u64())
		}
	}
	return 0
}