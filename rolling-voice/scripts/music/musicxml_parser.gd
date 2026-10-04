class_name MusicXmlParser
extends RefCounted
## MusicXML(.musicxml / .xml / 압축 .mxl) 악보에서 멜로디와 가사를 읽는다.
## Audiveris 같은 악보 인식 프로그램이나 MuseScore에서 내보낸 파일을 그대로 쓸 수 있다.
##
## 지원: 음높이(조표·임시표는 <alter>로 반영), 박자(divisions), 템포(<sound tempo> / 메트로놈 표기),
##       붙임줄(tie), 화음(가장 높은 음), 여러 성부(첫 성부만), 꾸밈음(무시), 가사(syllabic),
##       줄바꿈(<print new-system> 또는 긴 쉼)
## 미지원: 도돌이표·D.S.·코다 (악보에 적힌 순서대로 한 번만 읽음)

const NAME_HINTS: PackedStringArray = ["vocal", "voice", "melody", "sing", "soprano", "lead", "보컬", "멜로디", "노래"]
const STEP_PC := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


## 파일 경로에서 읽기 (.mxl은 압축을 풀어서)
static func parse_file(path: String) -> Dictionary:
	if path.get_extension().to_lower() == "mxl":
		var zip := ZIPReader.new()
		if zip.open(path) != OK:
			return _fail("압축된 악보(.mxl)를 열 수 없어요")
		var inner := ""
		var files := zip.get_files()
		if files.has("META-INF/container.xml"):
			var container := _build_tree(zip.read_file("META-INF/container.xml"))
			var rootfile = _find_first(container, "rootfile")
			if rootfile:
				inner = rootfile.attrs.get("full-path", "")
		if inner.is_empty():
			for f in files:
				if not f.begins_with("META-INF") and (f.ends_with(".xml") or f.ends_with(".musicxml")):
					inner = f
					break
		if inner.is_empty() or not files.has(inner):
			zip.close()
			return _fail(".mxl 안에서 악보 파일을 찾지 못했어요")
		var bytes := zip.read_file(inner)
		zip.close()
		return parse_bytes(bytes)
	return parse_bytes(FileAccess.get_file_as_bytes(path))


## 결과: {ok, error, title, part, notes: [{start, end, midi, lyric, line}], first_bpm}
static func parse_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _fail("악보 파일이 비어 있어요")
	var root := _build_tree(bytes)
	if root.is_empty():
		return _fail("MusicXML 형식이 아니에요")
	var score = _find_first(root, "score-partwise")
	if score == null:
		if _find_first(root, "score-timewise"):
			return _fail("score-timewise 형식은 지원하지 않아요. MuseScore에서 다시 내보내 주세요")
		return _fail("MusicXML 악보를 찾지 못했어요")

	# 제목
	var title := ""
	var work = _child(score, "work")
	if work:
		title = _text(_child(work, "work-title"))
	if title.is_empty():
		title = _text(_child(score, "movement-title"))

	# 파트 이름
	var part_names := {}
	var part_list = _child(score, "part-list")
	if part_list:
		for sp in _children(part_list, "score-part"):
			part_names[sp.attrs.get("id", "")] = _text(_child(sp, "part-name"))

	# 멜로디 파트 고르기: 가사가 있는 파트 > 이름 힌트 > 첫 파트
	var parts := _children(score, "part")
	if parts.is_empty():
		return _fail("악보에 파트가 없어요")
	var chosen: Dictionary = parts[0]
	var best := -1
	for p in parts:
		var score_val := 0
		if _find_first(p, "lyric"):
			score_val += 10
		var pname := String(part_names.get(p.attrs.get("id", ""), "")).to_lower()
		for hint in NAME_HINTS:
			if pname.contains(hint):
				score_val += 5
				break
		if score_val > best:
			best = score_val
			chosen = p

	var res := _read_part(chosen)
	if res.notes.is_empty():
		return _fail("멜로디 음표를 찾지 못했어요")
	res["ok"] = true
	res["error"] = ""
	res["title"] = title
	res["part"] = part_names.get(chosen.attrs.get("id", ""), "")
	return res


