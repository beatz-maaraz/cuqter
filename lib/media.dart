import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuqter/services/local_storage_service.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:hugeicons/hugeicons.dart' as huge;

// Model for assets matching Figma prototype
class AppAsset {
  final String id;
  final String imageUrl; // Can be file path or network URL
  final String title;
  final String category; // 'Favorites', 'Camera', 'Download', 'Screenshot', 'More'
  final String type; // 'image' or 'video'
  final DateTime date;
  final String size;
  bool isFavorite;
  final String duration; // e.g. "0:15" if video

  AppAsset({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.category,
    required this.type,
    required this.date,
    required this.size,
    this.isFavorite = false,
    this.duration = '',
  });
}

// Lightweight stateless widget to render video placeholders in the grid
class VideoThumbnailWidget extends StatelessWidget {
  final String videoPath;
  const VideoThumbnailWidget({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff1e293b), Color(0xff0f172a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam_rounded,
          color: Colors.white38,
          size: 28,
        ),
      ),
    );
  }
}

class AssetManagerScreen extends StatefulWidget {
  final String initialTab; // 'All', 'Images', 'Videos'
  final String initialCategory; // 'Favorites', 'Camera', 'Download', 'Screenshot', 'More'
  final bool isPicker;
  final ValueChanged<AppAsset?>? onAssetSelected;
  final String? title;

  const AssetManagerScreen({
    super.key,
    this.initialTab = 'All',
    this.initialCategory = 'All',
    this.isPicker = false,
    this.onAssetSelected,
    this.title,
  });

  @override
  State<AssetManagerScreen> createState() => _AssetManagerScreenState();
}

class _AssetManagerScreenState extends State<AssetManagerScreen> {
  late String _selectedTab;
  late String _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Selection mode variables
  bool _isSelectionMode = false;
  final Set<String> _selectedAssetIds = {};
  List<AppAsset> _assets = [];
  bool _isLoading = false;

  // Folder Selection State (WhatsApp style)
  String? _selectedSubFolder;

