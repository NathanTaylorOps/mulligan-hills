class_name MHDirtyTracker
extends RefCounted
## Dirty rectangles per chunk. Rects are inclusive, in global sample coordinates.
## Chunk c owns texture samples [c*S-1, c*S+S+1] on each axis (S = chunk cells): its 33 vertices
## plus a one-sample border used for normals. A changed sample can therefore dirty up to 2x2 chunks.
## take() returns entries in first-dirtied order (deterministic) as 5 ints each:
## chunk_id, x0, y0, x1, y1, and clears the tracker.

const NONE: int = 1 << 30

var chunk_size: int = 32
var chunks_x: int = 0
var chunks_y: int = 0
var samples_x: int = 0
var samples_y: int = 0
var mark_count: int = 0

var _rects: PackedInt32Array = PackedInt32Array()
var _list: PackedInt32Array = PackedInt32Array()


@warning_ignore("integer_division")
func _init(p_samples_x: int, p_samples_y: int, p_chunk_size: int = 32) -> void:
	samples_x = p_samples_x
	samples_y = p_samples_y
	chunk_size = maxi(p_chunk_size, 1)
	chunks_x = (samples_x - 1 + chunk_size - 1) / chunk_size
	chunks_y = (samples_y - 1 + chunk_size - 1) / chunk_size
	_rects.resize(chunks_x * chunks_y * 4)
	for c in range(chunks_x * chunks_y):
		_rects[c * 4] = NONE
		_rects[c * 4 + 1] = NONE
		_rects[c * 4 + 2] = -1
		_rects[c * 4 + 3] = -1


func chunk_count() -> int:
	return chunks_x * chunks_y


func dirty_count() -> int:
	return _list.size()


func is_dirty(chunk_id: int) -> bool:
	return _rects[chunk_id * 4] != NONE


func peek_rect(chunk_id: int) -> Rect2i:
	var b: int = chunk_id * 4
	if _rects[b] == NONE:
		return Rect2i()
	return Rect2i(_rects[b], _rects[b + 1], _rects[b + 2] - _rects[b] + 1, _rects[b + 3] - _rects[b + 1] + 1)


@warning_ignore("integer_division")
func _first_chunk(v: int) -> int:
	var n: int = v - chunk_size - 1
	if n <= 0:
		return 0
	return (n + chunk_size - 1) / chunk_size


@warning_ignore("integer_division")
func _last_chunk(v: int, chunk_total: int) -> int:
	return mini(chunk_total - 1, (v + 1) / chunk_size)


func mark_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	x0 = maxi(x0, 0)
	y0 = maxi(y0, 0)
	x1 = mini(x1, samples_x - 1)
	y1 = mini(y1, samples_y - 1)
	if x0 > x1 or y0 > y1:
		return
	mark_count += 1
	for cy in range(_first_chunk(y0), _last_chunk(y1, chunks_y) + 1):
		for cx in range(_first_chunk(x0), _last_chunk(x1, chunks_x) + 1):
			var rx0: int = maxi(cx * chunk_size - 1, 0)
			var ry0: int = maxi(cy * chunk_size - 1, 0)
			var rx1: int = mini(cx * chunk_size + chunk_size + 1, samples_x - 1)
			var ry1: int = mini(cy * chunk_size + chunk_size + 1, samples_y - 1)
			var ix0: int = maxi(x0, rx0)
			var iy0: int = maxi(y0, ry0)
			var ix1: int = mini(x1, rx1)
			var iy1: int = mini(y1, ry1)
			if ix0 > ix1 or iy0 > iy1:
				continue
			var c: int = cy * chunks_x + cx
			var b: int = c * 4
			if _rects[b] == NONE:
				_list.append(c)
				_rects[b] = ix0
				_rects[b + 1] = iy0
				_rects[b + 2] = ix1
				_rects[b + 3] = iy1
			else:
				_rects[b] = mini(_rects[b], ix0)
				_rects[b + 1] = mini(_rects[b + 1], iy0)
				_rects[b + 2] = maxi(_rects[b + 2], ix1)
				_rects[b + 3] = maxi(_rects[b + 3], iy1)


func mark_all() -> void:
	mark_rect(0, 0, samples_x - 1, samples_y - 1)


## Returns [chunk_id, x0, y0, x1, y1] * dirty_count and clears.
func take() -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in range(_list.size()):
		var c: int = _list[k]
		var b: int = c * 4
		out.append(c)
		out.append(_rects[b])
		out.append(_rects[b + 1])
		out.append(_rects[b + 2])
		out.append(_rects[b + 3])
		_rects[b] = NONE
		_rects[b + 1] = NONE
		_rects[b + 2] = -1
		_rects[b + 3] = -1
	_list.clear()
	return out
