module file

import os

pub fn read_by_line[T](path string, process fn(string) ?T) ![]T {
	mut file := os.open_file(path, "rb")!
	defer {
        file.close()
    }

	mut result := []T{}
	buff_size := 4096
	mut buffer := []u8{len: buff_size}
    mut data := []u8{}
	for {
		// 读取数据到缓冲区
        n := file.read(mut buffer)!

		index := data.len // 开始遍历的下标
        mut start := 0
		// 合并上次剩余的数据和新读取的数据
		data << buffer[0..n]
		// 分割行（处理 \n 和 \r\n 两种换行符）
        for i := index; i < data.len; i++ {
            if data[i] == `\n` {
                // 提取一行（去除换行符）
                end := if i > 0 && data[i-1] == `\r` { i - 1 } else { i }
                line := data[start..end].bytestr()
				r := process(line)
				if r != none {
					result << r
				}
                start = i + 1
            }
        }

		// 保存未完成的行
        if start < data.len {
            data = unsafe{ data[start..] }
        } else {
			data = []u8{}
		}

		if n < buff_size {
			break
		}
	}

	if data.len > 0 {
		line := data.bytestr()
		r := process(line)
		if r != none {
			result << r
		}
    }
	return result
}