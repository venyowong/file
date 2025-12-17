module file

import time

fn test_chan() {
	append_by_chan("test.txt", "line 1", "line 2")
	time.sleep(1000 * time.millisecond)
}