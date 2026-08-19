import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart' as huge;
import 'package:open_filex/open_filex.dart';
import 'package:cuqter/services/local_storage_service.dart';

class StorageFileManagerPage extends StatefulWidget {
  final String title;
  final String fileType; // 'image', 'video', 'audio', 'document'

  const StorageFileManagerPage({
    super.key,
    required this.title,
    required this.fileType,
  });

  @override
  State<StorageFileManagerPage> createState() => _StorageFileManagerPageState();
}

class _StorageFileManagerPageState extends State<StorageFileManagerPage> {
  List<File> _files = [];
  bool _isLoading = true;
  bool _isSelecting = false;
  final Set<String> _selectedFilePaths = {};

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final path = await LocalStorageService.getLocalFolderPath(widget.fileType);
      if (path != null) {
        final dir = Directory(path);
        if (await dir.exists()) {
          final entities = dir.listSync(recursive: true, followLinks: false);
          final files = entities.whereType<File>().toList();
          // Sort by modified date, newest first
          files.sort((a, b) {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.modified.compareTo(aStat.modified);
          });
          setState(() {
            _files = files;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading files for ${widget.fileType}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedFilePaths.contains(path)) {
        _selectedFilePaths.remove(path);
        if (_selectedFilePaths.isEmpty) {
          _isSelecting = false;
        }
      } else {
        _selectedFilePaths.add(path);
      }
    });
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFilePaths.isEmpty) return;

    final colorScheme = Theme.of(context).colorScheme;
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
              Text(
                'Delete ${_selectedFilePaths.length} items?',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
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
                      child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      for (final path in _selectedFilePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('Error deleting file: $e');
        }
      }
      
      setState(() {
        _selectedFilePaths.clear();
        _isSelecting = false;
      });
      await _loadFiles();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected files deleted')),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Widget _buildFileThumbnail(File file, ColorScheme colorScheme) {
    if (widget.fileType == 'image') {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      List<List<dynamic>> icon;
      if (widget.fileType == 'video') {
        icon = huge.HugeIcons.strokeRoundedVideo01;
      } else if (widget.fileType == 'audio') {
        icon = huge.HugeIcons.strokeRoundedMusicNote01;
      } else {
        icon = huge.HugeIcons.strokeRoundedDocumentCode;
      }

      return Container(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: Center(
          child: huge.HugeIcon(
            icon: icon,
            color: colorScheme.primary,
            size: 40,
          ),
        ),
      );
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
          _isSelecting ? '${_selectedFilePaths.length} Selected' : widget.title,
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSelecting = false;
                    _selectedFilePaths.clear();
                  });
                },
              )
            : const BackButton(),
        actions: [
          if (_isSelecting)
            IconButton(
              icon: huge.HugeIcon(
                icon: huge.HugeIcons.strokeRoundedDelete02,
                color: colorScheme.error,
                size: 24,
              ),
              onPressed: _deleteSelectedFiles,
            ),
          if (!_isSelecting && _files.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.checklist_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _isSelecting = true;
                });
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      huge.HugeIcon(
                        icon: huge.HugeIcons.strokeRoundedFolder01,
                        color: colorScheme.onSurface.withValues(alpha: 0.2),
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No ${widget.title.toLowerCase()} found',
                        style: TextStyle(
                          fontSize: 18,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : widget.fileType == 'image' || widget.fileType == 'video'
                  ? _buildGrid(colorScheme)
                  : _buildList(colorScheme),
    );
  }

  Widget _buildGrid(ColorScheme colorScheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final path = file.path;
        final isSelected = _selectedFilePaths.contains(path);

        return GestureDetector(
          onLongPress: () {
            if (!_isSelecting) {
              setState(() {
                _isSelecting = true;
                _selectedFilePaths.add(path);
              });
            }
          },
          onTap: () {
            if (_isSelecting) {
              _toggleSelection(path);
            } else {
              OpenFilex.open(path);
            }
          },
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildFileThumbnail(file, colorScheme),
              ),
              if (_isSelecting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? colorScheme.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              if (_isSelecting)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : const SizedBox(width: 16, height: 16),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final path = file.path;
        final stat = file.statSync();
        final isSelected = _selectedFilePaths.contains(path);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primary.withValues(alpha: 0.1) 
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Colors.transparent,
            ),
          ),
          child: ListTile(
            onLongPress: () {
              if (!_isSelecting) {
                setState(() {
                  _isSelecting = true;
                  _selectedFilePaths.add(path);
                });
              }
            },
            onTap: () {
              if (_isSelecting) {
                _toggleSelection(path);
              } else {
                OpenFilex.open(path);
              }
            },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: _buildFileThumbnail(file, colorScheme),
              ),
            ),
            title: Text(
              path.split(Platform.pathSeparator).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              _formatBytes(stat.size),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            trailing: _isSelecting
                ? Container(
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : const SizedBox(width: 16, height: 16),
                  )
                : huge.HugeIcon(
                    icon: huge.HugeIcons.strokeRoundedArrowRight01,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
          ),
        );
      },
    );
  }
}
