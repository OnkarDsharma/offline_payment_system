import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import 'balance_screen.dart';
import 'history_screen.dart';
import 'online_payment_screen.dart';
import 'receive_screen.dart';
import 'send_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final appMode = ref.watch(appModeProvider);
    final isOnline = appMode == AppMode.online;
    final isSyncing = appMode == AppMode.syncing || appMode == AppMode.checking;
    final walletLabel = session?.name.isNotEmpty == true
        ? session!.name
        : 'Wallet ${session?.userId.split('_').last ?? '4206'}';
    final walletId = session?.userId ?? 'local_wallet';

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF163B28),
                        Color(0xFF005E36),
                        Color(0xFF0EA96B),
                      ],
                      stops: [0, 0.58, 1],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      _HeroHeader(
                        mode: appMode,
                        walletLabel: walletLabel,
                        onSync: isSyncing ? null : () => _syncNow(context, ref),
                      ),
                      const SizedBox(height: 16),
                      _WalletPreviewCard(
                        walletId: walletId,
                        isOnline: isOnline,
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAF7),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      children: [
                        _FeatureBanner(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BalanceScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _SectionTitle(title: 'Quick Pay'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _QuickPayAction(
                              icon: Icons.cloud_upload_rounded,
                              label: 'Send Online',
                              backgroundColor: const Color(0xFFDFF6F5),
                              iconColor: const Color(0xFF007A6B),
                              onTap: isOnline
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const OnlinePaymentScreen(),
                                        ),
                                      )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            _QuickPayAction(
                              icon: Icons.qr_code_scanner_rounded,
                              label: 'Send Offline',
                              backgroundColor: const Color(0xFFEDE7FF),
                              iconColor: const Color(0xFF7347D9),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SendScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _QuickPayAction(
                              icon: Icons.qr_code_2_rounded,
                              label: 'Receive',
                              backgroundColor: const Color(0xFFDFF7E9),
                              iconColor: const Color(0xFF0A7F44),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ReceiveScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _QuickPayAction(
                              icon: Icons.sync_rounded,
                              label: isSyncing ? 'Checking' : 'Sync',
                              backgroundColor: const Color(0xFFFFF0D8),
                              iconColor: const Color(0xFFE8862F),
                              onTap: isSyncing
                                  ? null
                                  : () => _syncNow(context, ref),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _SectionTitle(
                          title: 'Your Wallet',
                          actionLabel: walletId,
                        ),
                        const SizedBox(height: 12),
                        _WalletAction(
                          icon: Icons.account_balance_rounded,
                          title: 'View balances',
                          subtitle: 'Track online and offline spending power',
                          badge: isOnline ? 'Live' : 'Local',
                          accent: const Color(0xFF007A52),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BalanceScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _WalletAction(
                          icon: Icons.history_rounded,
                          title: 'Transaction history',
                          subtitle:
                              'See sent, received, and pending sync activity',
                          badge: 'Ledger',
                          accent: const Color(0xFF0B66C3),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomNavBar(),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(appModeProvider.notifier).syncNow();
      if (!context.mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to sync.')),
        );
        return;
      }

      final synced = result['synced'] ?? 0;
      final rejected = result['rejected'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync finished. Synced: $synced, Rejected: $rejected'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: ${error.toString()}')),
      );
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.mode,
    required this.walletLabel,
    required this.onSync,
  });

  final AppMode mode;
  final String walletLabel;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () {},
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size.square(36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.notifications_none_rounded, size: 22),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onSync,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.sync_rounded, size: 15),
              label: const Text('Sync'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'OnPay',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              child: Text(
                walletLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            _StatusPill(mode: mode),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Pay online, offline, or by QR without putting your balance on display.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFFBFF7D8),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      AppMode.online => 'Online',
      AppMode.offline => 'Offline',
      AppMode.syncing => 'Syncing',
      AppMode.checking => 'Checking',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.32)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _WalletPreviewCard extends StatelessWidget {
  const _WalletPreviewCard({
    required this.walletId,
    required this.isOnline,
  });

  final String walletId;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Wallet',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF0A2E20),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 18),
          Text(
            walletId,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0A2E20),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isOnline ? 'Ready for live sync' : 'Offline mode ready',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4F665C),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBanner extends StatelessWidget {
  const _FeatureBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFA9ECE4),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pay Unplugged',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: const Color(0xFF073B2A),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your offline wallet stays ready when the network drops.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF073B2A),
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'See wallet tools',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF004C36),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF075A3D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_card_rounded,
                  color: Color(0xFF42F090),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0A2E20),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        if (actionLabel != null)
          Flexible(
            child: Text(
              actionLabel!,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF007A52),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
      ],
    );
  }
}

class _QuickPayAction extends StatelessWidget {
  const _QuickPayAction({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 27),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF102A20),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.16)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF0A2E20),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF687A72),
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 74,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(icon: Icons.home_filled, label: 'Home', active: true),
            _NavItem(icon: Icons.swap_horiz_rounded, label: 'Move'),
            _NavItem(icon: Icons.qr_code_rounded, label: 'Pay'),
            _NavItem(icon: Icons.star_border_rounded, label: 'Deals'),
            _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
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
    final color = active ? const Color(0xFF006B45) : const Color(0xFF0A2E20);

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}