static func _read_part(part: Dictionary) -> Dictionary:
	var divisions := 1.0
	var pos := 0.0                 # 현재 위치(4분음표 단위)
	var tempos: Array = [[0.0, 120.0]]
	var raw: Array = []            # [start_q, end_q, midi, lyric, line]
	var melody_voice := ""
	var line := 0
	var new_line_pending := false
	var last_end_q := 0.0
	var last_chord_start := -1.0

	for measure: Dictionary in _children(part, "measure"):
		var measure_start := pos
		for el: Dictionary in measure.children:
			match el.name:
				"print":
					if el.attrs.get("new-system", "") == "yes" or el.attrs.get("new-page", "") == "yes":
						new_line_pending = true
				"attributes":
					var d := _text(_child(el, "divisions"))
					if d.is_valid_float() and float(d) > 0.0:
						divisions = float(d)
				"sound":
					_add_tempo(tempos, pos, el)
				"direction":
					var snd = _child(el, "sound")
					if snd and snd.attrs.has("tempo"):
						_add_tempo(tempos, pos, snd)
					else:
						var metro = _find_first(el, "metronome")
						if metro:
							var bpm := _metronome_bpm(metro)
							if bpm > 0.0:
								tempos.append([pos, bpm])
				"backup":
					pos -= float(_text(_child(el, "duration"))) / divisions
				"forward":
					pos += float(_text(_child(el, "duration"))) / divisions
				"note":
					if _child(el, "grace"):
						continue
					var dur := float(_text(_child(el, "duration"))) / divisions
					var is_chord = _child(el, "chord") != null
					var voice := _text(_child(el, "voice"))
					if voice.is_empty():
						voice = "1"
					var start := pos
					if is_chord:
						start = last_chord_start
					else:
						last_chord_start = pos
						pos += dur
					if melody_voice.is_empty() and _child(el, "rest") == null:
						melody_voice = voice
					if voice != melody_voice:
						continue
					if _child(el, "rest"):
						continue
					var pitch = _child(el, "pitch")
					if pitch == null:
						continue  # 타악기 등
					var midi := _pitch_to_midi(pitch)
					if midi < 0:
						continue
					var end := start + dur
					var ties := _tie_types(el)
					# 화음: 같은 시작이면 높은 음만 남김
					if is_chord and not raw.is_empty() and is_equal_approx(raw[-1][0], start):
						if midi > raw[-1][2]:
							raw[-1][2] = midi
						continue
					# 붙임줄 끝: 앞 음과 같은 높이면 길이만 이어 붙임
					if ties.has("stop") and not raw.is_empty() and raw[-1][2] == midi \
							and absf(raw[-1][1] - start) < 0.01:
						raw[-1][1] = end
						continue
					# 줄바꿈: 새 시스템이거나 1.5박 넘게 쉬었을 때 (가사 줄 단위)
					if new_line_pending or (not raw.is_empty() and start - last_end_q >= 1.5):
						if not raw.is_empty():
							line += 1
						new_line_pending = false
					raw.append([start, end, midi, _lyric_text(el), line])
					last_end_q = end
		# 마디가 비어 있거나 쉼표만 있어도 위치가 맞게 (backup으로 돌아간 경우 대비)
		pos = maxf(pos, measure_start)

	# 4분음표 위치 → 초
	tempos.sort_custom(func(a, b): return a[0] < b[0])
	var tmap: Array = []  # [q, sec, bpm]
	var sec := 0.0
	var prev_q := 0.0
	var prev_bpm := 120.0
	for t in tempos:
		sec += (t[0] - prev_q) * 60.0 / prev_bpm
		prev_q = t[0]
		prev_bpm = t[1]
		tmap.append([prev_q, sec, prev_bpm])
	var notes: Array[Dictionary] = []
	for r in raw:
		var s := _q_to_sec(r[0], tmap)
		var e := _q_to_sec(r[1], tmap)
		if e - s >= 0.03:
			notes.append({"start": s, "end": e, "midi": r[2], "lyric": r[3], "line": r[4]})
	return {"notes": notes, "first_bpm": float(tmap[0][2]) if not tmap.is_empty() else 120.0}


