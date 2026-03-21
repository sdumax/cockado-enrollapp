import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';
import 'package:cockado_enrollapp/core/services/connectivity_service.dart';
import 'sync_service.dart';
import 'sync_status_repository.dart';

enum _SyncUiState { loading, syncing, upToDate, offline, error }

class InitialisationScreen extends ConsumerStatefulWidget {
  const InitialisationScreen({super.key});

  @override
  ConsumerState<InitialisationScreen> createState() =>
      _InitialisationScreenState();
}

class _InitialisationScreenState extends ConsumerState<InitialisationScreen> {
  _SyncUiState _uiState = _SyncUiState.loading;
  int _current = 0;
  int _total = 0;
  String? _lastSyncedAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSync());
  }

  Future<void> _startSync() async {
    if (!mounted) return;

    setState(() {
      _uiState = _SyncUiState.loading;
      _errorMessage = null;
    });

    try {
      final isOnline = await ref.read(isOnlineProvider.future);

      if (!mounted) return;

      if (!isOnline) {
        final repo = ref.read(syncStatusRepositoryProvider);
        final lastSynced = await repo.getLastSyncedAt();
        if (!mounted) return;
        setState(() {
          _uiState = _SyncUiState.offline;
          _lastSyncedAt = lastSynced != null
              ? _formatTimestamp(lastSynced)
              : 'Never';
        });
        return;
      }

      final repo = ref.read(syncStatusRepositoryProvider);
      final eventId = await repo.getActiveEventId();

      if (!mounted) return;

      if (eventId == null) {
        context.go('/scan');
        return;
      }

      final syncService = ref.read(syncServiceProvider);
      final syncRequired = await syncService.isSyncRequired(eventId);

      if (!mounted) return;

      if (!syncRequired) {
        final lastSynced = await repo.getLastSyncedAt();
        if (!mounted) return;
        setState(() {
          _uiState = _SyncUiState.upToDate;
          _lastSyncedAt = lastSynced != null
              ? _formatTimestamp(lastSynced)
              : 'just now';
        });
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        context.go('/scan');
        return;
      }

      setState(() {
        _uiState = _SyncUiState.syncing;
        _current = 0;
        _total = 0;
      });

      await for (final progress in syncService.pullEnrollees(eventId)) {
        if (!mounted) return;
        setState(() {
          _current = progress.current;
          _total = progress.total;
        });
      }

      if (!mounted) return;
      context.go('/scan');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uiState = _SyncUiState.error;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatTimestamp(String iso8601) {
    final dt = DateTime.tryParse(iso8601);
    if (dt == null) return iso8601;

    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    String pad(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${pad(local.month)}-${pad(local.day)} '
        '${pad(local.hour)}:${pad(local.minute)}';
  }

  String _formatCount(int n) {
    if (n < 1000) return n.toString();
    final s = n.toString();
    final buf = StringBuffer();
    final offset = s.length % 3;
    for (var i = 0; i < s.length; i++) {
      if (i != 0 && (i - offset) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              _LogoHeader(),
              const SizedBox(height: 48),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_uiState) {
      case _SyncUiState.loading:
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),
          ),
        );

      case _SyncUiState.syncing:
        return _SyncingBody(
          current: _current,
          total: _total,
          formatCount: _formatCount,
        );

      case _SyncUiState.upToDate:
        return _UpToDateBody(lastSyncedAt: _lastSyncedAt);

      case _SyncUiState.offline:
        return _OfflineBody(
          lastSyncedAt: _lastSyncedAt,
          onContinue: () => context.go('/scan'),
        );

      case _SyncUiState.error:
        return _ErrorBody(
          message: _errorMessage,
          onRetry: _startSync,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Shared header
// ---------------------------------------------------------------------------

class _LogoHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/church_logo.png',
          width: 44,
          height: 44,
        ),
        const SizedBox(width: 12),
        const Text(
          'COC-CHECKIN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Syncing body
// ---------------------------------------------------------------------------

class _SyncingBody extends StatelessWidget {
  const _SyncingBody({
    required this.current,
    required this.total,
    required this.formatCount,
  });

  final int current;
  final int total;
  final String Function(int) formatCount;

  double get _progress =>
      (total > 0) ? (current / total).clamp(0.0, 1.0) : 0.0;

  String get _statusMessage {
    if (total == 0) return 'Preparing download...';
    if (_progress < 0.4) return 'Downloading enrollment records...';
    if (_progress < 0.75) return 'Downloading face recognition data...';
    if (_progress < 1.0) return 'Finalising sync...';
    return 'Sync complete.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'SYNCING DATA',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: 4,
            width: double.infinity,
            child: LinearProgressIndicator(
              value: total > 0 ? _progress : null,
              backgroundColor: AppColors.darkCard,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.blue),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          total > 0
              ? '${formatCount(current)} / ${formatCount(total)} ENROLLEES'
              : 'Preparing...',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Up-to-date body
// ---------------------------------------------------------------------------

class _UpToDateBody extends StatelessWidget {
  const _UpToDateBody({this.lastSyncedAt});

  final String? lastSyncedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 64,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        const Text(
          'UP TO DATE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Last synced ${lastSyncedAt ?? 'just now'}',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Offline body
// ---------------------------------------------------------------------------

class _OfflineBody extends StatelessWidget {
  const _OfflineBody({
    required this.lastSyncedAt,
    required this.onContinue,
  });

  final String? lastSyncedAt;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'WORKING OFFLINE',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Last synced: ${lastSyncedAt ?? 'Never'}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'CONTINUE WITH CACHED DATA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'SYNC FAILED',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'RETRY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
