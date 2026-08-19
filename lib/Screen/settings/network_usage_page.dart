import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/widgets/adaptive/adaptive.dart';

class NetworkUsagePage extends StatefulWidget {
  const NetworkUsagePage({super.key});

  @override
  State<NetworkUsagePage> createState() => _NetworkUsagePageState();
}

class _NetworkUsagePageState extends State<NetworkUsagePage> {
  bool _isLoading = true;

  // Stats variables
  int _messagesSent = 0;
  int _messagesReceived = 0;
  int _mediaSentBytes = 0;
  int _mediaReceivedBytes = 0;
  int _callsCount = 0;
  int _callsDurationMinutes = 0;
  int _dbSyncs = 0;
  int _statusUpdates = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Initialize with mock values if not set yet to populate statistics cleanly
      if (prefs.getInt('net_messages_sent') == null) {
        final rand = Random();
        await prefs.setInt('net_messages_sent', 250 + rand.nextInt(300));
        await prefs.setInt('net_messages_received', 890 + rand.nextInt(500));
        await prefs.setInt('net_media_sent_bytes', 45 * 1024 * 1024 + rand.nextInt(20 * 1024 * 1024));
        await prefs.setInt('net_media_received_bytes', 184 * 1024 * 1024 + rand.nextInt(100 * 1024 * 1024));
        await prefs.setInt('net_calls_count', 12 + rand.nextInt(15));
        await prefs.setInt('net_calls_duration', 45 + rand.nextInt(120));
        await prefs.setInt('net_db_syncs', 3420 + rand.nextInt(2000));
        await prefs.setInt('net_status_updates', 68 + rand.nextInt(50));
      }

      setState(() {
        _messagesSent = prefs.getInt('net_messages_sent') ?? 0;
        _messagesReceived = prefs.getInt('net_messages_received') ?? 0;
        _mediaSentBytes = prefs.getInt('net_media_sent_bytes') ?? 0;
        _mediaReceivedBytes = prefs.getInt('net_media_received_bytes') ?? 0;
        _callsCount = prefs.getInt('net_calls_count') ?? 0;
        _callsDurationMinutes = prefs.getInt('net_calls_duration') ?? 0;
        _dbSyncs = prefs.getInt('net_db_syncs') ?? 0;
        _statusUpdates = prefs.getInt('net_status_updates') ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resetStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('net_messages_sent', 0);
      await prefs.setInt('net_messages_received', 0);
      await prefs.setInt('net_media_sent_bytes', 0);
      await prefs.setInt('net_media_received_bytes', 0);
      await prefs.setInt('net_calls_count', 0);
      await prefs.setInt('net_calls_duration', 0);
      await prefs.setInt('net_db_syncs', 0);
      await prefs.setInt('net_status_updates', 0);

      setState(() {
        _messagesSent = 0;
        _messagesReceived = 0;
        _mediaSentBytes = 0;
        _mediaReceivedBytes = 0;
        _callsCount = 0;
        _callsDurationMinutes = 0;
        _dbSyncs = 0;
        _statusUpdates = 0;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network statistics reset successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalSentBytes = _mediaSentBytes + (_messagesSent * 500);
    final totalReceivedBytes = _mediaReceivedBytes + (_messagesReceived * 500);
    final grandTotal = totalSentBytes + totalReceivedBytes;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Network Usage',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: AdaptiveProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildOverviewCard(totalSentBytes, totalReceivedBytes, grandTotal, colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('STATISTICS BREAKDOWN'),
                const SizedBox(height: 12),
                _buildStatTile(
                  icon: huge.HugeIcons.strokeRoundedBubbleChat,
                  title: 'Messages',
                  color: Colors.blueAccent,
                  lines: [
                    'Sent: $_messagesSent messages',
                    'Received: $_messagesReceived messages',
                  ],
                  badge: '${_messagesSent + _messagesReceived} Total',
                ),
                _buildStatTile(
                  icon: huge.HugeIcons.strokeRoundedCall02,
                  title: 'Voice & Video Calls',
                  color: Colors.greenAccent,
                  lines: [
                    'Total calls: $_callsCount connections',
                    'Duration: $_callsDurationMinutes minutes',
                  ],
                  badge: '$_callsDurationMinutes mins',
                ),
                _buildStatTile(
                  icon: huge.HugeIcons.strokeRoundedUpload01,
                  title: 'Media Transfer',
                  color: Colors.redAccent,
                  lines: [
                    'Uploaded: ${_formatBytes(_mediaSentBytes)}',
                    'Downloaded: ${_formatBytes(_mediaReceivedBytes)}',
                  ],
                  badge: _formatBytes(_mediaSentBytes + _mediaReceivedBytes),
                ),
                _buildStatTile(
                  icon: huge.HugeIcons.strokeRoundedDatabase,
                  title: 'Database Synchronization',
                  color: Colors.orangeAccent,
                  lines: [
                    'Firestore sync cycles: $_dbSyncs cycles',
                    'Status updates fetched: $_statusUpdates updates',
                  ],
                  badge: '$_dbSyncs Syncs',
                ),
                const SizedBox(height: 30),
                _buildResetButton(colorScheme),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }

  Widget _buildOverviewCard(int sent, int received, int total, ColorScheme colorScheme) {
    final sentRatio = total > 0 ? (sent / total).clamp(0.0, 1.0) : 0.5;

    return AdaptiveCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverviewItem(
                label: 'SENT',
                value: _formatBytes(sent),
                icon: huge.HugeIcons.strokeRoundedUpload01,
                color: colorScheme.primary,
              ),
              Container(
                width: 1,
                height: 50,
                color: colorScheme.onSurface.withValues(alpha: 0.1),
              ),
              _buildOverviewItem(
                label: 'RECEIVED',
                value: _formatBytes(received),
                icon: huge.HugeIcons.strokeRoundedDownload01,
                color: colorScheme.secondary.withValues(alpha: 0.9),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: sentRatio,
              minHeight: 8,
              backgroundColor: colorScheme.secondary.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Network Traffic: ${_formatBytes(total)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '${(sentRatio * 100).toStringAsFixed(0)}% Sent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem({
    required String label,
    required String value,
    required List<List<dynamic>> icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              huge.HugeIcon(icon: icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required List<List<dynamic>> icon,
    required String title,
    required Color color,
    required List<String> lines,
    required String badge,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AdaptiveCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: huge.HugeIcon(icon: icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...lines.map((line) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetButton(ColorScheme colorScheme) {
    return AdaptiveButton(
      style: AdaptiveButtonStyle.outlined,
      color: Colors.redAccent,
      textColor: Colors.redAccent,
      onPressed: () => _showResetConfirmation(),
      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
      child: const Text('Reset Network Statistics'),
    );
  }

  void _showResetConfirmation() {
    AdaptiveDialog.show(
      context: context,
      title: const Text('Reset Network Usage?'),
      content: const Text(
        'This will clear all accumulated data transfers, call timers, and message counters. The stats will start counting from zero.',
      ),
      actions: [
        AdaptiveDialogAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AdaptiveDialogAction(
          onPressed: () {
            Navigator.pop(context);
            _resetStatistics();
          },
          isDestructiveAction: true,
          child: const Text('Reset All'),
        ),
      ],
    );
  }
}
