# 2D 도트 액션 RPG 모션·캐릭터 디자인 레퍼런스

> 목적: 플레이어가 "젤다의전설·크루세이더 퀘스트를 벤치마킹해달라"고 요청. **실제 스프라이트·
> 그래픽·사운드를 베끼거나 그대로 가져오는 것은 절대 금지**(저작권/라이선스 위반, `docs/art/
> LICENSES.md`·`asset-sources.md` 규정 대상). 이 문서는 두 작품에서 관찰되는 "스타일 언어"(비례
> 공식, 애니메이션 타이밍, 연출 원리)만 저작권 없는 일반 원칙으로 재서술한다. 고유 캐릭터 이름·
> 대사·아이콘 디자인 등 표현 그 자체는 다루지 않는다.
> 작성일: 2026-09-09. GDD 2.3절("귀엽지만 뭉클한" 톤), 3장(SD 2.5등신 캐릭터) 기준.

## 요약

- 2D 도트 액션 게임의 "타격감"은 스프라이트 자체보다 **정지 프레임(히트스톱)·카메라 반응(셰이크)·
  이펙트(플래시/파티클)의 조합**에서 나온다는 것이 일반 게임 개발 자료 전반의 공통된 결론이다.
  이는 이미 이 프로젝트의 `hit_feel.gd` 패키지(히트스톱·넉백·흰 플래시·데미지 숫자·카메라 셰이크)
  가 정확히 구현하고 있는 구조와 일치한다 — 지금 필요한 건 애니메이션 프레임 쪽의 보강이다.
- 공격 애니메이션은 어떤 게임이든 **선딜(anticipation)을 길게, 타격 프레임을 가장 짧게, 후딜을
  중간 길이로** 배분하는 3단 구조(준비-실행-회복)가 공통 원칙이다. 구체적으로는 선딜
  80~200ms, 타격 20~40ms, 후딜 60~100ms 범위가 자주 언급된다.
- SD/치비 캐릭터의 "귀여움"은 비례 공식(2~3등신)만이 아니라 **디테일을 과감히 생략하고 실루엣과
  표정만 남기는 단순화**에서 나온다 — GDD의 2.5등신 설정과 정확히 맞아떨어지는 범위다.
- 걷기 사이클은 **4~8프레임**이 업계 표준 범위이며, 프레임 수보다 **불균등한 홀드 타임**(정지
  프레임을 길게, 액션 프레임을 짧게)이 손맛에 더 크게 기여한다는 지적이 반복된다.
- 대기(idle) 모션은 최소 2프레임(호흡)만으로도 "살아있다"는 인상을 주며, 여기에 2~4초 주기의
  보조 동작(귀 까닥임, 눈 깜빡임 등)을 얹으면 캐릭터성이 크게 강화된다.
- 피격(hurt) 리액션은 프레임 수를 적게(2~3프레임) 가져가는 대신 **흰 플래시·넉백·사운드**로 즉시성을
  보강하는 것이 일반적 패턴 — 이 역시 이미 구현된 `hit_flash.gd`/넉백 Tween 구조와 부합한다.

## 사례/소재 카드

### 1. 젤다의전설(2D 탑다운작 — 링크의 각성/신들의 트라이포스류)

