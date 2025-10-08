module file

import time

fn test_watch() {
	mut w := Watcher {
		path: "./watch_test.v"
		on_data: on_read_string
	}
	w.start()
	time.sleep(10 * time.second)
	w.stop()
}

fn on_read_string(bytes []u8) bool {
	println(bytes.bytestr())
	return true
}