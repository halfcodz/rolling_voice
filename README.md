# Rolling Voice

굴러가는 동전이 쓰러지기 전에, 노래를 끝까지 부르는 Godot 4 노래 게임입니다.

노래가 흘러나오면 마이크로 따라 부릅니다. 음정이 맞지 않으면 동전이 조금씩 휘청이고, 정해 둔 횟수만큼 틀리면 동전이 쓰러집니다.

## 실행 방법

1. [Godot 4.7](https://godotengine.org/download)(Standard, 무료)을 설치합니다.
2. Godot 프로젝트 매니저에서 `rolling-voice/project.godot`를 가져와(Import) 엽니다.
3. <kbd>F5</kbd>로 실행합니다. 처음 실행하면 운영체제가 마이크 권한을 물어볼 수 있습니다.

> 이어폰을 끼고 플레이하세요. 스피커로 나온 가이드 멜로디가 마이크에 다시 들어가면 판정이 틀어집니다.

## 게임 규칙

| 설정 | 설명 |
| --- | --- |
| 최대 실수 | 1~30회. 이 횟수만큼 틀리면 동전이 쓰러집니다. |
| 난이도 | 쉬움 ±100센트 / 보통 ±60센트 / 어려움 ±35센트 (100센트 = 반음) |
| 옥타브 무시 | 한 옥타브 높거나 낮게 불러도 정답으로 칩니다. 남녀 키 차이용입니다. |

- 음표 하나가 끝날 때마다 그 음표 동안 허용 범위 안에서 부른 시간 비율을 계산합니다. 비율이 기준(쉬움 30% / 보통 45% / 어려움 60%)보다 낮으면 실수 1회입니다.
- 0.25초보다 짧은 음표는 판정하지 않습니다.
- 실수가 쌓일수록 동전이 크게 흔들리고, 지금 음이 틀리고 있으면 잔떨림이 더해집니다.
- 완주하면 음정 정확도에 따라 별 1~3개를 받습니다.

## 내 노래 추가하기

메뉴의 **내 노래 추가 → 노래 폴더 열기**를 누르면 사용자 노래 폴더(`user://songs`)가 열립니다.

- **MIDI (`.mid`)**: 멜로디 트랙을 자동으로 고릅니다. 트랙 이름에 `melody`/`vocal`/`멜로디`/`보컬`이 들어 있으면 그 트랙을 우선 씁니다. 같은 이름의 `.ogg`/`.mp3`/`.wav`가 있으면 반주로 함께 재생합니다.
- **텍스트 악보 (`.txt`)**: 메모장으로 쓸 수 있습니다.

```text
// 주석
title=도레미 연습
bpm=90
도4 레4 미4/2 R 솔4/0.5/가사 C5/2
```

음표는 `음이름[/박자[/가사]]` 형식입니다. 음이름은 `C4`, `F#3`, `Bb4`처럼 쓰거나 `도4`, `솔#4`처럼 계이름으로 써도 됩니다. `R`은 쉼표입니다. 머리말로 `bpm`(중간에 다시 쓰면 빠르기 변경), `transpose`(반음 단위 조옮김), `audio`(반주 파일), `offset`(반주에서 첫 음까지의 초)을 지정할 수 있습니다.

## 구조

```
rolling-voice/
├─ scenes/            main_menu.tscn, game.tscn
├─ scripts/
│  ├─ audio/          pitch_detector.gd (마이크 → YIN 음정 추정), melody_synth.gd (가이드 멜로디 합성)
│  ├─ music/          note_utils.gd, song_data.gd, song_library.gd (텍스트 악보), midi_parser.gd
│  ├─ game/           game.gd (판정), rolling_coin.gd, rolling_world.gd, pitch_lane.gd, game_hud.gd
│  ├─ ui/             main_menu.gd, ui_theme.gd (코드로 만든 Theme)
│  └─ global/         game_settings.gd (설정 저장, 오디오 버스)
├─ assets/            폰트·모델·효과음·아이콘 (출처: assets/CREDITS.md)
└─ tests/run_tests.gd 단위 테스트
```

사용한 Godot 기능은 다음과 같습니다.

- 오디오: `AudioStreamMicrophone`, `AudioEffectCapture`, `AudioStreamGenerator`, 버스 이펙트(Reverb, HardLimiter)
- 3D 화면: `GPUParticles3D`(먼지·불꽃·꽃가루), `ProceduralSkyMaterial`, SSAO, Glow, 깊이 안개
- UI: 코드로 만든 `Theme`/`StyleBoxFlat`, `Tween` 애니메이션, `FastNoiseLite` 카메라 흔들림

## 테스트

```bash
godot --headless --path rolling-voice -s res://tests/run_tests.gd
```

## 에셋 라이선스

- 3D 모델·효과음·스프라이트: [Kenney](https://kenney.nl) Starter Kits (CC0)
- 폰트: [Jua](https://fonts.google.com/specimen/Jua) (SIL OFL 1.1)
- 아이콘: [Material Symbols](https://github.com/google/material-design-icons) (Apache 2.0)

자세한 내용은 `rolling-voice/assets/CREDITS.md`를 참고하세요. 내장곡 4곡은 저작권이 만료된 멜로디만 담고 있습니다.
