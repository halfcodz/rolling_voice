class_name OmrRunner
extends Node
## 악보 사진·PDF → MusicXML(.mxl) 변환.
## 무료 악보 인식 프로그램 Audiveris를 백그라운드로 실행하고(-batch -export),
## 결과 .mxl을 노래 폴더로 옮긴다. 게임은 그 .mxl을 MusicXmlParser로 읽는다.

signal finished(mxl_path: String)
signal failed(message: String)

const IMAGE_EXTS: PackedStringArray = ["png", "jpg", "jpeg", "bmp", "tif", "tiff", "pdf"]
const DOWNLOAD_URL := "https://github.com/Audiveris/audiveris/releases"
const TIMEOUT_SEC := 600.0

var _pid := -1
var _out_dir := ""
var _source := ""
var _elapsed := 0.0


## Audiveris 실행 파일 찾기: 설정에 저장된 경로 → 흔한 설치 위치 → PATH
static func find_audiveris() -> String:
	var saved: String = GameSettings.audiveris_path
	if not saved.is_empty() and FileAccess.file_exists(saved):
		return saved
	var candidates: PackedStringArray = []
	match OS.get_name():
		"Windows":
			for base in [OS.get_environment("ProgramFiles"), OS.get_environment("ProgramFiles(x86)"),
					OS.get_environment("LOCALAPPDATA").path_join("Programs"), "C:/Program Files"]:
				if String(base).is_empty():
					continue
				candidates.append(String(base).path_join("Audiveris/Audiveris.exe"))
				candidates.append(String(base).path_join("Audiveris/bin/Audiveris.bat"))
		"macOS":
			candidates.append("/Applications/Audiveris.app/Contents/MacOS/Audiveris")
		_:
			candidates.append("/opt/audiveris/bin/Audiveris")
			candidates.append("/usr/bin/audiveris")
			candidates.append("/usr/local/bin/audiveris")
	for c in candidates:
		if FileAccess.file_exists(c):
			return c
	# PATH에서 찾기
	var out: Array = []
	if OS.get_name() == "Windows":
		OS.execute("where", ["Audiveris"], out)
	else:
		OS.execute("which", ["audiveris"], out)
	if not out.is_empty():
		var first := String(out[0]).strip_edges().get_slice("\n", 0).strip_edges()
		if not first.is_empty() and FileAccess.file_exists(first):
			return first
	return ""


static func is_image(path: String) -> bool:
	return IMAGE_EXTS.has(path.get_extension().to_lower())


## 한국어 OCR 데이터(kor.traineddata)가 설치돼 있으면 가사를 한국어+영어로 읽게 한다.
static func _ocr_languages() -> String:
	var dirs: PackedStringArray = []
	if OS.get_name() == "Windows":
		dirs.append(OS.get_environment("APPDATA").path_join("AudiverisLtd/audiveris/tessdata"))
	else:
		dirs.append(OS.get_environment("HOME").path_join(".config/AudiverisLtd/audiveris/tessdata"))
		dirs.append(OS.get_environment("HOME").path_join("Library/Application Support/AudiverisLtd/audiveris/tessdata"))
	for d in dirs:
		if FileAccess.file_exists(d.path_join("kor.traineddata")):
			return "kor+eng"
	return "eng"


func run(image_path: String) -> void:
	var exe := find_audiveris()
	if exe.is_empty():
		failed.emit("NO_AUDIVERIS")
		return
	_source = image_path
	_out_dir = ProjectSettings.globalize_path("user://omr_work/%d" % Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var args: PackedStringArray = [
		"-batch", "-export",
		"-output", _out_dir,
		"-constant", "org.audiveris.omr.text.Language.defaultSpecification=" + _ocr_languages(),
		"--", image_path,
	]
	if exe.to_lower().ends_with(".bat"):
		args.insert(0, exe)
		args.insert(0, "/c")
		exe = "cmd.exe"
	_pid = OS.create_process(exe, args, false)
	if _pid <= 0:
		failed.emit("Audiveris를 실행하지 못했어요: " + exe)
		return
	_elapsed = 0.0


func cancel() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


func _process(delta: float) -> void:
	if _pid <= 0:
		return
	_elapsed += delta
	if _elapsed > TIMEOUT_SEC:
		cancel()
		failed.emit("악보 인식이 너무 오래 걸려서 멈췄어요")
		return
	if OS.is_process_running(_pid):
		return
	_pid = -1
	_collect()


func _collect() -> void:
	# Audiveris는 <출력폴더>/<이름>/<이름>.mxl 또는 <이름>.mvt1.mxl 처럼 내보낸다 → 가장 큰 .mxl 선택
	var found := _find_mxl(_out_dir)
	if found.is_empty():
		_remove_tree(_out_dir)
		failed.emit("악보를 읽지 못했어요. 더 밝고 반듯하게 찍은 사진(또는 PDF)으로 해 보세요")
		return
	SongLibrary.ensure_songs_dir()
	var base := _source.get_file().get_basename()
	var dst := SongLibrary.SONGS_DIR.path_join(base + ".mxl")
	var n := 2
	while FileAccess.file_exists(dst):
		dst = SongLibrary.SONGS_DIR.path_join("%s (%d).mxl" % [base, n])
		n += 1
	var ok := DirAccess.copy_absolute(found, dst) == OK
	_remove_tree(_out_dir)
	if not ok:
		failed.emit("인식한 악보를 노래 폴더에 저장하지 못했어요")
		return
	finished.emit(dst)


## 임시 작업 폴더 정리
static func _remove_tree(dir: String) -> void:
	if dir.is_empty() or not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _find_mxl(dir: String) -> String:
	var best := ""
	var best_size := -1
	var stack: PackedStringArray = [dir]
	while not stack.is_empty():
		var d: String = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		for f in DirAccess.get_files_at(d):
			if f.get_extension().to_lower() == "mxl":
				var p := d.path_join(f)
				var size := FileAccess.get_file_as_bytes(p).size()
				if size > best_size:
					best_size = size
					best = p
		for sub in DirAccess.get_directories_at(d):
			stack.append(d.path_join(sub))
	return best
