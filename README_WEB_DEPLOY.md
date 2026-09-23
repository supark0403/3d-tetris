# 진격의 서바이버: 입체기동 (AoT Vampire Survivors)

진격의 거인 컨셉의 3D 뱀파이어 서바이벌. 레인저가 입체기동장치로 벽·건물·나무·거인에 그래플링하며 10분 생존.

## 조작 (PC)
- WASD 이동, 마우스 시점, Space 점프, Shift 가스 부스트
- Q / E: 좌 / 우 훅 발사·해제, F 또는 우클릭: 양쪽 훅, Shift+훅: 릴 감기+분사
- 좌클릭 / J: 블레이드 공격 (공중+훅 상태면 목덜미 치명타)
- V: 1인칭 / 3인칭 전환, Esc / P: 일시정지(설정 포함)

## 모바일
- 메인 메뉴에서 📱 모바일 선택 → 좌측 가상 조이스틱 + 우측 드래그 시점 + ⚔/🪝L/🪝R/⤴/💨 버튼

## 게임 규칙
- 거인 5종: 소형(HP30/뎀8) → 소중형(65/14) → 중형(130/24) → 중대형(230/38) → 대형(420/60)
- 처치시 XP 젬 드롭 → 레벨업 3택1 강화 (공격/체력/기동/사거리/치명타)
- 10:00 버티면 클리어, 체력 0이면 게임 오버

## 에셋 출처 (ASSET_ZIP 적극 활용)
- 플레이어: `Modular Character Outfits - Fantasy[Standard]` 레인저 (Male_Ranger.gltf)
- 거인: `Universal Base Characters[Standard]` 남성 베이스 스케일 변형 5종
- 마을: `Medieval Village MegaKit[Standard]` 벽/지붕/문/창문/소품 모듈 30종+ 프로시저럴 조립
- 나무/바닥: `Stylized Nature MegaKit[Standard]` Common/Pine/Twisted/Dead 트리 + Bush/Rock, Plane 바닥
- 무기: `Medieval Weapons` (블레이드 컨셉 참조, 인게임은 박스 블레이드+메탈 PBR)
- 애니메이션: `Universal Animation Library 1/2` UAL1/UAL2 Standard.glb 동봉 (확장용, 코드 폴백 이동)
- GUI: `Generic Dark pixel` gdp_theme.tres + 스타일 전면 적용
- SFX: `JDSherbert Wooden UI SFX` Confirm/Cancel/Cursor/Select/Error
- 스카이: `Free Sky Backgrounds` 중 175번 메뉴 배경 + 인게임 ProceduralSky
- 폰트: NanumGothic Regular/Bold (OFL, 한글 깨짐 없음 — 게임에서 가장 많이 쓰는 계열)

## 실행
1. Godot 4.7.2-stable (GL Compatibility) 로 `project.godot` 열기
2. 메인 씬: `res://scenes/main.tscn` (F5)
3. 최초 임포트가 끝나야 에셋 썸네일/콜리전이 생성됨

## 웹 배포 (GitHub)
- `export_presets.cfg` 에 Web 프리셋 포함 (스레드 OFF → COI 없이도 실행, PWA ON)
- `main` 브랜치 푸시 → `.github/workflows/web-export.yml` → `gh-pages` 브랜치에 자동 배포
- Pages 설정: Settings → Pages → Deploy from branch → `gh-pages`
- 대용량 에셋 주의: `ASSET_ZIP/` 원본 ZIP은 export 제외. `assets/` glTF가 200MB+이므로初回 로딩이 김. 가벼운 웹 빌드가 필요하면 `assets/village/glTF` 중 미사용 100종을 씬에서 참조 제거 후 `export_presets.cfg` exclude에 추가.
- 실측(2026-09): Web `index.pck` 약 235MB. GitHub Pages는 git 단일 파일 100MB 제한이 있어 그대로 푸시하면 gh-pages 배포가 거부될 수 있다. 대책:
  1. (권장·간단) itch.io / Cloudflare Pages / निज 서버에 `build/web` 업로드 (드래그앤드롭으로 바로 플레이 가능)
  2. GitHub Releases에 `index.pck`+`index.wasm` 첨부 후 Pages에서는 로더만 두기
  3. `assets/village/glTF`(176종 중 실제 사용 20종)와 Ranger Normal/ORM(22MB)을 경량화하면 100MB 이하로 축소 가능 — `arena_builder.gd`는 로드 실패시 박스/캡슐 폴백이라 제외해도 게임이 깨지지 않음

## 라이선스/크레딧
- Universal Graphic / Medieval Village / Stylized Nature / Medieval Weapons: 각 스토어 라이선스 준수 (프로젝트 내 사용만, 재배포 금지 파일은 ASSET_ZIP 원본 firm 유지)
- NanumGothic: SIL OFL 1.1
- Wooden UI SFX: JDSherbert (itch.io 무료팩, 크레딧 표기)
