import 'package:flutter/material.dart';
import '../models/transaction_template.dart';

class TemplateAmounts extends StatelessWidget {
  final int expense;
  final int income;

  const TemplateAmounts({
    super.key,
    required this.expense,
    required this.income,
  });

  Widget _buildAmount(
    BuildContext context,
    String label,
    int amount,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '￥${(amount / 100).toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: amount == 0 ? theme.colorScheme.onSurfaceVariant : color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAmount(context, '支出', expense, Colors.red),
        const SizedBox(width: 24),
        _buildAmount(context, '收入', income, Colors.green),
      ],
    );
  }
}

class TransactionTemplateTile extends StatelessWidget {
  final TransactionTemplate template;
  final VoidCallback? onTap;
  final Widget trailing;

  const TransactionTemplateTile({
    super.key,
    required this.template,
    required this.onTap,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${template.entries.length} 笔',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    trailing,
                  ],
                ),
                const SizedBox(height: 16),
                TemplateAmounts(
                  expense: template.totalExpense,
                  income: template.totalIncome,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
