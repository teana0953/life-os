## Context

延續 #78(今日照護上總覽)。使用者兩個新訴求:照護提醒管理太深、以及通知沒開時提醒收不到卻
無提示。定案不合併提醒設定。完整理由見
`docs/superpowers/specs/2026-07-24-surface-care-reminders-and-push-hint-design.md`。

## Decisions

- **不合併提醒設定**:`ReminderSettingsScreen`/`/reminders`/更多 tile 全保留。提醒設定與
  照護提醒管理維持兩個入口,但管理畫面「知道」推播狀態並在未開時提示 → 用連結(push route)
  串起兩者,而非把設定卡塞進管理畫面。
- **`pushOn` 判定**:`status == enabled` 不足以判斷(load() 在上次 session 已訂閱時回 idle)。
  併看 `_gateway.permissionStatus() == granted`。新增唯讀 getter,不改 enable/test 邏輯。
  banner 條件 = `!pushOn`;單一文案涵蓋 denied/prompt/unsupported,細節導引交給 `/reminders`。
  **已知近似(YAGNI)**:`permission==granted` 是「曾授權/訂閱」的 proxy,非「目前訂閱仍有效」;
  若訂閱被瀏覽器 prune 或授權後訂閱失敗,banner 會被抑制而提醒其實送不到。此近似可接受(不引入
  訂閱有效性查核);spec 明確把「已開」定義成此 getter,保持可測。
- **總覽卡 no-schedule 由「隱藏」改「slim CTA」**:這是 #78 明確的設計選擇(當時為零雜訊),
  現因「新使用者要能從總覽找到設定」而反轉——但只在 **loaded 且 slots 空** 時顯示 CTA;
  loading/error/reauth 仍不顯示,維持不阻斷總覽其他卡。需同步改 #78 的對應測試(原斷言不顯示)。
- **卡片用 callback 注入導覽**:卡片新增 `onManage`(標題列管理)與 `onSetup`(空狀態 CTA)
  callback,由 `_OverviewBody` 提供 `context.push('/care-items')`——與 #78「就地動作走
  controller、導覽走 callback/push」一致,保持卡片可測。
- **care-items 只讀推播狀態**:注入 `ReminderSettingsController` 僅為讀 `pushOn` 顯示 banner;
  不觸發 enable/test(那仍是 `/reminders` 的職責),避免把兩個畫面的責任攪在一起。

## Out of scope

不合併提醒設定;不動後端/推播邏輯/底部導覽;不移除更多分頁的「照護提醒」與「提醒設定」tile。
