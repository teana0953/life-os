# 设计:托盘加入回馈(tray-add-scroll-feedback,方案 A)

## 问题
食物搜寻页点搜寻结果 → 项目 append 到托盘尾端;托盘是固定高 260px 的 `ListView.builder`,没有 ScrollController、不会自动卷到新项目。托盘一旦有 2~3 项,新加的落在卷轴下方看不到 → 使用者「以为没加入成功」。加入当下缺少「东西动了」的回馈。

## 方案 A(纯 presentation 层)
1. **加入讯号**:`CreateMealController`(ChangeNotifier)在 `add`/`addManual` 时记录「刚加入的那笔」——一个会递增的 `addTick`(int)+ `lastAdded`(TrayEntry?)。remove / 改数量**不触发**。这是 view 区分「真的新增」vs remove/改量的干净、可测讯号。
2. **自动卷动**:`_TrayPanel` 由 `StatelessWidget` 改为 `StatefulWidget`,持有 `ScrollController`;监听 controller,侦测到新 add(addTick 变化)就 `WidgetsBinding.instance.addPostFrameCallback` → `animateTo(maxScrollExtent)` 短动画卷到最新列(托盘没溢出时 clamp 成 no-op)。
3. **浅高亮**:剛加入那列背景用淡出动画,从主色/accent 低透明度 → 透明,约 0.9s。只有 addTick 指向的那笔会亮。

## 架构
全在 presentation 层,遵守 CLAUDE.md:controller 是 presentation 的 ChangeNotifier(加讯号栏位属 presentation 状态,合规);颜色一律走 `Theme.of(context)`,不写死 hex。domain/application/infrastructure 不动,DTO/API 不动。

## 验收(TDD)
- **自动卷动**:加到托盘溢出后再加一笔 → 断言卷动到底、最新列可见(scroll offset 近 maxScrollExtent,或最新 `tray-item-N` key 在视窗内)。
- **高亮**:新列加入当下有高亮色,过了 fade 时长后回透明。
- **两条路径都涵盖**:点搜寻结果(`add`)、手动输入 dialog(`addManual`)。
- **不回归**:remove / 改数量**不**触发卷动或高亮;既有托盘、AmountStepper、remove 测试仍过。

## 范围
`food_search_screen.dart`(`_TrayPanel` stateful + ScrollController + 高亮)、`create_meal_controller.dart`(加入讯号)、相关 widget 测试。

## 取舍
controller 加一个 presentation 用的「加入讯号」栏位是必要的(view 才能区分 add vs remove/改量);最小且可测,不算过度设计。高亮用低透明度主色淡出,与 Chiikawa 调性一致、不吵。
