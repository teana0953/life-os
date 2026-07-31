/// Shared by [FinanceCategory] and [FinanceTransaction] — a category's type
/// and the type of any transaction filed under it must match (enforced by
/// the backend).
enum FinanceType { expense, income }

FinanceType financeTypeFromJson(String value) =>
    value == 'income' ? FinanceType.income : FinanceType.expense;

String financeTypeToJson(FinanceType type) =>
    type == FinanceType.income ? 'income' : 'expense';
