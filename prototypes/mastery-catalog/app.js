"use strict";
const $ = id => document.getElementById(id);
const typeNames = {active:"액티브", modifier:"행동 변형", passive:"패시브", keystone:"핵심 특성"};
let documentData, nodeMap, ownerMap, selected;
function restoreSummary() {
  $("status").textContent = `${documentData.masteries.masteries.length}계열 · 계열 노드 ${nodeMap.size}개 + 조합 특성 ${documentData.hybrids.classes.length}개 = 성장 항목 ${nodeMap.size+documentData.hybrids.classes.length}개 / 구조 검사 통과 (전투 검증 아님)`;
}
function element(tag, text, className) {
  const item = document.createElement(tag);
  if (text !== undefined) item.textContent = text;
  if (className) item.className = className;
  return item;
}
function nodeLink(id) {
  const link = element("a", nodeMap.get(id)?.name || id);
  link.href = "#node/" + encodeURIComponent(id);
  link.addEventListener("click", () => { if(location.hash === link.hash) $("detail").scrollIntoView({block:"start"}); });
  return link;
}
function showNode(id) {
  const node = nodeMap.get(id);
  if (!node) { $("status").textContent = "알 수 없는 노드 링크입니다. 원본을 확인하세요."; return; }
  const detail = $("detail"); detail.replaceChildren(element("h3", node.name), element("code", node.id));
  const list = element("dl");
  const rows = [["유형 / 제안 단계",`${typeNames[node.type]} / ${node.tier}단계`], ["효과",node.effect], ["제약·대가",node.tradeoff], ["장비",node.equipment.join(" · ")], ["애니메이션 요구",node.animation], ["태그",node.tags.join(" · ")]];
  for (const [label,value] of rows) list.append(element("dt",label),element("dd",value));
  const prerequisites = element("dd");
  if (!node.requires_all.length) prerequisites.textContent = "이 JSON 내 선행 노드 없음. 실제 학습 비용·레벨 조건 확정 아님.";
  node.requires_all.forEach((reference,index) => { if(index) prerequisites.append(" + "); prerequisites.append(nodeLink(reference)); });
  list.append(element("dt","모두 필요한 선행 노드"),prerequisites);
  if (node.modifies) { const target = element("dd"); target.append(nodeLink(node.modifies)); list.append(element("dt","변형 대상 액티브"),target); }
  detail.append(list);
}
function showMastery(id) {
  selected = id;
  const mastery = documentData.masteries.masteries.find(item => item.id === id);
  $("mastery-summary").textContent = `${mastery.name} · 단일계열 직업 제안: ${mastery.pure_class} · ${mastery.role} / ${mastery.branches.join(" ↔ ")}`;
  for (const button of $("masteries").children) button.setAttribute("aria-pressed",String(button.dataset.id === id));
  $("nodes").replaceChildren();
  for (const node of [...mastery.nodes].sort((a,b) => a.tier-b.tier)) {
    const button = element("button",node.name);
    button.append(element("span",`${node.tier}단계 · ${typeNames[node.type]} · 선행 ${node.requires_all.length}개`));
    button.addEventListener("click",() => { location.hash = "node/" + encodeURIComponent(node.id); });
    $("nodes").append(button);
  }
  $("hybrids").replaceChildren();
  for (const hybrid of documentData.hybrids.classes.filter(item => item.masteries.includes(id))) {
    const card = element("section",undefined,"hybrid");
    const names = hybrid.masteries.map(mid => documentData.masteries.masteries.find(m => m.id === mid).name).join(" + ");
    card.append(element("h3",`${hybrid.name} · ${names}`),element("code",hybrid.id),element("p",`고유 특성 제안: ${hybrid.signature.name}`),element("code",hybrid.signature.id));
    for (const [label,value] of [["조건",hybrid.signature.trigger],["결과",hybrid.signature.effect],["대가",hybrid.signature.tradeoff],["반복 방지",hybrid.signature.anti_loop],["장비",hybrid.equipment_note],["플레이",hybrid.play_pattern],["구현 상태",hybrid.example.status]]) card.append(element("p",`${label}: ${value}`));
    const example = element("p","예시 액티브(장착 아님): ");
    hybrid.example.active_slots.forEach((reference,index) => { if(index) example.append(" / "); example.append(nodeLink(reference)); });
    card.append(example); $("hybrids").append(card);
  }
}
function followHash() {
  let id;
  try { id = decodeURIComponent(location.hash.replace(/^#node\//,"")); } catch { $("status").textContent="잘못된 링크 인코딩"; return; }
  if (!id) { restoreSummary(); showMastery(documentData.masteries.masteries[0].id); showNode(documentData.masteries.masteries[0].nodes[0].id); return; }
  if (ownerMap.has(id)) { restoreSummary(); if(selected !== ownerMap.get(id)) showMastery(ownerMap.get(id)); showNode(id); }
  else $("status").textContent = "존재하지 않는 노드 링크: " + id;
}
function showBuild(id) {
  const build = documentData.builds.scenarios.find(item => item.id === id);
  if (!build) return;
  for (const button of $("build-list").children) button.setAttribute("aria-pressed",String(button.dataset.id === id));
  const panel = $("build-detail");
  panel.replaceChildren(element("h3", build.title), element("code", build.id), element("p", "DRAFT · 향후 검증용 예시 · 현재 학습/전직/전투 미구현"));
  const masteryNames = build.active_masteries.map(mid => documentData.masteries.masteries.find(m => m.id === mid).name);
  panel.append(element("p",`${build.class_name} · ${masteryNames.join(" + ")} · 우선순위 제안 ${build.priority}`));
  const hybrid = documentData.hybrids.classes.find(item => item.id === build.class_id);
  panel.append(element("p", `조합 특성(액티브 슬롯 아님): ${hybrid.signature.name}`), element("code",build.identity_trait));
  panel.append(element("h4","선행을 포함한 학습 순서 — SP/단계 자격 미확정"));
  const order = element("ol");
  for (const id of build.learning_order) {
    const row = element("li"); row.append(nodeLink(id),` · ${typeNames[nodeMap.get(id).type]}`); order.append(row);
  }
  panel.append(order,element("h4","액티브 2슬롯 + 각 행동 변형 — 제안 조건"));
  build.active_slots.forEach((slot,index) => {
    const row = element("p",`슬롯 ${index+1}: `); row.append(nodeLink(slot.active)," → ");
    if(slot.modifier) row.append(nodeLink(slot.modifier)); else row.append("변형 없음"); panel.append(row);
  });
  for (const [label,value] of [["장비",build.equipment_note],["장비 태그",build.equipment_tags.join(" · ")],["약점",build.weakness],["기본 조작 대안",build.basic_alternative],["필요 구현",build.implementation_needed.join(" / ")]]) panel.append(element("p",`${label}: ${value}`));
  const context = build.context;
  panel.append(element("h4","테스트 맥락 — 현재 배치·재료 소비 조건 아님"));
  for (const [label,value] of [["몬스터",context.monster_ids],["장소",context.location_ids],["재료 참조",context.material_ids],["초안 참조",context.draft_refs]]) panel.append(element("p",`${label}: ${value.join(" · ") || "없음"}`));
  panel.append(element("p","선행 노드만 정적 검사했습니다. SP 투자량·단계 예산은 미정이며 전직 과제 완료는 향후 시험 fixture 가정입니다. 재료는 관찰/인벤토리 참조이지 스킬 비용이 아닙니다."));
  panel.append(element("h4",`${build.checklist.length}개 구현 검증 체크리스트 — 아직 실행 결과 아님`));
  for (const test of build.checklist) {
    const card = element("section",undefined,"build-case"); card.append(element("h4",test.id));
    for (const [key,label] of [["given","조건"],["action","조작"],["expected","기대"],["reject","거부할 결과"],["evidence","향후 증거"]]) card.append(element("p",`${label}: ${test[key]}`));
    panel.append(card);
  }
}
fetch("/api/catalog",{cache:"no-store"}).then(async response => {
  const value = await response.json(); if(!response.ok) throw Error(value.error || "초안 읽기 실패"); return value;
}).then(value => {
  documentData = value; nodeMap = new Map(); ownerMap = new Map();
  for (const mastery of value.masteries.masteries) {
    for (const node of mastery.nodes) { nodeMap.set(node.id,node); ownerMap.set(node.id,mastery.id); }
    const button = element("button",mastery.name); button.dataset.id=mastery.id;
    button.addEventListener("click",() => { showMastery(mastery.id); location.hash="node/"+encodeURIComponent(mastery.nodes[0].id); });
    $("masteries").append(button);
  }
  restoreSummary();
  $("sources").textContent=JSON.stringify({sources:value.sources,validation:value.validation,build_validation:value.build_validation},null,2);
  $("build-scope").textContent=value.builds.scope;
  $("build-boundary").textContent="미확정: "+value.builds.policy_boundary.unresolved.join(" / ");
  for (const check of value.builds.global_checks) $("build-global").append(element("li",check.check));
  for (const build of value.builds.scenarios) {
    const title=build.title.startsWith(build.class_name+": ") ? build.title.slice(build.class_name.length+2) : build.title;
    const button=element("button",`${build.class_name} · ${title}`); button.dataset.id=build.id;
    button.addEventListener("click",()=>showBuild(build.id)); $("build-list").append(button);
  }
  showBuild(value.builds.scenarios[0].id);
  addEventListener("hashchange",() => { followHash(); $("detail").scrollIntoView({block:"start"}); }); followHash();
}).catch(error => { $("status").textContent="검증 실패 — 도감 표시 중단: "+error.message; });
