# 3D Tetris

가이드라인 기반 3D 테트리스 (Godot 4.7, GL Compatibility).

## 조작 (설정에서 변경 가능, P/Esc·R 고정)
- `A` / `D`: 좌 / 우 이동 — **꾹 누르면 DAS(0.15s) 후 ARR(0.04s) 자동 연타**
- `W`: 하드드롭 (+2/칸), `S`: 소프트드롭 (+1/칸, 20배속)
- `←`: 반시계 회전, `→`: 시계 회전 (SRS + 킥)
- `Space`: 홀드 (락당 1회)
- `P` / `Esc`: 일시정지, `R`: 재시작

## 시스템
- 7-bag, 고스트 피스, 락딜레이 0.5s(리셋 15회), 10라인당 레벨업(중력 가속)
- T스핀 3코너 판정 (노라인 400, Single 800 / Double 1200 / Triple 1600 ×레벨)
- 라인 점수 100/300/500/800 ×레벨, B2B 1.5배, 콤보 50×콤보×레벨
- 게임오버: 스폰 막힘(블록아웃) / 완전 히든락(락아웃)

## 효과음·VFX (외부 파일 없음)
- 효과음: `scripts/autoload/sfx.gd`가 8비트 톤/아르페지오/노이즈를 절차 생성
  (이동·회전·홀드·락·하드드롭·클리어·테트리스·T스핀·콤보·레벨업·게임오버)
- VFX: 라인 플래시+파편, 하드드롭 더스트, 카메라 셰이크, TETRIS/T-SPIN 팝업

## 실행
Godot 4.7에서 `project.godot` 열기 → `F5`. 메인 메뉴에서 게임 시작,
설정(볼륨·키 바인딩, `user://tetris_settings.cfg` 저장) 후 플레이.

## 웹 배포 (GitHub Pages)
`tools/publish_web.bat` 더블클릭 한 번이면 끝난다. 내용:
1. `godot --headless --export-release Web` 로 `build/web` 생성
2. orphan `gh-pages` 브랜치에 빌드 결과만 커밋 → 강제 푸시
3. 주소: https://supark0403.github.io/3d-tetris/

Pages 최초 1회만 리포 Settings → Pages → Deploy from branch → `gh-pages` 선택.
(CI 워크플로 대신 수동 배포 — 토큰에 workflow 권한이 없어도 됨.)
