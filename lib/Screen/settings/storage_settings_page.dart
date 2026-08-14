import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:cuqter/services/local_storage_service.dart';

class StorageDetails {
  final int size;
  final int count;
  const StorageDetails(this.size, this.count);
}

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  int _photoSize = 0;
  int _videoSize = 0;
  int _audioSize = 0;
  int _docSize = 0;
  int _cacheSize = 0;
  int _totalSize = 0;

  int _photoCount = 0;
  int _videoCount = 0;
  int _audioCount = 0;
  int _docCount = 0;
  int _cacheCount = 0;
  
  bool _isLoading = true;
  bool _useLessData = false;
  bool _autoDownloadMedia = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _calculateStorageSizes();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _useLessData = prefs.getBool('storage_use_less_data') ?? false;
        _autoDownloadMedia = prefs.getBool('storage_auto_download_media') ?? true;
      });
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving preference: $e');
    }
  }

  Future<void> _calculateStorageSizes({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final photoPath = await LocalStorageService.getLocalFolderPath('image');
      final videoPath = await LocalStorageService.getLocalFolderPath('video');
      final audioPath = await LocalStorageService.getLocalFolderPath('audio');
      final docPath = await LocalStorageService.getLocalFolderPath('document');

      final photoDetails = await _getFolderSize(photoPath);
      final videoDetails = await _getFolderSize(videoPath);
      final audioDetails = await _getFolderSize(audioPath);
      final docDetails = await _getFolderSize(docPath);
      final cacheDetails = await _getCacheSize();

      if (mounted) {
        setState(() {
          _photoSize = photoDetails.size;
          _photoCount = photoDetails.count;

          _videoSize = videoDetails.size;
          _videoCount = videoDetails.count;

          _audioSize = audioDetails.size;
          _audioCount = audioDetails.count;

          _docSize = docDetails.size;
          _docCount = docDetails.count;

          _cacheSize = cacheDetails.size;
          _cacheCount = cacheDetails.count;

          _totalSize = _photoSize + _videoSize + _audioSize + _docSize + _cacheSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error calculating storage sizes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<StorageDetails> _getFolderSize(String? path) async {
    if (path == null) return const StorageDetails(0, 0);
    int totalSize = 0;
    int fileCount = 0;
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await for (final file in dir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
            fileCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting folder size for path $path: $e');
    }
    return StorageDetails(totalSize, fileCount);
  }

  Future<StorageDetails> _getCacheSize() async {
    int totalSize = 0;
    int fileCount = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final file in tempDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalSize += await file.length();
            fileCount++;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting cache size: $e');
    }
    return StorageDetails(totalSize, fileCount);
  }

  String _formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Future<void> _clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final entities = tempDir.listSync(recursive: false);
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } catch (e) {
            debugPrint('Failed to delete cache entity: $e');
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary cache cleared successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }

    await _calculateStorageSizes(showLoader: false);
  }

  Future<void> _clearLocalDownloads() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: huge.HugeIcon(
                  icon: huge.HugeIcons.strokeRoundedDelete02,
                  color: colorScheme.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Delete downloaded media?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This will permanently delete all downloaded files (photos, videos, audio, and documents) saved by Cuqter on your device. You can download them again from chats at any time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.error,
                    foregroundColor: colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    foregroundColor: colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        final photoPath = await LocalStorageService.getLocalFolderPath('image');
        final videoPath = await LocalStorageService.getLocalFolderPath('video');
        final audioPath = await LocalStorageService.getLocalFolderPath('audio');
        final docPath = await LocalStorageService.getLocalFolderPath('document');

        final paths = [photoPath, videoPath, audioPath, docPath];
        for (var path in paths) {
          if (path != null) {
            final dir = Directory(path);
            if (await dir.exists()) {
              await for (final file in dir.list(recursive: true, followLinks: false)) {
                if (file is File) {
                  try {
                    await file.delete();
                  } catch (e) {
                    debugPrint('Error deleting download file: $e');
                  }
                }
              }
            }
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All local downloaded media deleted')),
          );
        }
      } catch (e) {
        debugPrint('Error deleting local downloaded media: $e');
      }

      await _calculateStorageSizes(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Storage & Data',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 20),
                _buildUsageCard(colorScheme),
                const SizedBox(height: 30),
                _buildSectionLabel('STORAGE BREAKDOWN'),
                const SizedBox(height: 10),
                _buildGroupedSection(children: [
                  _buildStorageBreakdownTile(
                    icon: huge.HugeIcons.strokeRoundedImage01,
                    title: 'Photos',
                    size: _photoSize,
                    fileCount: _photoCount,
                    color: Colors.blueAccent,
                  ),
                  _buildStorageBreakdownTile(
                    icon: huge.HugeIcons.strokeRoundedVideo01,
                    title: 'Videos',
                    size: _videoSize,
                    fileCount: _videoCount,
                    color: Colors.redAccent,
                  ),
                  _buildStorageBreakdownTile(
                    icon: huge.HugeIcons.strokeRoundedCall,
                    title: 'Voice & Audio',
                    size: _audioSize,
                    fileCount: _audioCount,
                    color: Colors.greenAccent,
                  ),
                  _buildStorageBreakdownTile(
                    icon: huge.HugeIcons.strokeRoundedDocumentCode,
                    title: 'Documents & Files',
                    size: _docSize,
                    fileCount: _docCount,
                    color: Colors.orangeAccent,
                  ),
                  _buildStorageBreakdownTile(
                    icon: huge.HugeIcons.strokeRoundedDatabase,
                    title: 'Cached Data',
                    size: _cacheSize,
                    fileCount: _cacheCount,
                    color: Colors.purpleAccent,
                  ),
                ]),
                const SizedBox(height: 30),
                _buildSectionLabel('NETWORK & DATA CONTROLS'),
                const SizedBox(height: 10),
                _buildGroupedSection(children: [
                  _buildSwitchTile(
                    icon: huge.HugeIcons.strokeRoundedDownload02,
                    title: 'Auto-Download Media',
                    subtitle: 'Automatically save incoming media to local storage',
                    value: _autoDownloadMedia,
                    onChanged: (val) {
                      setState(() {
                        _autoDownloadMedia = val;
                      });
                      _savePreference('storage_auto_download_media', val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: huge.HugeIcons.strokeRoundedDatabase,
                    title: 'Use Less Data',
                    subtitle: 'Optimize media upload quality for poor connections',
                    value: _useLessData,
                    onChanged: (val) {
                      setState(() {
                        _useLessData = val;
                      });
                      _savePreference('storage_use_less_data', val);
                    },
                  ),
                ]),
                const SizedBox(height: 30),
                _buildSectionLabel('MANAGEMENT ACTIONS'),
                const SizedBox(height: 10),
                _buildGroupedSection(children: [
                  _buildActionTile(
                    icon: huge.HugeIcons.strokeRoundedClean,
                    title: 'Clear Temporary Cache',
                    subtitle: 'Free up local space without deleting downloaded files',
                    onTap: _clearCache,
                    textColor: colorScheme.primary,
                  ),
                  _buildActionTile(
                    icon: huge.HugeIcons.strokeRoundedDelete02,
                    title: 'Delete All Downloaded Media',
                    subtitle: 'Permanently remove downloads from your device',
                    onTap: _clearLocalDownloads,
                    textColor: colorScheme.error,
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildSectionLabel(String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildGroupedSection({required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildUsageCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.7),
            colorScheme.tertiaryContainer.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          huge.HugeIcon(
            icon: huge.HugeIcons.strokeRoundedHardDrive,
            color: colorScheme.primary,
            size: 40,
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Storage Used',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _formatBytes(_totalSize),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: colorScheme.primary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Keep your storage clean to maintain app performance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          _buildSegmentBar(colorScheme),
        ],
      ),
    );
  }

  Widget _buildSegmentBar(ColorScheme colorScheme) {
    if (_totalSize == 0) return const SizedBox.shrink();

    final photoRatio = _photoSize / _totalSize;
    final videoRatio = _videoSize / _totalSize;
    final audioRatio = _audioSize / _totalSize;
    final docRatio = _docSize / _totalSize;
    final cacheRatio = _cacheSize / _totalSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.fastOutSlowIn,
            builder: (context, val, child) {
              return FractionallySizedBox(
                widthFactor: val,
                alignment: Alignment.centerLeft,
                child: child,
              );
            },
            child: Container(
              height: 10,
              width: double.infinity,
              color: colorScheme.onSurface.withValues(alpha: 0.1),
              child: Row(
                children: [
                  _buildBarSegment(photoRatio, Colors.blueAccent),
                  _buildBarSegment(videoRatio, Colors.redAccent),
                  _buildBarSegment(audioRatio, Colors.greenAccent),
                  _buildBarSegment(docRatio, Colors.orangeAccent),
                  _buildBarSegment(cacheRatio, Colors.purpleAccent),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(colorScheme),
      ],
    );
  }

  Widget _buildBarSegment(double ratio, Color color) {
    if (ratio == 0) return const SizedBox.shrink();
    return Expanded(
      flex: (ratio * 1000).round().clamp(1, 1000),
      child: Container(
        color: color,
      ),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem('Photos', _photoSize, Colors.blueAccent),
        _buildLegendItem('Videos', _videoSize, Colors.redAccent),
        _buildLegendItem('Audio', _audioSize, Colors.greenAccent),
        _buildLegendItem('Docs', _docSize, Colors.orangeAccent),
        _buildLegendItem('Cache', _cacheSize, Colors.purpleAccent),
      ],
    );
  }

  Widget _buildLegendItem(String label, int size, Color color) {
    if (size == 0) return const SizedBox.shrink();
    final percentage = _totalSize > 0 ? (size / _totalSize * 100).toStringAsFixed(1) : '0';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($percentage%)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildStorageBreakdownTile({
    required List<List<dynamic>> icon,
    required String title,
    required int size,
    required int fileCount,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: ListTile(
        onTap: () => _showBreakdownDetailSheet(title, icon, size, fileCount, color),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: huge.HugeIcon(icon: icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatBytes(size),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            huge.HugeIcon(
              icon: huge.HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _showBreakdownDetailSheet(
    String title,
    List<List<dynamic>> icon,
    int size,
    int fileCount,
    Color color,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percentage = _totalSize > 0 ? (size / _totalSize) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: huge.HugeIcon(icon: icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Storage breakdown details',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: percentage),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.fastOutSlowIn,
                builder: (context, value, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 12,
                          backgroundColor: colorScheme.onSurface.withValues(alpha: 0.05),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(value * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'of total app space',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildDetailCard(
                      label: 'Storage Used',
                      value: _formatBytes(size),
                      icon: huge.HugeIcons.strokeRoundedHardDrive,
                      colorScheme: colorScheme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDetailCard(
                      label: 'Total Files',
                      value: '$fileCount files',
                      icon: huge.HugeIcons.strokeRoundedFolder01,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailCard({
    required String label,
    required String value,
    required List<List<dynamic>> icon,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          huge.HugeIcon(
            icon: icon,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required List<List<dynamic>> icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: huge.HugeIcon(icon: icon, color: colorScheme.primary, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
      ),
    );
  }

  Widget _buildActionTile({
    required List<List<dynamic>> icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: huge.HugeIcon(icon: icon, color: textColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        onTap: onTap,
      ),
    );
  }
}
