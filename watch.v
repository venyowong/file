module file

import os
import time
import venyowong.concurrent

pub struct Watcher {
mut:
	stop bool
	t thread
pub:
	path string
	on_data fn ([]u8) bool @[required]
pub mut:
	last_mtime i64
	next_pos u64
	min_spin_interval i64
	max_spin_interval i64
	interval_steps int
}

pub fn (mut w Watcher) start() {
	if w.min_spin_interval == 0 {
		w.min_spin_interval = 10 * time.millisecond
	}
	if w.max_spin_interval == 0 {
		w.max_spin_interval = 5 * time.second
	}
	if w.interval_steps <= 0 {
		w.interval_steps = 20
	}
	w.t = spawn watch_file(mut w)
}

pub fn (mut w Watcher) stop() {
	w.stop = true
}

fn watch_file(mut w Watcher) {
	for {
		if w.stop {
			break
		}

        stat := os.stat(w.path) or {
            time.sleep(w.min_spin_interval)
            continue
        }
        
        if stat.mtime != w.last_mtime {
			if stat.size >= w.next_pos {
				mut file := os.open_file(w.path, "rb") or {
					time.sleep(w.min_spin_interval)
					continue
				}
				defer {
					file.close()
				}
				
				buff_size := 4096
				mut pos := w.next_pos
				mut buf := []u8{len: buff_size}
				mut bytes := []u8{}
				mut end := false
				for {
					n := file.read_from(pos, mut buf) or {
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
					if w.on_data(bytes) {
						w.next_pos += u64(bytes.len)
					} else {
						time.sleep(w.min_spin_interval)
						continue
					}
				} else {
					time.sleep(w.min_spin_interval)
					continue
				}
			} else {
				w.next_pos = stat.size
			}
			w.last_mtime = stat.mtime
        }
        
        concurrent.spin_wait(w.min_spin_interval, w.max_spin_interval, w.interval_steps, 0, fn [w]() bool {
			if w.stop {return true}
			s := os.stat(w.path) or {
				return false
			}
			return s.mtime != w.last_mtime
		}) or {
			time.sleep(w.min_spin_interval)
			continue
		}
    }
}