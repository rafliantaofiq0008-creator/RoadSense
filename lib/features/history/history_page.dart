import 'package:flutter/material.dart';

import '../../core/utils/app_date_time.dart';
import '../../data/models/road_session.dart';
import '../../data/remote/road_session_api.dart';
import '../../shared/widgets/app_surface_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../map/map_page.dart';
import '../trip_detail/trip_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final RoadSessionApi _sessionApi = RoadSessionApi();
  List<RoadSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _sessionApi.getSessionsForCurrentUser();
      if (mounted) {
        setState(() {
          _sessions = sessions;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDeleteSession(RoadSession session) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat trip?'),
        content: const Text(
          'Trip, data sensor, event, dan foto terkait akan dihapus permanen. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _sessionApi.deleteSession(session.id);
      await _loadSessions();
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Riwayat trip berhasil dihapus.')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus trip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppSurfaceCard(
          title: 'Belum ada trip',
          subtitle:
              'Mulai preview dan recording terlebih dahulu agar histori perjalanan muncul di sini.',
          accentColor: theme.colorScheme.primary,
          trailing: Icon(Icons.route_rounded, color: theme.colorScheme.primary),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Histori tersimpan otomatis setelah sesi selesai dan upload berhasil.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadSessions,
      child: ListView.builder(
        itemCount: _sessions.length,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final theme = Theme.of(context);
          final displayTitle = AppDateTime.displaySessionTitle(session);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.65,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDetailPage(sessionId: session.id),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 42,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayTitle,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Mulai ${AppDateTime.formatSession(session.startTime)}'
                                    '${session.endTime != null ? ' • Selesai ${AppDateTime.formatSession(session.endTime)}' : ''}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'map') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          MapPage(initialSessionId: session.id),
                                    ),
                                  );
                                  return;
                                }

                                if (value == 'delete') {
                                  _confirmDeleteSession(session);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'map',
                                  child: Text('Lihat di peta'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus riwayat'),
                                ),
                              ],
                              child: Icon(
                                Icons.more_horiz_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusBadge(
                              label:
                                  '${session.averageSpeed?.toStringAsFixed(1) ?? '0.0'} km/h avg',
                              color: theme.colorScheme.primary,
                              icon: Icons.speed_rounded,
                            ),
                            StatusBadge(
                              label:
                                  'Vib ${session.maxVibration?.toStringAsFixed(2) ?? '0.0'}',
                              color: theme.colorScheme.secondary,
                              icon: Icons.multiline_chart_rounded,
                            ),
                            StatusBadge(
                              label: '${session.totalEvents} event',
                              color: theme.colorScheme.tertiary,
                              icon: Icons.warning_amber_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoColumn(
                                  context,
                                  label: 'Durasi',
                                  value: session.endTime != null
                                      ? session.endTime!
                                                    .difference(
                                                      session.startTime,
                                                    )
                                                    .inMinutes <=
                                                0
                                            ? '< 1 menit'
                                            : '${session.endTime!.difference(session.startTime).inMinutes} menit'
                                      : 'Masih aktif',
                                ),
                              ),
                              Expanded(
                                child: _buildInfoColumn(
                                  context,
                                  label: 'Jarak',
                                  value:
                                      '${session.estimatedDistanceKm?.toStringAsFixed(2) ?? '0.00'} km',
                                ),
                              ),
                              Expanded(
                                child: _buildInfoColumn(
                                  context,
                                  label: 'Status',
                                  value: 'Saved to Cloud',
                                  highlight: theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MapPage(initialSessionId: session.id),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Peta'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _confirmDeleteSession(session),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Hapus'),
                              style: FilledButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                backgroundColor: theme
                                    .colorScheme
                                    .errorContainer
                                    .withValues(alpha: 0.42),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context, {
    required String label,
    required String value,
    Color? highlight,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: highlight ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
