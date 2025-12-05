module main

enum Platform {
	linux
	freebsd
	unknown
}

fn detect_platform() Platform {
	$if linux {
		return .linux
	} $else $if freebsd {
		return .freebsd
	} $else {
		return .unknown
	}
}

fn get_platform_name() string {
	platform := detect_platform()
	match platform {
		.linux { return 'Linux' }
		.freebsd { return 'FreeBSD' }
		.unknown { return 'Unknown' }
	}
}