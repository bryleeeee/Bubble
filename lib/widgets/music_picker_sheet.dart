import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/post.dart';
import '../spotify_service.dart';

class MusicPickerSheet extends StatefulWidget {
  final void Function(MusicTrack) onSelect;
  const MusicPickerSheet({Key? key, required this.onSelect}) : super(key: key);

  @override
  State<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends State<MusicPickerSheet> {
  final _ctrl = TextEditingController();
  final _spotify = SpotifyService();
  Timer? _debounce;
  
  List<MusicTrack> _results = [];
  List<MusicTrack> _recommendations = []; // ── Holds the Top 50 PH tracks
  
  bool _loading = false;
  bool _loadingRecommendations = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchTop50Philippines(); // ── Automatically fetch Top 50 on load
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── DYNAMICALLY FETCH TOP 50 PHILIPPINES ──
  Future<void> _fetchTop50Philippines() async {
    try {
      // Uses your existing Spotify Service to search for the playlist tracks!
      final results = await _spotify.searchTracks('Top 50 Philippines');
      if (mounted) {
        setState(() {
          _recommendations = results;
          _loadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingRecommendations = false);
      }
    }
  }

  // ── YOUR ORIGINAL SEARCH LOGIC (RESTORED) ──
  Future<void> _search(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = '';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _spotify.searchTracks(query);
        if (mounted) {
          setState(() {
            _results = results;
            _loading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = e.toString().replaceAll('Exception: ', '');
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── YOUR ORIGINAL DRAGGABLE SHEET ──
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: BT.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 20,
                    decoration: BoxDecoration(
                      color: BT.spotify,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Add Music', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: BT.textPrimary)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: BT.spotify,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Spotify', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: BT.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BT.divider, width: 1),
                ),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _search,
                  style: const TextStyle(fontSize: 14, color: BT.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search songs, artists...',
                    hintStyle: TextStyle(color: BT.textTertiary, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: BT.textTertiary, size: 20),
                    border: InputBorder.none,
                    isDense: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(sc)),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ScrollController sc) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(BT.spotify)),
            ),
            SizedBox(height: 14),
            Text('Finding tracks...', style: TextStyle(color: BT.textTertiary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😵', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: BT.heartRed, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _search(_ctrl.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [BT.pastelPink, BT.pastelPurple]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Try again', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── SHOW TOP 50 PHILIPPINES WHEN SEARCH IS EMPTY ──
    if (_ctrl.text.isEmpty) {
      if (_loadingRecommendations) {
        return const Center(
          child: SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation(BT.pastelPurple)),
          ),
        );
      }
      
      if (_recommendations.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🎧', style: TextStyle(fontSize: 44)),
              SizedBox(height: 12),
              Text('Search for a song', style: TextStyle(color: BT.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 6),
              Text('Type above to find something to vibe to', style: TextStyle(color: BT.textTertiary, fontSize: 13)),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: BT.pastelPurple, size: 18),
                SizedBox(width: 8),
                Text('Top 50 Philippines', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: BT.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recommendations.length,
              itemBuilder: (_, i) => _buildTrackTile(_recommendations[i]),
            ),
          ),
        ],
      );
    }

    if (_ctrl.text.isNotEmpty && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎵', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text('No results for "${_ctrl.text}"', style: const TextStyle(color: BT.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    // ── SHOW REAL SEARCH RESULTS ──
    return ListView.builder(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (_, i) => _buildTrackTile(_results[i]),
    );
  }

  Widget _buildTrackTile(MusicTrack t) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onSelect(t);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: BT.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: BT.divider, width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: t.albumArt.isNotEmpty
                  ? Image.network(
                      t.albumArt,
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      // ── FIXES THE WEB CORS ERROR ──
                      errorBuilder: (_, __, ___) => _artPlaceholder(t),
                    )
                  : _artPlaceholder(t),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: BT.textPrimary, fontSize: 13.5)),
                  Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BT.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: t.dominantColor, shape: BoxShape.circle),
            ),
            const Icon(Icons.add_circle_outline_rounded, color: BT.pastelPurple, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _artPlaceholder(MusicTrack t) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: t.dominantColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
    );
  }
}