  static const Color figmaBlue = Color(0xff0057FF);

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _selectedCategory = widget.initialCategory;
    _searchController.addListener(_onSearchChanged);
    _loadStorageAssets();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedSubFolder = null; // Always reset selected folder when changing categories
      if (_selectedCategory == category) {
        _selectedCategory = 'All';
      } else {
        _selectedCategory = category;
      }
    });
  }

  Map<String, List<AppAsset>> _getFoldersFromAssets(List<AppAsset> assetList) {
    final Map<String, List<AppAsset>> folderGroups = {};
    for (var asset in assetList) {
      if (asset.imageUrl.startsWith('http')) {
        continue;
      }
      final file = File(asset.id);
      final folderPath = file.parent.path;
      folderGroups.putIfAbsent(folderPath, () => []).add(asset);
    }
    return folderGroups;
  }

  Widget _buildFolderListView(Map<String, List<AppAsset>> folders) {
    final folderList = folders.entries.toList();
    folderList.sort((a, b) {
      if (a.value.isEmpty) return 1;
      if (b.value.isEmpty) return -1;
      return b.value.first.date.compareTo(a.value.first.date);
    });

    if (folderList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 64, color: Colors.black.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              'No folders containing media found',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.4),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 columns for grid
        crossAxisSpacing: 10,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8, // Make it a bit taller to fit text
      ),
      itemCount: folderList.length,
      itemBuilder: (context, index) {
        final entry = folderList[index];
        final folderPath = entry.key;
        final assets = entry.value;
        final folderName = folderPath.split(Platform.pathSeparator).last;
        final newestAsset = assets.first;
        final isVideo = newestAsset.type == 'video';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        final imageCount = assets.where((a) => a.type == 'image').length;
        final videoCount = assets.where((a) => a.type == 'video').length;
        String subtitle = '';
        if (imageCount > 0 && videoCount > 0) {
          subtitle = '${imageCount + videoCount} items';
        } else if (imageCount > 0) {
          subtitle = '$imageCount items';
        } else if (videoCount > 0) {
          subtitle = '$videoCount items';
        }

        return InkWell(
          onTap: () {
            setState(() {
              _selectedSubFolder = folderPath;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      newestAsset.imageUrl.startsWith('http')
                          ? Image.network(
                              newestAsset.imageUrl,
                              cacheWidth: 300,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(newestAsset.imageUrl),
                              cacheWidth: 300,
                              fit: BoxFit.cover,
                            ),
                      if (isVideo)
                        Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                folderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectedFolderView(String folderPath, List<AppAsset> folderAssets) {
    final folderName = folderPath.split(Platform.pathSeparator).last;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;
    final subtitleColor = isDark ? colorScheme.onSurface.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5);
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
        key: ValueKey<String>(folderPath),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: huge.HugeIcon(
                    icon: huge.HugeIcons.strokeRoundedArrowLeft01,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedSubFolder = null;
                    });
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folderName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${folderAssets.length} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _buildAssetGrid(folderAssets),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Load actual files asynchronously and concurrently using parallel futures
  Future<void> _loadStorageAssets() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final List<AppAsset> loadedAssets = [];
      
      // Load favorites list once from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final favoritePaths = prefs.getStringList('media_favorites') ?? [];

      if (!kIsWeb) {
        // Request permissions on Android in parallel
        if (Platform.isAndroid) {
          final storageGranted = await Permission.storage.isGranted;
          final photosGranted = await Permission.photos.isGranted;
          final videosGranted = await Permission.videos.isGranted;
          
          if (!storageGranted && !photosGranted && !videosGranted) {
            await [
              Permission.storage,
              Permission.photos,
              Permission.videos,
            ].request();
          }
        }

        // List of folders to scan with their mapped categories
        final List<Map<String, String>> foldersToScan = [];

        // Helper to scan subfolders of a directory
        Future<void> addFolderAndSubfolders(String parentPath, String defaultCategory) async {
          final parentDir = Directory(parentPath);
          if (await parentDir.exists()) {
            foldersToScan.add({'path': parentPath, 'category': defaultCategory});
            try {
              await for (final entity in parentDir.list(recursive: false, followLinks: false).handleError((e) {
                debugPrint('Error listing parent directory $parentPath: $e');
              })) {
                if (entity is Directory) {
                  final name = entity.path.split(Platform.pathSeparator).last;
                  if (!name.startsWith('.')) {
                    foldersToScan.add({'path': entity.path, 'category': defaultCategory});
                  }
                }
              }
            } catch (e) {
              debugPrint('Error traversing parent directory $parentPath: $e');
            }
          }
        }

        // 1. App-specific local storage folders
        final localImagePath = await LocalStorageService.getLocalFolderPath('image');
        if (localImagePath != null) {
          foldersToScan.add({'path': localImagePath, 'category': 'Camera'});
        }
        final localVideoPath = await LocalStorageService.getLocalFolderPath('video');
        if (localVideoPath != null) {
          foldersToScan.add({'path': localVideoPath, 'category': 'Camera'});
        }
        final localDocPath = await LocalStorageService.getLocalFolderPath('document');
        if (localDocPath != null) {
          foldersToScan.add({'path': localDocPath, 'category': 'Download'});
        }

        // 2. Public phone storage folders (Android only, if permission granted)
        if (Platform.isAndroid && 
            (await Permission.storage.isGranted || 
             await Permission.photos.isGranted || 
             await Permission.videos.isGranted)) {
          await addFolderAndSubfolders('/storage/emulated/0/DCIM', 'Camera');
          await addFolderAndSubfolders('/storage/emulated/0/Pictures', 'More');
          await addFolderAndSubfolders('/storage/emulated/0/Download', 'Download');
        }

        // 3. Windows user profile media folders
        if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            await addFolderAndSubfolders('$userProfile\\Pictures', 'Camera');
            await addFolderAndSubfolders('$userProfile\\Downloads', 'Download');
            await addFolderAndSubfolders('$userProfile\\Videos', 'More');
          }
        }

        // Scan all folders in parallel (concurrently) using Future.wait
        final scanFutures = foldersToScan.map((folder) {
          return _scanFolder(folder['path']!, folder['category']!, loadedAssets, favoritePaths);
        });
        await Future.wait(scanFutures);
      }

      // 3. For any saved favorite paths that might not be in the scanned folders,
      // add them to the assets list if they exist on disk
      final favoriteFutures = favoritePaths.map((path) async {
        if (!loadedAssets.any((a) => a.id == path)) {
          final file = File(path);
          if (await file.exists()) {
            final filename = path.split(Platform.pathSeparator).last;
            final stat = await file.stat();
            final nameLower = filename.toLowerCase();
            final isVideo = nameLower.endsWith('.mp4') || nameLower.endsWith('.mov') || nameLower.endsWith('.avi') || nameLower.endsWith('.mkv') || nameLower.endsWith('.3gp');
            
            return AppAsset(
              id: path,
              imageUrl: path,
              title: filename,
              category: 'Favorites',
              type: isVideo ? 'video' : 'image',
              date: stat.modified,
              size: '${(stat.size / (1024 * 1024)).toStringAsFixed(2)} MB',
              duration: isVideo ? '0:00' : '',
              isFavorite: true,
            );
          }
        }
        return null;
      });

      final favoriteResults = await Future.wait(favoriteFutures);
      for (var asset in favoriteResults) {
        if (asset != null) {
          loadedAssets.add(asset);
        }
      }

      // Sort assets by date descending (newest first)
      loadedAssets.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _assets = loadedAssets;
      });
    } catch (e) {
      debugPrint('Error loading storage assets: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Scan folder concurrently loading metadata stats in parallel
  Future<void> _scanFolder(String path, String category, List<AppAsset> loadedAssets, List<String> favoritePaths) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final List<File> candidateFiles = [];
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            final filename = entity.path.split(Platform.pathSeparator).last;
            if (filename.startsWith('.')) continue;

            final nameLower = filename.toLowerCase();
            final isImage = nameLower.endsWith('.jpg') || nameLower.endsWith('.jpeg') || nameLower.endsWith('.png') || nameLower.endsWith('.gif') || nameLower.endsWith('.webp');
            final isVideo = nameLower.endsWith('.mp4') || nameLower.endsWith('.mov') || nameLower.endsWith('.avi') || nameLower.endsWith('.mkv') || nameLower.endsWith('.3gp');

            if (isImage || isVideo) {
              candidateFiles.add(entity);
            }
          }
        }

        if (candidateFiles.isNotEmpty) {
          final stats = await Future.wait(candidateFiles.map((f) => f.stat()));

          // Determine category dynamically based on path name
          String dynamicCategory = category;
          final folderNameLower = path.split(Platform.pathSeparator).last.toLowerCase();
          if (folderNameLower.contains('screenshot')) {
            dynamicCategory = 'Screenshot';
          } else if (folderNameLower.contains('camera')) {
            dynamicCategory = 'Camera';
          } else if (folderNameLower.contains('download')) {
            dynamicCategory = 'Download';
          }

          for (int i = 0; i < candidateFiles.length; i++) {
            final file = candidateFiles[i];
            final stat = stats[i];
            final filename = file.path.split(Platform.pathSeparator).last;
            final nameLower = filename.toLowerCase();
            final isVideo = nameLower.endsWith('.mp4') || nameLower.endsWith('.mov') || nameLower.endsWith('.avi') || nameLower.endsWith('.mkv') || nameLower.endsWith('.3gp');

            // Prevent duplicates
            if (loadedAssets.any((a) => a.id == file.path)) continue;

            final isFav = favoritePaths.contains(file.path);

            loadedAssets.add(
              AppAsset(
                id: file.path,
                imageUrl: file.path,
                title: filename,
                category: dynamicCategory,
                type: isVideo ? 'video' : 'image',
                date: stat.modified,
                size: '${(stat.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                duration: isVideo ? '0:00' : '',
                isFavorite: isFav,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error scanning folder $path: $e');
    }
  }

  // Persist favorite changes to SharedPreferences
  Future<void> _persistFavorite(String path, bool isFav) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('media_favorites') ?? [];
      if (isFav) {
        if (!list.contains(path)) {
          list.add(path);
        }
      } else {
        list.remove(path);
      }
      await prefs.setStringList('media_favorites', list);
    } catch (e) {
      debugPrint('Error persisting favorite: $e');
    }
  }

  // Real capture and add asset flow
  void _pickAndAddAsset() async {
    final XFile? media = await pickMediaFile();
    if (media != null) {
      String name = media.name;
      bool isVideoFile = false;
      if (media.mimeType != null && media.mimeType!.startsWith('video/')) {
        isVideoFile = true;
      } else {
        final nameLower = name.toLowerCase();
        isVideoFile = nameLower.endsWith('.mp4') || nameLower.endsWith('.mov') || nameLower.endsWith('.avi') || nameLower.endsWith('.mkv');
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final fileBytes = await media.readAsBytes();
        final savedPath = await LocalStorageService.saveFileLocally(
          name,
          fileBytes,
          isVideoFile ? 'video' : 'image',
        );

        if (savedPath != null) {
          await _loadStorageAssets();
          
          if (widget.isPicker) {
            final newAsset = _assets.firstWhere((a) => a.id == savedPath, orElse: () => _assets.first);
            if (widget.onAssetSelected != null) {
              widget.onAssetSelected!(newAsset);
            } else {
              Navigator.pop(context, newAsset);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added new ${isVideoFile ? 'video' : 'image'} to local storage!'),
                backgroundColor: figmaBlue,
              ),
            );
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e'), backgroundColor: Colors.redAccent),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<AppAsset> get _filteredAssets {
    return _assets.where((asset) {
      // 1. Filter by search query
      if (_searchQuery.isNotEmpty && !asset.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }

      // 2. Filter by tabs (All, Images, Videos)
      if (_selectedTab == 'Images' && asset.type != 'image') return false;
      if (_selectedTab == 'Videos' && asset.type != 'video') return false;

      // 3. Filter by category
      if (_selectedCategory == 'Favorites' && !asset.isFavorite) return false;
      if (_selectedCategory != 'All' && _selectedCategory != 'Favorites' && _selectedCategory != 'More' && asset.category != _selectedCategory) return false;

      return true;
    }).toList();
  }

  // Group assets dynamically by date
  Map<String, List<AppAsset>> _groupAssetsByDate(List<AppAsset> assetList) {
    final Map<String, List<AppAsset>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var asset in assetList) {
      final assetDate = DateTime(asset.date.year, asset.date.month, asset.date.day);
      String header;
      if (assetDate == today) {
        header = 'Recent';
      } else if (assetDate == yesterday) {
        header = 'Yesterday';
      } else {
        header = _formatDateHeader(asset.date);
      }
      groups.putIfAbsent(header, () => []).add(asset);
    }
    return groups;
  }

  String _formatDateHeader(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _buildContent(List<AppAsset> filtered, Map<String, List<AppAsset>> grouped) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? colorScheme.onSurface.withValues(alpha: 0.6) : Colors.black54;

    if (_selectedCategory == 'More') {
      return SizedBox(
        key: ValueKey('folder_view_${_selectedSubFolder ?? ""}'),
        child: _selectedSubFolder == null
            ? _buildFolderListView(_getFoldersFromAssets(filtered))
            : _buildSelectedFolderView(_selectedSubFolder!, _getFoldersFromAssets(filtered)[_selectedSubFolder] ?? []),
      );
    }
    
    if (_isLoading) {
      return Center(
        key: ValueKey('loading_${_selectedTab}_$_selectedCategory'),
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }
    
    if (filtered.isEmpty) {
      return Center(
        key: ValueKey('empty_${_selectedTab}_$_selectedCategory'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: isDark ? colorScheme.onSurface.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            Text(
              'No assets found in storage',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      key: ValueKey('grid_view_${_selectedTab}_$_selectedCategory'),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGridSectionHeader(entry.key),
              _buildAssetGrid(entry.value),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAssets;
    final grouped = _groupAssetsByDate(filtered);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Glassmorphic background and border styling
    final glassBgColor = isDark 
        ? Colors.black.withValues(alpha: 0.6) 
        : Colors.white.withValues(alpha: 0.65);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final textColor = isDark ? colorScheme.onSurface : Colors.black87;

    final bodyContent = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isPicker)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 2),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.2) 
                      : Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          // Header Row (Centered Title)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: huge.HugeIcon(
                      icon: huge.HugeIcons.strokeRoundedCancel01,
                      color: textColor,
                      size: 20,
                    ),
                    onPressed: () {
                      if (_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedAssetIds.clear();
                        });
                      } else if (_selectedCategory != 'All' || _selectedSubFolder != null) {
                        setState(() {
                          _selectedCategory = 'All';
                          _selectedSubFolder = null;
                        });
                      } else {
                        if (widget.onAssetSelected != null) {
                          widget.onAssetSelected!(null);
                        } else {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                ),
                Text(
                  _isSelectionMode
                      ? '${_selectedAssetIds.length} Selected'
                      : (widget.title ?? (widget.isPicker ? 'Select Photo' : 'AssetManager')),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_isSelectionMode)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: huge.HugeIcon(
                            icon: huge.HugeIcons.strokeRoundedDelete01,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          onPressed: _showBulkDeleteConfirmation,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Search Bar (Frosted Glass style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30.0),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search assets...',
                  hintStyle: TextStyle(
                    color: isDark ? colorScheme.onSurface.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? colorScheme.onSurface.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Tabs Selector: All, Images, Videos (Frosted Glass style - Compact & Centered)
          Center(
            child: Container(
              height: 42,
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(30.0),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Stack(
                children: [
                  // Sliding indicator
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: _selectedTab == 'All'
                        ? Alignment.centerLeft
                        : (_selectedTab == 'Images'
                            ? Alignment.center
                            : Alignment.centerRight),
                    child: FractionallySizedBox(
                      widthFactor: 1 / 3,
                      heightFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(25.0),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab text layers
                  Row(
                    children: ['All', 'Images', 'Videos'].map((tab) {
                      final isSelected = _selectedTab == tab;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              _selectedTab = tab;
                            });
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? colorScheme.onSurface.withValues(alpha: 0.6) : Colors.black54),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              child: Text(tab),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Categories list: Favorites, Camera, Download, Screenshot, More
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              children: [
                _buildCategoryCard('Favorites', huge.HugeIcons.strokeRoundedFavourite),
                _buildCategoryCard('Camera', huge.HugeIcons.strokeRoundedCamera01),
                _buildCategoryCard('Download', huge.HugeIcons.strokeRoundedDownload01),
                _buildCategoryCard('Screenshot', huge.HugeIcons.strokeRoundedRecord),
                _buildCategoryCard('More', huge.HugeIcons.strokeRoundedFolder01),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Asset Content with smooth Fade/Slide transition switcher
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                );
              },
              child: _buildContent(filtered, grouped),
            ),
          ),
        ],
      ),
    );

    final glassLayout = ClipRRect(
      borderRadius: widget.isPicker 
          ? const BorderRadius.vertical(top: Radius.circular(24.0)) 
          : BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          color: glassBgColor,
          child: bodyContent,
        ),
      ),
    );

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      body: glassLayout,
      
      // Bulk Actions Bar (Shown when items are selected)
      bottomNavigationBar: _isSelectionMode
          ? SafeArea(
              child: Container(
                height: 70,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.black.withValues(alpha: 0.75) 
                      : Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBulkActionItem(
                      icon: huge.HugeIcons.strokeRoundedFavourite,
                      label: 'Favorite',
                      onTap: () async {
                        bool allFavorites = true;
                        for (var asset in _assets) {
                          if (_selectedAssetIds.contains(asset.id) && !asset.isFavorite) {
                            allFavorites = false;
                            break;
                          }
                        }
                        
                        final newState = !allFavorites;

                        for (var asset in _assets) {
                          if (_selectedAssetIds.contains(asset.id)) {
                            setState(() {
                              asset.isFavorite = newState;
                            });
                            await _persistFavorite(asset.id, newState);
                          }
                        }
                        setState(() {
                          _isSelectionMode = false;
                          _selectedAssetIds.clear();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(newState ? 'Added to Favorites' : 'Removed from Favorites')),
                        );
                      },
                    ),
                    _buildBulkActionItem(
                      icon: huge.HugeIcons.strokeRoundedDelete01,
                      label: 'Delete',
                      color: colorScheme.error,
                      onTap: () {
                        _showBulkDeleteConfirmation();
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,

      // FAB to trigger system camera or gallery selection
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton(
              onPressed: _pickAndAddAsset,
              backgroundColor: colorScheme.primary,
              shape: const CircleBorder(),
              child: huge.HugeIcon(icon: huge.HugeIcons.strokeRoundedCamera01, color: colorScheme.onPrimary, size: 26),
            )
          : null,
    );

    if (widget.isPicker) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        child: scaffold,
      );
    }
    return scaffold;
  }

  // Category card builder with theme specific color styling & toggling
  Widget _buildCategoryCard(String category, dynamic icon) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedCategory == category;
    
    Color containerColor;
    Color iconColor;
    
    if (isSelected) {
      containerColor = colorScheme.primary;
      iconColor = Colors.white;
    } else {
      if (category == 'Favorites') {
        containerColor = isDark
            ? colorScheme.primary.withValues(alpha: 0.15)
            : const Color(0xffE5EFFF);
        iconColor = colorScheme.primary;
      } else {
        containerColor = isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04);
        iconColor = isDark ? colorScheme.onSurface.withValues(alpha: 0.6) : Colors.black54;
      }
    }

    return GestureDetector(
      onTap: () => _onCategorySelected(category),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isSelected ? Colors.transparent : containerColor,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: colorScheme.primary, width: 2.5)
                    : null,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: icon is IconData
                        ? Icon(
                            icon,
                            color: iconColor,
                            size: 22,
                          )
                        : huge.HugeIcon(
                            icon: icon,
                            color: iconColor,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.primary
                    : (isDark ? colorScheme.onSurface.withValues(alpha: 0.8) : Colors.black87),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAssetGrid(List<AppAsset> assetList) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: assetList.length,
      itemBuilder: (context, index) {
        final asset = assetList[index];
        final isSelected = _selectedAssetIds.contains(asset.id);

        return GestureDetector(
          onTap: () {
            if (widget.isPicker) {
              if (widget.onAssetSelected != null) {
                widget.onAssetSelected!(asset);
              } else {
                Navigator.pop(context, asset);
              }
            } else if (_isSelectionMode) {
              setState(() {
                if (isSelected) {
                  _selectedAssetIds.remove(asset.id);
                  if (_selectedAssetIds.isEmpty) {
                    _isSelectionMode = false;
                  }
                } else {
                  _selectedAssetIds.add(asset.id);
                }
              });
            } else {
              _openAssetPreview(asset);
            }
          },
          onLongPress: () {
            if (widget.isPicker) {
              _openAssetPreview(asset);
            } else {
              setState(() {
                _isSelectionMode = true;
                _selectedAssetIds.add(asset.id);
              });
            }
          },
          child: Hero(
            tag: 'asset_${asset.id}',
            child: Stack(
              children: [
                // Render image or video thumbnail with smooth scaling animation
                Positioned.fill(
                  child: AnimatedScale(
                    scale: isSelected ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                         boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: asset.type == 'video'
                          ? VideoThumbnailWidget(videoPath: asset.imageUrl)
                          : (asset.imageUrl.startsWith('http')
                              ? Image.network(
                                  asset.imageUrl,
                                  cacheWidth: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                )
                              : Image.file(
                                  File(asset.imageUrl),
                                  cacheWidth: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                )),
                    ),
                  ),
                ),

                // Video Icon Overlay
                if (asset.type == 'video')
                  Positioned.fill(
                    child: AnimatedScale(
                      scale: isSelected ? 0.92 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.play_arrow_rounded, color: colorScheme.primary, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Animated selection frame & overlay (Frosted selection)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: _isSelectionMode
                          ? (isSelected ? colorScheme.primary.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.1))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12.0),
                      border: _isSelectionMode && isSelected
                          ? Border.all(color: colorScheme.primary, width: 3)
                          : Border.all(color: Colors.transparent, width: 0),
                    ),
                  ),
                ),

                // Favorite Indicator
                if (asset.isFavorite)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.redAccent,
                        size: 14,
                      ),
                    ),
                  ),

                // Bouncing checkmark bubble
                Positioned(
                  top: 6,
                  right: 6,
                  child: AnimatedScale(
                    scale: (_isSelectionMode && isSelected) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: (_isSelectionMode && isSelected) ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAssetPreview(AppAsset asset) async {
    final result = await Navigator.push<AppAsset>(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenAssetPreview(
          asset: asset,
          isPicker: widget.isPicker,
          onFavoriteChanged: (val) async {
            setState(() {
              asset.isFavorite = val;
            });
            await _persistFavorite(asset.id, val);
          },
          onDelete: () async {
            try {
              if (!kIsWeb) {
                await File(asset.id).delete();
              }
              setState(() {
                _assets.removeWhere((item) => item.id == asset.id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Asset deleted')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete asset: $e')),
              );
            }
          },
        ),
      ),
    );

    if (result != null) {
      if (widget.onAssetSelected != null) {
        widget.onAssetSelected!(result);
      } else {
        Navigator.pop(context, result);
      }
    }
  }

  void _showBulkDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete assets?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete ${_selectedAssetIds.length} assets? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              try {
                for (var id in _selectedAssetIds) {
                  if (!kIsWeb) {
                    await File(id).delete();
                  }
                }
                setState(() {
                  _assets.removeWhere((asset) => _selectedAssetIds.contains(asset.id));
                  _isSelectionMode = false;
                  _selectedAssetIds.clear();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Selected assets deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete files: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionItem({
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          huge.HugeIcon(icon: icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class FullScreenAssetPreview extends StatefulWidget {
  final AppAsset asset;
  final ValueChanged<bool> onFavoriteChanged;
  final VoidCallback onDelete;
  final bool isPicker;

  const FullScreenAssetPreview({
    super.key,
    required this.asset,
    required this.onFavoriteChanged,
    required this.onDelete,
    this.isPicker = false,
  });

  @override
  State<FullScreenAssetPreview> createState() => _FullScreenAssetPreviewState();
}

class _FullScreenAssetPreviewState extends State<FullScreenAssetPreview> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.asset.isFavorite;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isPicker)
            TextButton(
              onPressed: () {
                Navigator.pop(context, widget.asset);
              },
              child: const Text(
                'SELECT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          if (!widget.isPicker) ...[
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? Colors.redAccent : Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isFavorite = !_isFavorite;
                  widget.onFavoriteChanged(_isFavorite);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              onPressed: _showDeleteConfirm,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: _showDetailsSheet,
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: 'asset_${widget.asset.id}',
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: widget.asset.type == 'video'
                ? VideoPlayerPreview(videoPath: widget.asset.imageUrl)
                : (widget.asset.imageUrl.startsWith('http')
                    ? Image.network(
                        widget.asset.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                      )
                    : Image.file(
                        File(widget.asset.imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
                      )),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete asset?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this asset? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDetailsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff121212),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Asset Information',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Name', widget.asset.title),
              _buildDetailRow('Type', widget.asset.type.toUpperCase()),
              _buildDetailRow('Category', widget.asset.category),
              _buildDetailRow('Size', widget.asset.size),
              _buildDetailRow(
                'Date Added', 
                '${widget.asset.date.day}/${widget.asset.date.month}/${widget.asset.date.year}',
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Stateful helper widget to play video inside full screen preview
class VideoPlayerPreview extends StatefulWidget {
  final String videoPath;
  const VideoPlayerPreview({super.key, required this.videoPath});

  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}

class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() async {
    if (widget.videoPath.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoPath));
    }

    try {
      await _controller!.initialize();
      _controller!.play();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing preview controller: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}
