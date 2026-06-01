import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/sync_service.dart';
import '../utils/money.dart';
import 'offline_tokens_screen.dart';

bool get _enableConversionForTesting => true;

class BalanceScreen extends ConsumerWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    final session = ref.watch(authSessionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: ref.read(connectivityServiceProvider).isOnline(),
          builder: (context, snapshot) {
            final isOnline = snapshot.data ?? false;
            final hasServerSession = session?.token.isNotEmpty ?? false;
            final enableConversionForTesting = _enableConversionForTesting;
            final canConvert =
                enableConversionForTesting || (isOnline && hasServerSession);
            final totalBalance = wallet.onlineBalance + wallet.offlineBalance;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _BalanceHeader(
                  onBack: () => Navigator.of(context).pop(),
                  isOnline: isOnline,
                ),
                const SizedBox(height: 14),
                _TotalBalanceCard(totalBalance: totalBalance),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceSplitCard(
                        title: 'Online',
                        amount: formatPaise(wallet.onlineBalance),
                        subtitle: 'Server-backed',
                        icon: Icons.cloud_done_rounded,
                        color: const Color(0xFF007A52),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _BalanceSplitCard(
                        title: 'Offline',
                        amount: formatPaise(wallet.offlineBalance),
                        subtitle: 'QR-ready',
                        icon: Icons.offline_bolt_rounded,
                        color: const Color(0xFF7347D9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _OfflineTokenToolCard(
                  enabled: canConvert,
                  statusText: _conversionStatusText(
                    isOnline: isOnline,
                    hasServerSession: hasServerSession,
                    enableConversionForTesting: enableConversionForTesting,
                    canConvert: canConvert,
                  ),
                  onTap: canConvert
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OfflineTokensScreen(),
                            ),
                          );
                        }
                      : null,
                ),
                const SizedBox(height: 14),
                _UserIdCard(userId: session?.userId ?? 'not-ready'),
              ],
            );
          },
        ),
      ),
    );
  }

  String _conversionStatusText({
    required bool isOnline,
    required bool hasServerSession,
    required bool enableConversionForTesting,
    required bool canConvert,
  }) {
    if (enableConversionForTesting && !(isOnline && hasServerSession)) {
      return 'Test mode is enabled for local token conversion.';
    }
    if (canConvert) {
      return 'Connected. You can mint offline tokens now.';
    }
    return 'Available when the wallet is connected to the server.';
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.onBack,
    required this.isOnline,
  });

  final VoidCallback onBack;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF0A2E20),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance Hub',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF0A2E20),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Online and offline spending power',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF687A72),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        _StatusPill(label: isOnline ? 'Online' : 'Local'),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF6F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF007A6B),
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.totalBalance});

  final int totalBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B28), Color(0xFF007A52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFC7FF18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                ),
                child: Text(
                  'OnPay',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'Total cash balance',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFBFF7D8),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            _formatRupee(totalBalance),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 0.98,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Combined online and offline wallet value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFCBEEDC),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BalanceSplitCard extends StatelessWidget {
  const _BalanceSplitCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEF1EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0A2E20),
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatRupeeText(amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF0A2E20),
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF687A72),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _OfflineTokenToolCard extends StatelessWidget {
  const _OfflineTokenToolCard({
    required this.enabled,
    required this.statusText,
    required this.onTap,
  });

  final bool enabled;
  final String statusText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? const [Color(0xFFA9ECE4), Color(0xFFDFF7E9)]
                  : const [Color(0xFFE8E8E4), Color(0xFFF2F2EF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  enabled ? const Color(0xFF75D8C9) : const Color(0xFFD8D8D3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xFF075A3D)
                      : const Color(0xFFBDBDB8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFFC7FF18),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline token tools',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF073B2A),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Convert online balance into offline tokens.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF21483A),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF007A52),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF073B2A),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserIdCard extends StatelessWidget {
  const _UserIdCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF1EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0F0),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.perm_identity_rounded,
              color: Color(0xFF0A2E20),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User ID',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF0A2E20),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  userId,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687A72),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRupee(int paise) {
  return _formatRupeeText(formatPaise(paise));
}

String _formatRupeeText(String value) {
  return value.replaceFirst('Rs.', '₹');
}
