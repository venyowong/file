module file

import venyowong.concurrent
import time

fn test_watch() {
	shared w := Watcher {
		path: "D:\\repos\\nucleus_eap\\NucleusEap\\bin\\Debug\\net8.0-windows\\logs\\log20250705.txt"
	}
	spawn w.start()
	for {
		concurrent.spin_wait(10 * time.millisecond, time.second, 50, u64(10 * time.second), fn [shared w]() bool {
			rlock w {
				return w.increments.len > 0
			}
		}) or {
			lock w {
				w.stop()
				println(w)
			}
			return
		}
		lock w {
			increment := w.increments.pop_left()
			println(increment.data.bytestr())
				println(w)
		}
	}
}