import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/auth_provider.dart';
import '../providers/transactions_provider.dart';
import '../utils/money.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final transactions = [...ref.watch(transactionsProvider)]
      ..sort((a, b) => b.timestampUtc.compareTo(a.timestampUtc));
    final currentUserId = session?.userId ?? '';
    final spentToday = _sumSentToday(transactions, currentUserId);
    final spentRange = _sumSentInCurrentMonth(transactions, currentUserId);

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: ColoredBox(
              color: const Color(0xFFF8F8F6),
              child: Stack(
                children: [
                  Column(
                    children: [
                      _HistoryHeader(
                        spentRange: spentRange,
                        spentToday: spentToday,
                        accountName: session?.name ?? 'Personal',
                      ),
                      Expanded(
                        child: transactions.isEmpty
                            ? const _EmptyHistory()
                            : _TransactionList(
                                transactions: transactions,
                                currentUserId: currentUserId,
                              ),
                      ),
                    ],
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _HistoryNavBar(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _sumSentToday(
    List<WalletTransaction> transactions,
    String currentUserId,
  ) {
    final now = DateTime.now();
    return transactions.where((transaction) {
      final localTime = transaction.timestampUtc.toLocal();
      return _isSent(transaction, currentUserId) &&
          localTime.year == now.year &&
          localTime.month == now.month &&
          localTime.day == now.day;
    }).fold(0, (total, transaction) => total + transaction.amount);
  }

  int _sumSentInCurrentMonth(
    List<WalletTransaction> transactions,
    String currentUserId,
  ) {
    final now = DateTime.now();
    return transactions.where((transaction) {
      final localTime = transaction.timestampUtc.toLocal();
      return _isSent(transaction, currentUserId) &&
          localTime.year == now.year &&
          localTime.month == now.month;
    }).fold(0, (total, transaction) => total + transaction.amount);
  }

  bool _isSent(WalletTransaction transaction, String currentUserId) {
    if (currentUserId.isNotEmpty) {
      return transaction.fromUserId == currentUserId;
    }
    return transaction.direction == OfflineTransactionDirection.sent;
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.spentRange,
    required this.spentToday,
    required this.accountName,
  });

  final int spentRange;
  final int spentToday;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 244,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF38C2B5),
            Color(0xFF1B8D81),
            Color(0xFF0B594D),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFFAFE6DF),
                      child: Icon(Icons.currency_rupee_rounded,
                          size: 12, color: Color(0xFF0B594D)),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.menu_rounded, color: Colors.white, size: 17),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    accountName.isEmpty ? 'Personal' : accountName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.unfold_more_rounded,
                      color: Colors.white, size: 14),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 13),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B594D).withOpacity(0.34),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _HeaderMetric(
                      label: 'Spent this month',
                      amount: spentRange,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withOpacity(0.12),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: _HeaderMetric(
                        label: 'Spent today',
                        amount: spentToday,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withOpacity(0.58),
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          formatPaise(amount).replaceFirst('Rs.', '₹'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.transactions,
    required this.currentUserId,
  });

  final List<WalletTransaction> transactions;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDate(transactions);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 86),
      children: [
        Row(
          children: [
            Text(
              'Transactions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF006FD6),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.search_rounded, size: 17),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final group in groups) ...[
          _DateHeader(
            label: _formatDateHeading(group.date),
            netAmount: _netForDay(group.transactions, currentUserId),
          ),
          const SizedBox(height: 8),
          for (final transaction in group.transactions) ...[
            _TransactionRow(
              transaction: transaction,
              isOutgoing: _isOutgoing(transaction, currentUserId),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  List<_TransactionGroup> _groupByDate(List<WalletTransaction> transactions) {
    final grouped = <DateTime, List<WalletTransaction>>{};
    for (final transaction in transactions) {
      final localTime = transaction.timestampUtc.toLocal();
      final day = DateTime(localTime.year, localTime.month, localTime.day);
      grouped.putIfAbsent(day, () => []).add(transaction);
    }

    return grouped.entries
        .map((entry) => _TransactionGroup(entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int _netForDay(
    List<WalletTransaction> transactions,
    String currentUserId,
  ) {
    return transactions.fold(0, (total, transaction) {
      final signedAmount = _isOutgoing(transaction, currentUserId)
          ? -transaction.amount
          : transaction.amount;
      return total + signedAmount;
    });
  }

  bool _isOutgoing(WalletTransaction transaction, String currentUserId) {
    if (currentUserId.isNotEmpty) {
      return transaction.fromUserId == currentUserId;
    }
    return transaction.direction == OfflineTransactionDirection.sent;
  }
}

class _TransactionGroup {
  const _TransactionGroup(this.date, this.transactions);

  final DateTime date;
  final List<WalletTransaction> transactions;
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.label,
    required this.netAmount,
  });

  final String label;
  final int netAmount;

  @override
  Widget build(BuildContext context) {
    final isPositive = netAmount > 0;
    final amount = formatPaise(netAmount.abs()).replaceFirst('Rs.', '₹');

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6D6D6D),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          netAmount == 0 ? amount : '${isPositive ? '+' : '-'}$amount',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isPositive
                    ? const Color(0xFF007A3D)
                    : const Color(0xFF5C5C5C),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.isOutgoing,
  });

  final WalletTransaction transaction;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final localTime = transaction.timestampUtc.toLocal();
    final statusLabel = switch (transaction.status) {
      OfflineTransactionStatus.pendingSync => 'Pending sync',
      OfflineTransactionStatus.confirmed => 'Confirmed',
      OfflineTransactionStatus.rejected => 'Rejected',
    };
    final title = isOutgoing ? 'Payment sent' : 'Payment received';
    final amount = formatPaise(transaction.amount).replaceFirst('Rs.', '₹');
    final amountColor =
        isOutgoing ? const Color(0xFF111111) : const Color(0xFF007A3D);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isOutgoing
                  ? const Color(0xFFEAF2FF)
                  : const Color(0xFFEAF7F1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isOutgoing
                  ? Icons.offline_bolt_rounded
                  : Icons.account_balance_wallet_rounded,
              color: isOutgoing
                  ? const Color(0xFF3D7BD9)
                  : const Color(0xFF008553),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF151515),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatTime(localTime)} · $statusLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF707070),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${isOutgoing ? '-' : '+'}$amount',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 90),
      children: [
        Row(
          children: [
            Text(
              'Transactions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF111111),
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF006FD6),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.search_rounded, size: 17),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF008553),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No transactions yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sent and received payments will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF707070),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryNavBar extends StatelessWidget {
  const _HistoryNavBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        color: const Color(0xFFF8F8F6),
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.swap_horiz_rounded, label: 'Payments'),
            _NavItem(icon: Icons.bar_chart_rounded, label: 'Spending'),
            _NavItem(icon: Icons.home_filled, label: 'Home', active: true),
            _NavItem(icon: Icons.credit_card_rounded, label: 'Cards'),
            _NavItem(icon: Icons.grid_view_rounded, label: 'Spaces'),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF101010) : const Color(0xFF4A4A4A);

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

String _formatDateHeading(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
}

String _formatTime(DateTime date) {
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
