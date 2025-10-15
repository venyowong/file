module file

import os
import time
import venyowong.concurrent

pub struct Increment {
pub:
	data []u8 @[json: '-']
	last_mtime i64
	next_pos u64
}

pub struct Watcher {
pub:
	path string
pub mut:
	increments []Increment
	interval_steps int
	last_mtime i64
	min_spin_interval i64
	max_spin_interval i64
	next_pos u64
	stop bool
}

pub fn (shared w Watcher) start() {
	lock w {
		if w.min_spin_interval == 0 {
			w.min_spin_interval = 10 * time.millisecond
		}
		if w.max_spin_interval == 0 {
			w.max_spin_interval = 5 * time.second
		}
		if w.interval_steps <= 0 {
			w.interval_steps = 20
		}
	}
	
	w.watch_file()
}

pub fn (mut w Watcher) stop() {
	w.stop = true
}

fn (shared w Watcher) watch_file() {
	mut min_spin_interval := i64(0)
	mut max_spin_interval := i64(0)
	mut interval_steps := 0
	mut path := ""
	rlock w {
		min_spin_interval = w.min_spin_interval
		max_spin_interval = w.max_spin_interval
		interval_steps = w.interval_steps
		path = w.path
	}
	for {
		mut stop := false
		mut last_mtime := i64(0)
		mut next_pos := u64(0)
		rlock w {
			stop = w.stop
			last_mtime = w.last_mtime
			next_pos = w.next_pos
		}
		if stop {
			break
		}

		stat := os.stat(path) or {
			time.sleep(min_spin_interval)
			continue
		}

        if stat.mtime != last_mtime {
			if stat.size >= next_pos {
				mut f := os.open_file(path, "rb") or {
					time.sleep(min_spin_interval)
					continue
				}
				
				buff_size := 4096
				mut pos := next_pos
				mut buf := []u8{len: buff_size}
				mut bytes := []u8{}
				mut end := false
				for {
					n := f.read_from(pos, mut buf) or {
						break
					}
					if n > 0 {
						bytes << buf[0..n]
						pos += u64(n)
					}
					if n < buff_size {
						end = true
						break
					}
				}

				if end {
					lock w {
						w.next_pos += u64(bytes.len)
						w.increments << Increment {
							data: bytes
							next_pos: w.next_pos
							last_mtime: stat.mtime
						}
					}
				} else {
					time.sleep(min_spin_interval)
					f.close()
					continue
				}

				f.close()
			} else {
				lock w {
					w.next_pos = stat.size
					w.increments << Increment {
						data: []u8{}
						next_pos: w.next_pos
						last_mtime: stat.mtime
					}
				}
			}
			lock w {
				w.last_mtime = stat.mtime
			}
        }

		concurrent.spin_wait(min_spin_interval, max_spin_interval, interval_steps, 0, fn [shared w]() bool {
			rlock w {
				if w.stop {return true}
				s := os.stat(w.path) or {
					return false
				}
				return s.mtime != w.last_mtime
			}
		}) or {
			time.sleep(min_spin_interval)
			continue
		}
    }
}