static func _add_tempo(tempos: Array, pos: float, sound: Dictionary) -> void:
	var t := String(sound.attrs.get("tempo", ""))
	if t.is_valid_float() and float(t) > 0.0:
		if not tempos.is_empty() and is_equal_approx(tempos[-1][0], pos):
			tempos[-1][1] = float(t)
		else:
			tempos.append([pos, float(t)])


static func _metronome_bpm(metro: Dictionary) -> float:
	var per := _text(_child(metro, "per-minute"))
	if not per.is_valid_float():
		return -1.0
	var unit := _text(_child(metro, "beat-unit"))
	var factor := {"whole": 4.0, "half": 2.0, "quarter": 1.0, "eighth": 0.5, "16th": 0.25}.get(unit, 1.0) as float
	if _child(metro, "beat-unit-dot"):
		factor *= 1.5
	return float(per) * factor


static func _q_to_sec(q: float, tmap: Array) -> float:
	var seg: Array = tmap[0]
	for e in tmap:
		if e[0] <= q + 1e-6:
			seg = e
		else:
			break
	return seg[1] + (q - seg[0]) * 60.0 / seg[2]


static func _pitch_to_midi(pitch: Dictionary) -> int:
	var step := _text(_child(pitch, "step")).to_upper()
	var octave := _text(_child(pitch, "octave"))
	if not STEP_PC.has(step) or not octave.is_valid_int():
		return -1
	var alter := _text(_child(pitch, "alter"))
	var a := roundi(float(alter)) if alter.is_valid_float() else 0
	return (int(octave) + 1) * 12 + STEP_PC[step] + a


static func _tie_types(note: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for t in _children(note, "tie"):
		out.append(t.attrs.get("type", ""))
	var notations = _child(note, "notations")
	if notations:
		for t in _children(notations, "tied"):
			out.append(t.attrs.get("type", ""))
	return out


## 첫 번째 가사 줄(verse 1)만 쓴다. 단어 끝(end/single)에는 띄어쓰기를 붙인다.
static func _lyric_text(note: Dictionary) -> String:
	var lyrics := _children(note, "lyric")
	if lyrics.is_empty():
		return ""
	var ly: Dictionary = lyrics[0]
	for l in lyrics:
		if l.attrs.get("number", "1") == "1":
			ly = l
			break
	var text := ""
	for t in _children(ly, "text"):
		text += _text(t)
	text = text.strip_edges()
	if text.is_empty():
		return ""
	var syl := _text(_child(ly, "syllabic"))
	if syl == "end" or syl == "single" or syl.is_empty():
		text += "_"
	return text.replace(" ", "_")


# ── 아주 작은 DOM (XMLParser → Dictionary 트리) ──────────────────
static func _build_tree(bytes: PackedByteArray) -> Dictionary:
	var parser := XMLParser.new()
	if parser.open_buffer(bytes) != OK:
		return {}
	var root := {"name": "#root", "attrs": {}, "children": [], "text": ""}
	var stack: Array = [root]
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var node := {"name": parser.get_node_name(), "attrs": {}, "children": [], "text": ""}
				for i in parser.get_attribute_count():
					node.attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				stack[-1].children.append(node)
				if not parser.is_empty():
					stack.append(node)
			XMLParser.NODE_ELEMENT_END:
				if stack.size() > 1:
					stack.pop_back()
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				stack[-1].text += parser.get_node_data()
	return root if not root.children.is_empty() else {}


static func _child(node, name: String):
	if node == null:
		return null
	for c in node.children:
		if c.name == name:
			return c
	return null


static func _children(node, name: String) -> Array:
	var out: Array = []
	if node == null:
		return out
	for c in node.children:
		if c.name == name:
			out.append(c)
	return out


static func _find_first(node, name: String):
	if node == null:
		return null
	for c in node.children:
		if c.name == name:
			return c
		var found = _find_first(c, name)
		if found != null:
			return found
	return null


static func _text(node) -> String:
	return String(node.text).strip_edges() if node != null else ""


static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "notes": [], "title": "", "part": "", "first_bpm": 120.0}
