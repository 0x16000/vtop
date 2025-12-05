module main

struct SystemInfo {
	hostname string
	uptime u64
	load_avg LoadAvg
	num_processes int
	num_running int
	num_sleeping int
	num_stopped int
	num_zombie int
}

struct LoadAvg {
	one_min f64
	five_min f64
	fifteen_min f64
}

struct MemoryInfo {
mut:
	total_mem u64
	free_mem u64
	available_mem u64
	buffers u64
	cached u64
	swap_total u64
	swap_free u64
}

struct CpuInfo {
	user f64
	system f64
	idle f64
	iowait f64
	num_cores int
}

struct Process {
	pid int
	user string
	priority int
	nice int
	virt_mem u64
	res_mem u64
	shr_mem u64
	state string
	cpu_percent f64
	mem_percent f64
	time_plus string
	command string
}