# 핀 편집 원본·제작 도구 감사

2026-09-13 · 읽기 전용 조사. 이미지 생성·래스터 코드 드로잉·프로그램 설치·기존 애셋 교체 없음.

## 결론

**승인된 핀의 레이어/프레임 편집 원본은 발견하지 못했다. Aseprite/LibreSprite 실행 파일도 조사한 PATH와 일반 설치 위치에서는 발견하지 못했다.** 따라서 현재 확인된 환경만으로 픽셀 편집기에서 직접 4개 핵심 포즈를 그리고 내보낼 수 있다고 보고할 근거가 없다. 이는 PC 전체에 프로그램이 없다는 단정이 아니다. 별도 드라이브·휴대용 설치·사용자 지정 경로는 조사하지 않았다.

게임 기준은 몸체 64×96, FHD 1920×1080, 은투구·붉은 깃털·황토 튜닉·초록 망토, 오른손 검/왼손 방패를 유지한다. 다음 품질 게이트는 실제 관절 연결과 접지가 있는 **접지 A·통과 A·접지 B·통과 B 전신 핵심 포즈**이며, 단순 움직임 흉내를 이 완료 기준으로 대체하지 않는다.

## 조사 증거

| 점검 | 방법 | 관찰 |
|---|---|---|
| 편집 가능한 파일 | 저장소에서 `rg --files`, 이어 숨김/ignore 포함 `rg --files -uu`, 확장자 `.ase/.aseprite/.ora/.kra/.psd/.xcf/.procreate/.clip` 검색. `.git`·엔진 캐시 제외 | 18개, 모두 `game/assets/third_party/tiny_swords/`의 `.aseprite` |
| 핀 전용 파일 | `docs/art`, `prototypes`, `tools`의 파일명 검색 | PNG·GIF·문서·후처리/분할 모션 Python·Godot 프로토타입. 핀 레이어/원화 타임라인 파일 없음 |
| 실행 명령 | `Get-Command aseprite,libresprite` | 해석되는 실행 명령 없음 |
| 다른 편집기 명령 참고 | `Get-Command krita,gimp` | PATH에서 발견되지 않음. 전체 설치 여부 조사 아님 |
| 일반 실행 파일 위치 | 아래 명시 경로를 `Test-Path -PathType Leaf`로만 검사 | 모두 False |
| Godot 플러그인 | `game/addons/AsepriteWizard` 코드 검색 | 플러그인 존재. `config_dialog.gd`는 외부 명령에 `--version`을 전달하고, `config.gd`는 `aseprite/general/command_path`를 관리. 플러그인 자체가 편집기 실행 파일은 아님 |
| 현재 도구 | 활성 도구 설명/이름 검사 | 이미지 생성·이미지 보기·명령 실행은 있음. 전용 Aseprite/LibreSprite 픽셀/타임라인 편집 커넥터는 발견되지 않음. 현재 CUA 설명상 native app 제어는 비활성 |

검사한 실행 파일:

- `C:/Program Files/Aseprite/Aseprite.exe`
- `C:/Program Files (x86)/Aseprite/Aseprite.exe`
- `C:/Program Files/LibreSprite/libresprite.exe`
- `C:/Program Files (x86)/LibreSprite/libresprite.exe`
- `C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe`
- `C:/Program Files/Steam/steamapps/common/Aseprite/Aseprite.exe`

위 Aseprite/LibreSprite 일반 설치 디렉터리와 `C:/Users/freer/AppData/Local/Programs/Aseprite`, `C:/Users/freer/AppData/Local/Programs/LibreSprite`도 존재 여부만 확인했으며 모두 False였다. 광범위한 사용자 폴더·레지스트리·개인 문서 탐색은 하지 않았다.

## 발견된 18개 원본의 의미

Tiny Swords의 Warrior/Pawn/Monk/Lancer/Archer, Particle FX, 물거품·나무·양·금·덤불·구름·장식 등이다. 파일 존재는 편집 가능한 형식의 자원이 저장소에 있다는 증거이지, 내부 레이어 구조·라이선스 적합성·핀 재사용 승인을 검증했다는 뜻이 아니다. 특히 **핀 외형의 원본이 아니며**, 다른 캐릭터 애니메이션에 핀 얼굴을 얹는 작업을 승인된 핀 보행 제작으로 취급할 수 없다.

## 기존 산출물을 재사용하지 않는 이유

- `tools/build_fin_front_test.py`는 원본 다리 마스크의 크기 변경·위치 이동과 hip cover 사각형을 사용한 cutout blockout이다. 사용자 거절 방식이며 재실행하지 않았다.
- `preview/parallel-pass/fin/contact-a-v1.png`는 앞선 검사의 1254×1254 RGB 이미지로 실제 알파가 없다. 고해상도 포즈 시안일 뿐 64×96 완성 프레임이 아니다.
- 독립 생성된 여러 이미지의 크기를 맞춘다고 얼굴·장비·관절의 시간적 일관성이 생기지 않는다. 독립 AI 아틀라스 방식은 반복하지 않는다.
- **생성 PNG 한 장을 `.aseprite` 컨테이너에 넣는 것은 파일 형식 변환일 뿐, 손으로 설계한 레이어·키포즈·중간 프레임 원본을 완성한 것이 아니다.**

## 가능한 범위와 추가 선택

현재 가능: 자료·제작 명세 정리, 기존 이미지/엔진 출력의 읽기 검수, 사용자가 제공한 새 레이어 원본의 구조 확인, 완성 프레임의 크기·알파·정렬 검사. 이 감사에서 새 프레임 제작은 하지 않았다.

추가 선택이 필요한 경로:

1. 사용자가 이미 가진 핀 편집 원본과 실제 편집기 경로를 제공하면 그 범위만 확인한다.
2. 새 픽셀 편집기 설치/사용은 사용자 결정 후 진행한다. 설치만으로 수작업 프레임 제작 능력이나 native GUI 자동화를 확보했다고 약속하지 않는다. 사용 가능한 편집·내보내기 경로를 별도 검증해야 한다.
3. 픽셀 아티스트가 4개 전신 키포즈와 레이어 원본을 제작하는 경로라면 별도 협업/비용 결정이 필요하다. 본 감사에서는 외부 연락·주문을 하지 않았다.

루트 작업자에게 이 선택 지점을 보고한다. 선택 전에는 손그림 완성 모션이라고 주장하거나 거절된 자동 변형으로 대체하지 않는다.
