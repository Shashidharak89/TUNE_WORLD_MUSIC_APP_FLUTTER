import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../services/audio_handler.dart';
import '../theme/app_theme.dart';
import '../models/audio_model.dart';
import '../widgets/audio_tile_widget.dart';

class DownloadsScreen extends StatefulWidget {
  final TuneWorldAudioHandler audioHandler;

  const DownloadsScreen({super.key, required this.audioHandler});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isMultiSelectMode = false;
  final Set<String> _selectedAudioIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DownloadProvider>(context, listen: false).fetchDownloadedTracks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _bulkDeleteDownloaded(List<String> audioIds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Offline Copies', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${audioIds.length} track(s) from offline downloads?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final dlProv = Provider.of<DownloadProvider>(context, listen: false);
              for (final id in audioIds) {
                await dlProv.deleteTrack(id);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${audioIds.length} offline track(s)')),
                );
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedAudioIds.clear();
                });
              }
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloadProv = Provider.of<DownloadProvider>(context);
    final allDownloaded = downloadProv.downloadedTracks;
    final filtered = allDownloaded.where((audio) {
      if (_searchQuery.isEmpty) return true;
      return audio.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (audio.userName != null && audio.userName!.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    return PopScope(
      canPop: !_isMultiSelectMode,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        if (_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedAudioIds.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _isMultiSelectMode
            ? AppBar(
                backgroundColor: AppTheme.cardBg,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedAudioIds.clear();
                    });
                  },
                ),
                title: Text(
                  '${_selectedAudioIds.length} Selected',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedAudioIds.addAll(filtered.map((a) => a.id));
                      });
                    },
                    child: const Text('Select All', style: TextStyle(color: AppTheme.primaryAccent)),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedAudioIds.clear();
                      });
                    },
                    child: const Text('Deselect All', style: TextStyle(color: Colors.grey)),
                  ),
                ],
              )
            : AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'Downloaded Music',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.grey),
                    onPressed: () {
                      Provider.of<DownloadProvider>(context, listen: false).fetchDownloadedTracks();
                    },
                  ),
                ],
              ),
        body: Stack(
          children: [
            Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search offline downloads...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryAccent),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Active Download Indicator Banner
                if (downloadProv.downloadingIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppTheme.primaryAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Downloading ${downloadProv.downloadingIds.length} audio file(s)...',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Track Count Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filtered.length} Offline Tracks',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (filtered.isNotEmpty && !_isMultiSelectMode)
                        TextButton.icon(
                          onPressed: () {
                            widget.audioHandler.playTrack(filtered[0], queueList: filtered, index: 0);
                          },
                          icon: const Icon(Icons.play_circle_fill, color: AppTheme.primaryAccent),
                          label: const Text('Play All', style: TextStyle(color: AppTheme.primaryAccent)),
                        ),
                    ],
                  ),
                ),

                // List of downloaded tracks
                Expanded(
                  child: downloadProv.isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent))
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.download_done_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'No offline tracks match your search' : 'No offline audio files downloaded yet',
                                    style: const TextStyle(color: Colors.grey, fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              padding: EdgeInsets.only(bottom: _isMultiSelectMode ? 160 : 120),
                            itemBuilder: (context, index) {
                              final audio = filtered[index];
                              return AudioTileWidget(
                                audio: audio,
                                audioHandler: widget.audioHandler,
                                isDownloadedScreen: true,
                                onDeleteDownloaded: () {
                                  _confirmDeleteDownloaded(context, audio);
                                },
                                isMultiSelectMode: _isMultiSelectMode,
                                isMultiSelected: _selectedAudioIds.contains(audio.id),
                                onToggleSelect: () {
                                  setState(() {
                                    if (_selectedAudioIds.contains(audio.id)) {
                                      _selectedAudioIds.remove(audio.id);
                                      if (_selectedAudioIds.isEmpty) {
                                        _isMultiSelectMode = false;
                                      }
                                    } else {
                                      _selectedAudioIds.add(audio.id);
                                    }
                                  });
                                },
                                onLongPress: () {
                                  setState(() {
                                    _isMultiSelectMode = true;
                                    _selectedAudioIds.add(audio.id);
                                  });
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
          if (_isMultiSelectMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  border: const Border(top: BorderSide(color: Colors.white12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _selectedAudioIds.isEmpty
                            ? null
                            : () => _bulkDeleteDownloaded(_selectedAudioIds.toList()),
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                        label: const Text('Delete Offline Files', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  void _confirmDeleteDownloaded(BuildContext context, AudioModel audio) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('Delete Offline Copy', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove "${audio.name}" from offline downloads?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<DownloadProvider>(context, listen: false).deleteTrack(audio.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed "${audio.name}" from offline downloads')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
