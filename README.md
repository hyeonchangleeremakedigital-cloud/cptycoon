# 쿠팡 물류센터 타이쿤

HTML 플레이어블 시안을 Godot 4.7.2 / GDScript로 재구현한 네이티브 Android 프로토타입입니다. WebView를 사용하지 않습니다.

## 플레이

- 터치 또는 드래그로 이동. PC는 방향키/WASD.
- 레일 가까이 가면 자동 집기, A/B/C 분류존에서 자동 정리.
- 8개 정리 후 다음 근무로 진행. 다음 목표는 4개씩 증가.
- 정리 1개당 10코인. 속도/가방 업그레이드(각 최대 3단계).
- 누적 정리 수, 코인, 업그레이드는 기기에 저장됩니다.
- 음소거 기본값. 일시 중단/복귀와 Android 뒤로가기 지원.

## 개발

Godot 4.7.2에서 `project.godot`을 가져온 뒤 F6/F5로 실행합니다.

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . -- --smoke-test
godot --headless --path . --export-debug "Android APK" builds/cptycoon-debug.apk
godot --headless --path . --export-release "Windows Desktop" builds/cptycoon.exe
godot --headless --path . --export-release "Web" builds/web/index.html
```

이 저장소의 Android 프리셋은 서명을 분리합니다. 직접 내보낸 APK에는 `apksigner` 서명이 추가로 필요합니다. 제공된 `cptycoon-android.apk`는 이미 디버그 서명되어 설치할 수 있고, `cptycoon-release.aab`는 별도의 업로드 키로 서명했습니다.

Android 빌드에는 같은 버전의 export templates, JDK 17, Android SDK가 필요합니다. 엔진의 Android export 설정에서 Java/SDK 경로를 지정하세요. 자세한 로컬 설치 상태는 별도 인수인계 문서를 참고하세요.

## 구조

- `scripts/game.gd`: 게임 상태·입력·자동 집기/분류·저장·픽셀 렌더링
- `scenes/main.tscn`: 메인 장면
- `assets/korean_font.tres`: Noto Sans KR 650 폰트의 현재 게임 문자 서브셋
- `assets/OFL.txt`: 폰트 라이선스
- `export_presets.cfg`: Android APK/AAB, Windows, Web 프리셋
- `.github/workflows/build.yml`: 테스트 후 Android/Windows/Web 빌드

한글 문구를 추가할 때 현재 서브셋에 없는 글자가 있으면 원본 Noto Sans KR로 폰트를 다시 생성하거나 교체해야 합니다.

## 범위

패키지 ID: `com.remakedigital.cptycoon.prototype`, 버전 0.1.0 / code 1.
인앱결제·광고 SDK·분석 SDK·채용 지원 링크는 포함하지 않습니다. 코인은 게임 재화이며 실제 급여와 관계없습니다.
첨부 참고 자료의 분위기와 물류센터 요소를 참고해 그래픽을 코드로 새로 그렸습니다.

## 배포

GitHub Actions의 `prototype-builds` 아티팩트는 테스트용입니다. Play Store 업로드는 별도 릴리스 서명이 필요합니다. 서명키·비밀번호는 저장소에 넣지 마세요.
기존 HTML→Godot 이식 이후에는 동일 Godot 소스로 Web과 Android를 빌드할 수 있습니다.

현재 GitHub Actions 워크플로는 제공만 했으며 원격 실행은 검증하지 않았습니다. 사용자가 직접 소스를 업로드하는 범위입니다.

## MCP

개발 PC에는 `Coding-Solo/godot-mcp`를 설치하고 Codex MCP 설정에 등록했습니다. 이는 Godot 공식 내장 기능이 아닌 커뮤니티 MCP 서버입니다. 런타임 앱에는 포함되지 않습니다.
