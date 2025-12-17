@[has_globals]
module file

import log
import os
import venyowong.concurrent

__global (
	chans concurrent.SafeStructMap[Channel]
)

fn init() {
	chans = concurrent.SafeStructMap.new[Channel]()
}

struct Channel {
	ch chan string
	path string
mut:
	f os.File
}

fn Channel.new(path string) !Channel {
	mut f := os.open_file(path, 'a')!
	ch := chan string{}
	mut c := Channel {
		ch: &ch
		f: f
		path: path
	}
	mut r_c := &c
	spawn r_c.consume()
	return c
}

pub fn (c Channel) append_lines(lines ...string) {
	for l in lines {
		c.ch <- l
	}
}

pub fn (mut c Channel) close() {
	c.ch.close()
	c.f.close()
}

pub fn (mut c Channel) consume() {
	log.info("begin to consume lines for $c.path")
	for {
		l := <-c.ch or {
			log.info("[$c.path] channel closed")
			break
		}
		c.f.writeln(l) or {
			log.error("[$c.path] failed to append log $err")
			return
		}
		if c.ch.len == 0 {
			c.f.flush()
		}
	}
}

pub fn append_by_chan(path string, lines ...string) {
	c := chans.get_or_create(path, fn [path]() Channel {
		return Channel.new(path) or {
			panic("$path $err")
		}
	})
	c.append_lines(...lines)
}

pub fn close_channels() {
	for mut c in chans.values() {
		c.close()
	}
}