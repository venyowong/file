@[has_globals]
module file

import os
import venyowong.concurrent

__global (
	chans concurrent.AsyncMap[Channel]
)

fn init() {
	chans = concurrent.AsyncMap.new[Channel]()
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
	for {
		l := <-c.ch or {
			break
		}
		c.f.writeln(l) or {
			return
		}
		if c.ch.len == 0 {
			c.f.flush()
		}
	}
}

pub fn append_by_chan(path string, lines ...string) {
	p := os.real_path(path)
	dir := os.dir(p)
	if !os.exists(dir) {
		os.mkdir_all(dir) or {
			panic("failed to create dir $dir : $err")
		}
	}
	
	c := chans.get_or_create(p, fn [p]() Channel {
		return Channel.new(p) or {
			panic("$p $err")
		}
	})
	c.append_lines(...lines)
}

pub fn close_channel(path string) {
	mut c := chans.get(path) or {return}
	c.close()
	chans.remove(path)
}

pub fn close_channels() {
	for k in chans.keys() {
		mut c := chans.get(k) or {continue}
		c.close()
		chans.remove(k)
	}
}