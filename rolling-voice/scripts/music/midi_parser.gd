class_name MidiParser
extends RefCounted
## 표준 MIDI 파일(.mid)에서 멜로디 한 줄을 뽑아낸다.
## - 여러 트랙/채널 중 '노래 멜로디처럼 보이는' 것을 고른다
##   (트랙 이름에 melody/vocal/멜로디/보컬 등이 있으면 우선, 아니면 단선율·음역 기준 점수)
## - 화음이 겹치면 가장 높은 음만 남긴다(스카이라인)
## - 드럼 채널(10번)은 무시한다

const VOCAL_LOW := 45   # A2
const VOCAL_HIGH := 84  # C6
const NAME_HINTS: PackedStringArray = ["melody", "vocal", "voice", "lead", "sing", "멜로디", "보컬", "노래", "주선율"]


class Reader:
	var b: PackedByteArray
	var p := 0

	func _init(bytes: PackedByteArray) -> void:
		b = bytes

	func left() -> int:
		return b.size() - p

	func u8() -> int:
		if p >= b.size():
			p += 1
			return 0
		var v := b[p]
		p += 1
		return v

	func u16() -> int:
		var hi := u8()
		var lo := u8()
		return (hi << 8) | lo

	func u32() -> int:
		var a := u16()
		var c := u16()
		return (a << 16) | c

	func vlq() -> int:
		var v := 0
		for i in 4:
			var c := u8()
			v = (v << 7) | (c & 0x7F)
			if (c & 0x80) == 0:
				break
		return v

	func text(n: int) -> String:
		var end := mini(p + n, b.size())
		var s := b.slice(p, end).get_string_from_utf8()
		if s.is_empty() and end > p:
			s = b.slice(p, end).get_string_from_ascii()
		p += n
		return s


## 결과: {"ok": bool, "error": String, "notes": Array[{start,end,midi}], "track": String}
static func parse(bytes: PackedByteArray) -> Dictionary:
	var r := Reader.new(bytes)
	if r.left() < 14 or r.text(4) != "MThd":
		return _fail("MIDI 파일 형식이 아니에요")
	var header_len := r.u32()
	r.u16()  # format
	var track_count := r.u16()
	var division := r.u16()
	r.p = 8 + header_len
	if (division & 0x8000) != 0:
		return _fail("SMPTE 시간 형식 MIDI는 지원하지 않아요")
	if division <= 0:
		return _fail("MIDI 해상도 값이 잘못됐어요")

	var tempos: Array = [[0, 500000]]
	var groups := {}  # (track*16+ch) -> {"name", "notes": [[start_tick, end_tick, key]]}
	var track_names := {}

	for t in track_count:
		if r.left() < 8:
			break
		var chunk_id := r.text(4)
		var length := r.u32()
		var end := mini(r.p + length, bytes.size())
		if chunk_id != "MTrk":
			r.p = end
			continue
		var tick := 0
		var status := 0
		var open := {}
		while r.p < end:
			tick += r.vlq()
			var b := r.u8()
			if b == 0xFF:
				var kind := r.u8()
				var l := r.vlq()
				var data_start := r.p
				if kind == 0x51 and l == 3:
					var t0 := r.u8()
					var t1 := r.u8()
					var t2 := r.u8()
					tempos.append([tick, (t0 << 16) | (t1 << 8) | t2])
				elif kind == 0x03 or kind == 0x04:
					track_names[t] = r.text(l)
				r.p = data_start + l
			elif b == 0xF0 or b == 0xF7:
				r.p += r.vlq()
			else:
				var d1 := 0
				if (b & 0x80) != 0:
					status = b
					d1 = r.u8()
				elif status != 0:
					d1 = b
				else:
					continue
				var msg := status & 0xF0
				var ch := status & 0x0F
				match msg:
					0x80, 0x90:
						var vel := r.u8()
						var key := ch * 128 + d1
						if msg == 0x90 and vel > 0:
							if not open.has(key):
								open[key] = []
							open[key].append(tick)
						elif open.has(key) and not open[key].is_empty():
							var start_tick: int = open[key].pop_front()
							if ch != 9 and tick > start_tick:
								var gk := t * 16 + ch
								if not groups.has(gk):
									groups[gk] = {"track": t, "notes": []}
								groups[gk].notes.append([start_tick, tick, d1])
					0xA0, 0xB0, 0xE0:
						r.u8()
					_:
						pass
		r.p = end

	if groups.is_empty():
		return _fail("MIDI 안에 음표가 없어요")

	# 템포 맵 (tick → 초)
	tempos.sort_custom(func(a, c): return a[0] < c[0])
	var tempo_map: Array = []  # [tick, sec, us_per_quarter]
	var sec := 0.0
	var last_tick := 0
	var last_tempo := 500000
	for e in tempos:
		sec += float(e[0] - last_tick) * last_tempo / 1000000.0 / division
		last_tick = e[0]
		last_tempo = e[1]
		tempo_map.append([last_tick, sec, last_tempo])

	# 멜로디 후보 고르기
	var best_key: int = -1
	var best_score := -1.0
	for gk: int in groups:
		var g: Dictionary = groups[gk]
		var notes: Array = g.notes
		notes.sort_custom(func(a, c): return a[0] < c[0] or (a[0] == c[0] and a[2] > c[2]))
		var in_range := 0
		var overlaps := 0
		for i in notes.size():
			if notes[i][2] >= VOCAL_LOW and notes[i][2] <= VOCAL_HIGH:
				in_range += 1
			if i + 1 < notes.size() and notes[i + 1][0] < notes[i][1] - division / 8:
				overlaps += 1
		var mono := 1.0 - float(overlaps) / notes.size()
		var score := in_range * (0.25 + mono * mono)
		var tname: String = String(track_names.get(g.track, "")).to_lower()
		for hint in NAME_HINTS:
			if tname.contains(hint):
				score *= 4.0
				break
		if score > best_score:
			best_score = score
			best_key = gk

	var chosen: Array = groups[best_key].notes
	var mono_notes := _skyline(chosen)
	var out: Array[Dictionary] = []
	for n in mono_notes:
		var s := _tick_to_sec(n[0], tempo_map, division)
		var e := _tick_to_sec(n[1], tempo_map, division)
		if e - s >= 0.06:
			out.append({"start": s, "end": e, "midi": n[2]})
	if out.is_empty():
		return _fail("멜로디로 쓸 음표를 찾지 못했어요")
	return {"ok": true, "error": "", "notes": out,
		"track": String(track_names.get(groups[best_key].track, ""))}


static func _skyline(notes: Array) -> Array:
	var result: Array = []
	for n in notes:
		if result.is_empty():
			result.append(n.duplicate())
			continue
		var prev: Array = result[-1]
		if n[0] == prev[0]:
			continue  # 같은 시각 화음 → 이미 높은 음이 들어가 있음
		if n[0] < prev[1]:
			if n[2] < prev[2] and n[1] <= prev[1]:
				continue  # 더 낮은 음이 안쪽에 겹침 → 버림
			prev[1] = n[0]
		result.append(n.duplicate())
	return result


static func _tick_to_sec(tick: int, tempo_map: Array, division: int) -> float:
	var seg: Array = tempo_map[0]
	for e in tempo_map:
		if e[0] <= tick:
			seg = e
		else:
			break
	return seg[1] + float(tick - seg[0]) * seg[2] / 1000000.0 / division


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "notes": [], "track": ""}