- **이름**: 2D 탑다운 젤다의 이동·공격 애니메이션 프레임 구조
- **출처**: [Spriters Resource(GB/GBC 스프라이트 아카이브)](https://www.spriters-resource.com/game_boy_gbc/thelegendofzeldalinksawakeningdx/), [Zelda Dungeon Wiki 스프라이트 분류](https://www.zeldadungeon.net/wiki/Category:Link's_Awakening_DX_Sprite_Files), 일반 게임 임팩트 연출 자료([game feel 아티클](https://salivity.github.io/game-development/article/maximizing-game-feel-in-action-game-development))
- **무엇인가**: 4방향(상/하/좌/우) 기준으로 캐릭터별 걷기 2~4프레임, 검 공격은 방향별 정지 자세 +
  휘두름 자세의 소수 프레임 전환으로 구성되는 극도로 절약된 스프라이트 구조. 공격 판정은 애니메이션
  프레임보다 짧게 걸리는 경우가 많아 "휘두르는 그림"과 "때리는 순간"이 살짝 어긋나도 크게 어색하지
  않다.
- **왜 흥미로운가**: 프레임 수가 매우 적은데도(캐릭터당 총 스프라이트 수가 한 자릿수~십여 개
  수준) "이 캐릭터가 지금 무엇을 하는지" 즉시 읽힌다 — 실루엣과 방향성이 프레임 수보다 중요하다는
  증거.
- **이 게임에 적용하면**:
  1. 몬스터·플레이어 공격 모션을 "정지 자세 1장 + 휘두름 1~2장"까지 줄여도 방향·타이밍만
     명확하면 손맛에 큰 지장이 없다 — 현재 `WeaponPivot` 회전으로 대체 중인 상황(전용 프레임
     없음)과도 잘 맞는 절충안이므로, pixel-artist에게 "정확히 몇 프레임이 필요한가"를 요청할 때
     최소 기준으로 제시할 수 있다.
  2. 8방향 대신 4방향만 스프라이트를 만들고 나머지 대각선은 좌우 반전 + 상하 재사용으로 커버하는
     절약 전략도 이 장르의 흔한 관례.

### 2. 임팩트 연출(정지 프레임·카메라 반응) — 일반 원리

- **이름**: 히트스톱(hitstop) + 카메라 셰이크 + 플래시의 3종 세트
- **출처**: [Research on Screen Shake and Hit Stop](https://www.oreateai.com/blog/research-on-the-mechanism-of-screen-shake-and-hit-stop-effects-on-game-impact/decf24388684845c565d0cc48f09fa24), [Maximizing Game Feel](https://salivity.github.io/game-development/article/maximizing-game-feel-in-action-game-development), [Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/)
- **무엇인가**: 타격 순간 게임 전체(또는 타격 관여 개체만)를 40~100ms 정지시키고, 그 직후 짧은
  카메라 흔들림과 스프라이트 색 반전(흰 플래시)을 동시에 재생하는 조합. 지속시간이 너무 짧으면
  느껴지지 않고, 너무 길면 끊긴 것처럼 보인다는 것이 반복 지적된다(체감 최적 구간 50~100ms).
- **왜 흥미로운가**: 스프라이트 프레임 자체를 늘리지 않고도(즉 아트 리소스 추가 없이) 타격감을
  극대화할 수 있는, 프로그래머 주도로 구현 가능한 연출이라는 점.
- **이 게임에 적용하면**: 이미 `scripts/systems/hit_feel.gd`가 이 3종 세트(히트스톱/넉백/
  플래시) + 카메라 셰이크(Phantom Camera)까지 구현되어 있다. **추가로 검토할 것**: 일반 타격과
  피니셔/크리티컬 타격의 히트스톱 길이를 다르게(예: 일반 40ms, 피니셔 80ms) 차등을 두면 "3타가
  묵직하다"는 M1 플레이테스트 목표 문항(§평가지 3-1 문항1)에 직접 기여할 수 있다 — 수치는
  `game/scripts/tuning.gd`에만 추가.

### 3. 크루세이더 퀘스트류 SD(2~3등신) 데포르메 비례

- **이름**: SD/치비 캐릭터 비례 공식
- **출처**: [Clip Studio Tips - 치비 그리기](https://tips.clip-studio.com/en-us/articles/4898), [Chibi(style) 개관](https://hagabaudr8.art/brevegraph-1/a-brevegraph-the-super-deformed-sd-chibi-style-in-2d-art), [Wikipedia Chibi](https://en.wikipedia.org/wiki/Chibi_(style)), [A' Design Award 백과](https://competition.adesignaward.com/design-encyclopedia.php?e=433373)
- **무엇인가**: 머리 크기를 몸 전체의 1/2~1/3로 과장(=2~3등신)하고, 옷 주름·근육 등 사실적
  디테일은 생략한 뒤 실루엣과 색면으로만 정보를 전달하는 양식. 2등신은 "장난감 같은" 인상, 2.5등신은
  가장 흔히 쓰이는 절충값, 3등신은 "치비 라이트"에 가까워 포즈 표현력이 늘어난다는 것이 정리된
  공식.
- **왜 흥미로운가**: 비례를 낮출수록 귀여움은 커지지만 액션 포즈(회전, 찌르기 등)의 가동 범위와
  가독성은 줄어드는 트레이드오프가 있다 — "귀여움 vs 액션 표현력" 사이에서 등신 수치를 고르는
  일이 곧 디자인 결정이라는 뜻.
- **이 게임에 적용하면**: GDD에 이미 명시된 "SD 비율(2.5등신)"은 이 트레이드오프에서 정확히
  중간값을 택한 것 — 근접 공격(핀의 검, 브람의 해머)처럼 팔 가동 범위가 필요한 캐릭터는 2.5등신을
  유지하되, 원거리 캐릭터(리라의 활, 모리의 지팡이)는 포즈가 더 정적이라 2.3등신 쪽으로 살짝 낮춰도
  괜찮다는 식으로 **캐릭터별 미세 조정 여지**를 pixel-artist에게 제안할 수 있다.

### 4. SD 캐릭터의 과장된 공격 모션(안티시페이션 강조)

- **이름**: 데포르메 캐릭터의 "크게 뒤로 당겼다가 크게 내지르는" 과장 표현
- **출처**: [Anticipation, Action, Recovery](https://www.rivalslib.com/workshop_guide/art/anticipation_action_recovery.html), [Pixelblog 56 - Top Down Character Attack Animation](https://www.slynyrd.com/blog/2025/5/23/pixelblog-56-top-down-character-attack-animation)(검색 요약 기준, 원문 접근 차단 — **미확인 세부치**), [Timing in Animation 2026](https://sunstrikestudios.com/en/blog/timing_in_animation/)
- **무엇인가**: 등신이 낮아 팔다리 길이가 짧은 만큼, 실제 물리 궤적보다 훨씬 과장된 준비 동작
  (몸 전체를 뒤로 젖히거나 웅크리는 포즈)을 넣어야 "공격한다"는 정보가 실루엣만으로도 전달된다.
  준비 동작이 클수록 작은 캐릭터에서도 액션이 읽힌다.
- **왜 흥미로운가**: 사실적 비례의 캐릭터라면 과한 동작이 부자연스럽지만, SD 캐릭터는 애초에
  비현실적 비례이므로 과장이 오히려 스타일과 일관성을 갖는다 — "작고 귀여운데 액션은 화끈하다"는
  간극 자체가 매력 포인트가 된다.
- **이 게임에 적용하면**: 3타 콤보 중 특히 피니셔(3타) 프레임에서 준비 자세(예: 무기를 크게 들어
  올리는 1프레임)를 다른 두 타보다 과장해 넣으면, 등신이 낮은 캐릭터에서도 "이번 타가 세다"는
  정보를 프레임 몇 장만으로 전달할 수 있다. 현재 전용 공격 프레임이 없는 상태(무기 회전으로 대체
  중)이므로, 이후 pixel-artist에게 공격 프레임을 요청할 때 "피니셔만이라도 준비 동작 프레임을
  별도로 달라"는 구체적 스펙으로 넘길 수 있다.

### 5. 대기(idle) 모션 — 숨쉬기/까닥임

- **이름**: 최소 2프레임 호흡 루프 + 보조 동작
- **출처**: [Idle Animation for Games (MoCap Online)](https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide), [Breathing Life into Idle Animations (AnimSchool)](https://blog.animschool.edu/2024/06/14/breathing-life-into-idle-animations/), [Isn't it time we rethink idle animations](https://guidohenkel.com/2014/10/isnt-it-time-we-rethink-idle-animations/)
- **무엇인가**: 몸통(또는 머리)을 1px 상하로 움직이는 2프레임만으로도 "정지해 있지 않다"는 인상을
  주며, 여기에 망토·머리카락 등 부속물을 반대 방향으로 살짝 흔들면 입체감이 더해진다. 더 나아가
  2~4초 주기로 하품·두리번거림 같은 "세컨더리 아이들"을 얹으면 캐릭터성이 강화된다는 것이 공통
  권고.
- **왜 흥미로운가**: 투자 대비 효과가 가장 큰 애니메이션 항목 중 하나로 꼽힌다 — 프레임 2장짜리
  호흡 루프가 "정적 이미지 그대로 방치"보다 체감 완성도를 크게 끌어올린다는 지적이 반복된다.
- **이 게임에 적용하면**: GDD 3장에 이미 "유휴 상태에서 하품·두리번거림 등 아이들 애니메이션
  보유"가 명시돼 있다 — 이 원칙과 정확히 일치한다. 우선순위 제안: (1) 모든 캐릭터 공통으로 2프레임
  호흡 루프부터 최소 스펙으로 확보 → (2) 캐릭터별 개성 살리는 세컨더리 동작(브람=콧노래로 몸 까닥,
  모리=졸린 눈 깜빡임, 리라=귀/화살통 흔들림)은 후순위로 순차 추가.

### 6. 피격(hurt) 리액션 — 짧은 프레임 + 강한 피드백

- **이름**: 최소 프레임 피격 애니메이션 + 플래시/넉백 보강
- **출처**: [Player damage VFX using animated sprites (Medium)](https://danielkirwan.medium.com/player-damage-vfx-using-animated-sprites-47f7a358f995), [White Flash on Damage (Godot, UhiyamaLab)](https://uhiyama-lab.com/en/notes/godot/modulate-white-flash-damage-effect/), [Visualizing Player Damage (Medium)](https://medium.com/geekculture/visualizing-player-damage-using-sprite-animation-in-unity-a6ef200b5b59)
- **무엇인가**: 피격 애니메이션 자체는 2~3프레임(살짝 뒤로 젖혀지는 정도)로 짧게 가져가고, 대신
  흰색/붉은색 플래시(모듈레이트 색상 반전)와 위치 넉백을 곱해 "맞았다"는 정보를 확실히 전달하는
  패턴이 일반적이다. 공격 애니메이션과 혼동되지 않도록 사운드나 플래시로 구분을 주는 것도 흔한
  보강책.
- **왜 흥미로운가**: 피격은 플레이어가 원치 않는 상태라 애니메이션에 공수를 많이 들이기보다
  "즉시 알아채고 다음 행동으로 넘어가게" 짧게 처리하는 게 합리적이라는 실용적 이유가 있다.
- **이 게임에 적용하면**: 현재 `Hurt` 상태와 `hit_flash.gd`(흰 플래시)·넉백(Tween)이 이미 구현돼
  있으므로, 전용 피격 프레임이 아직 없다면 우선순위를 낮게 잡아도 된다(플래시+넉백만으로 상당 부분
  체감 커버 가능) — pixel-artist 리소스가 부족할 때 공격 프레임보다 뒤로 미뤄도 되는 항목으로
  제안.

## 패턴 (반복되는 구조·장치)

1. **3단 타이밍 구조(선딜-타격-후딜)**: 모든 액션(이동 제외) 애니메이션이 "느리게 시작 → 순간
   빠르게 → 다시 느리게 마무리"의 비대칭 타이밍을 갖는다. 프레임 수를 늘리는 것보다 **각 프레임의
   홀드 시간을 불균등하게 배분**하는 것이 손맛에 더 크게 기여한다는 지적이 여러 출처에서 반복된다.
2. **정보량은 실루엣이 담당, 디테일은 생략**: 프레임 수가 적은 2D 도트 게임일수록 "지금 무슨
   행동을 하는지"는 몸 전체 실루엣의 변화로 전달되고, 세부 묘사(표정 디테일 등)는 오히려 줄인다.
3. **아트와 프로그램의 역할 분담**: 타격감의 상당 부분(히트스톱·셰이크·플래시·넉백)은 스프라이트
   프레임 없이 프로그램 쪽에서 구현 가능하다 — 아트 리소스가 부족한 개발 초기(M1 단계)에는 이 쪽을
   먼저 완성하고, 전용 애니메이션 프레임은 우선순위를 매겨 순차 추가하는 것이 합리적 전략이다(이미
   이 프로젝트가 그 순서로 진행 중).
4. **등신이 낮을수록 모션은 과장되어야 읽힌다**: SD 캐릭터는 팔다리 가동 범위가 짧으므로, 사실적
   캐릭터라면 과한 준비 동작이 오히려 스타일에 맞는 선택이 된다.
5. **최소 투자 항목이 체감 대비 효과가 크다**: idle 2프레임 호흡, hurt 2~3프레임 등 "적은 프레임
   수 + 강한 2차 피드백(플래시/넉백/사운드)" 조합이 반복적으로 권장된다.

## 주의점 (표절·저작권·클리셰 리스크)

- **금지**: 젤다·크루세이더 퀘스트의 실제 스프라이트 시트, 고유 캐릭터 실루엣/아이콘 디자인,
  대사·아이템 명칭, 사운드 이펙트 원본을 참고 이미지로 삼아 트레이싱하거나 리믹스하는 것. 이번
  리서치에서 수집한 것은 전부 "구조·수치·원리"이며 특정 프레임 이미지를 참조하지 않았다.
- **자체 확인 필요**: `Pixelblog 56`(슬린어드 블로그)은 네트워크 프록시 차단으로 원문을 직접
  열람하지 못하고 검색 엔진 요약만 확인했다 — 세부 프레임 수치를 그대로 인용하지 않았으며, 실제
  적용 전 pixel-artist가 원문을 재확인할 것을 권장(미확인 표시).
- **클리셰 리스크**: SD 데포르메 + 중세 판타지 + "귀엽지만 뭉클한" 톤 조합은 이미 스타듀밸리·
  옥토패스 트래블러류·수많은 인디 탑다운 RPG가 채택한 매우 흔한 조합이다. 차별화 지점은 스타일
  자체가 아니라 GDD가 이미 갖춘 세계관 요소(성물·잿빛 안개·엔딩 분기)와 애니메이션 디테일(캐릭터별
  세컨더리 아이들 모션 등)에서 찾아야 한다.
- **문화적 민감성**: 이번 조사 대상(젤다류·크루세이더 퀘스트·SD 치비 스타일)은 특정 살아있는
  종교·소수민족 전통을 소재로 하지 않는 상업적 창작 스타일이라 직접적 민감성 이슈는 낮다. 다만
  이후 지역별 몬스터·NPC 디자인 단계에서 실존 문화의 의상·상징을 SD로 과장 변형할 경우, 희화화로
  읽히지 않도록 별도 검토가 필요하다는 점만 미리 남겨 둔다.

## 이 프로젝트에 바로 적용 가능한 권장사항 (pixel-artist / godot-engineer용)

### 걷기(Move)
- 프레임 수: 4방향 × 4~6프레임(대각선은 좌우 반전 재사용)부터 시작. 8프레임까지는 늘려도 되지만
  그 이상은 이 등신·해상도에서 체감 이득이 작다는 것이 일반 권고.
- 타이밍: 8~12fps 재생(프레임당 약 80~125ms), 등속이 아니라 "발이 땅에 닿는" 프레임을 살짝 더
  길게 홀드.

### 공격(Attack, 3타 콤보 대응)
- 프레임 배분(콤보 1·2타): 선딜 1~2프레임(80~150ms 홀드) → 타격 1프레임(20~40ms, 최대한 짧게) →
  후딜 1~2프레임(60~100ms).
- 피니셔(3타)는 선딜 프레임에 SD 특유의 과장된 준비 포즈(무기를 평소보다 크게 들어 올리거나
  몸을 젖히는 실루엣)를 추가 요청 — 다른 두 타와 구분되는 "이번 건 세다"는 신호.
- 현재 `WeaponPivot` 회전 대체 방식은 과도기 해법으로 유지하되, 전용 프레임 확보 시 우선순위는
  피니셔(3타) → 1·2타 순으로 제안(피니셔 임팩트가 M1 평가지 문항1과 가장 직결).

### 피격(Hurt)
- 프레임 수: 2~3프레임(살짝 뒤로 젖혀지는 정도)이면 충분 — 이미 구현된 흰 플래시(`hit_flash.gd`)
  + 넉백 Tween과 합쳐지면 정보 전달은 충분하다. 아트 리소스가 부족하면 이 항목을 가장 나중으로
  미뤄도 무방.

### 대기(Idle)
- 최소 스펙: 2프레임 호흡 루프(500~800ms/프레임), 모든 캐릭터 공통.
- 확장 스펙(캐릭터 회차 유도용, GDD 3장과 연동): 캐릭터별 2~4초 주기 세컨더리 동작 1개씩(핀=검
  자루 고쳐 잡기, 리라=화살통 확인, 모리=하품, 브람=해머 어깨에 걸치고 콧노래) — 회차 플레이 시
  "다른 캐릭터를 골라보고 싶다"는 동기 강화에 기여할 수 있는 저비용 고효율 항목으로 제안.

### 히트스톱/카메라 연출 (godot-engineer용, 이미 구현된 시스템 보강 방향)
- 일반 타격과 피니셔/크리티컬의 히트스톱 지속시간에 차등(예: 일반 40~60ms, 피니셔 70~100ms)을
  두는 것을 `tuning.gd` 상수로 실험해 볼 것을 제안 — 코드 구조 변경 없이 수치만으로 검증 가능.
- 카메라 셰이크는 이미 강공격/크리티컬 한정으로 적용 중(Phantom Camera Noise Emitter) — 위 SD
  과장 원칙과 일관되게, 피니셔 타격에도 약한 셰이크를 추가하는 것을 M1 이후 검토 후보로 남긴다.

## 출처 목록

- https://www.spriters-resource.com/game_boy_gbc/thelegendofzeldalinksawakeningdx/
- https://www.zeldadungeon.net/wiki/Category:Link's_Awakening_DX_Sprite_Files
- https://en.wikipedia.org/wiki/Link_(The_Legend_of_Zelda)
- https://www.oreateai.com/blog/research-on-the-mechanism-of-screen-shake-and-hit-stop-effects-on-game-impact/decf24388684845c565d0cc48f09fa24
- https://salivity.github.io/game-development/article/maximizing-game-feel-in-action-game-development
- https://valdemird.com/blog/game-feel-on-the-web/
- https://hackread.com/the-juice-factor-designing-game-feel/
- https://tips.clip-studio.com/en-us/articles/4898
- https://tips.clip-studio.com/en-us/articles/10547
- https://hagabaudr8.art/brevegraph-1/a-brevegraph-the-super-deformed-sd-chibi-style-in-2d-art
- https://en.wikipedia.org/wiki/Chibi_(style)
- https://competition.adesignaward.com/design-encyclopedia.php?e=433373
- https://www.rivalslib.com/workshop_guide/art/anticipation_action_recovery.html
- https://www.slynyrd.com/blog/2025/5/23/pixelblog-56-top-down-character-attack-animation (검색 요약 기준, 원문 접근 차단 — 미확인)
- https://www.slynyrd.com/blog/2024/5/24/pixelblog-50-human-walk-cycle (검색 요약 기준, 원문 접근 차단 — 미확인)
- https://sunstrikestudios.com/en/blog/timing_in_animation/
- https://spritesheetgenerator.online/blog/animation-timing-fps-pixel-art
- https://mocaponline.com/blogs/mocap-news/idle-animation-game-dev-guide
- https://blog.animschool.edu/2024/06/14/breathing-life-into-idle-animations/
- https://guidohenkel.com/2014/10/isnt-it-time-we-rethink-idle-animations/
- https://danielkirwan.medium.com/player-damage-vfx-using-animated-sprites-47f7a358f995
- https://uhiyama-lab.com/en/notes/godot/modulate-white-flash-damage-effect/
- https://medium.com/geekculture/visualizing-player-damage-using-sprite-animation-in-unity-a6ef200b5b59
- https://crusaders-quest-game.fandom.com/wiki/Basics
- `docs/GDD-도트액션RPG-기획안.md`(프로젝트 내부 근거), `game/README.md`(구현 현황 근거)
