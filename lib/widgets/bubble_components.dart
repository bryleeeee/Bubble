import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/post.dart';

// IMAGE CAROUSEL
class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final void Function(String) onImageTap;

  const ImageCarousel({
    Key? key, required this.imageUrls, this.height = 300, required this.onImageTap,
  }) : super(key: key);

  @override State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) return const SizedBox.shrink();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: widget.height, width: double.infinity,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
            ),
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => widget.onImageTap(widget.imageUrls[index]),
                child: Container(
                  color: BT.bg,
                  child: Image.network(widget.imageUrls[index], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, color: BT.textTertiary, size: 28))),
                ),
              ),
            ),
          ),
        ),
      ),
      if (widget.imageUrls.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.imageUrls.length, (index) {
              final isActive = _currentIndex == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3.0),
                height: 6.0, width: isActive ? 18.0 : 6.0,
                decoration: BoxDecoration(
                  color: isActive ? BT.pastelPurple : BT.divider,
                  borderRadius: BorderRadius.circular(3)),
              );
            }),
          ),
        ),
    ]);
  }
}

// MUSIC ATTACHMENT CARD
class MusicAttachmentCard extends StatefulWidget {
  final MusicTrack track;
  const MusicAttachmentCard({Key? key, required this.track}) : super(key: key);
  @override State<MusicAttachmentCard> createState() => _MusicAttachmentCardState();
}

class _MusicAttachmentCardState extends State<MusicAttachmentCard>
    with SingleTickerProviderStateMixin {
  bool _playing = false;
  bool _loadingAudio = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _streamUrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _audioPlayer.onPlayerComplete.listen((_) { if (mounted) setState(() => _playing = false); });
  }

  @override void dispose() { _pulseCtrl.dispose(); _audioPlayer.dispose(); super.dispose(); }

  Future<void> _togglePlay() async {
    HapticFeedback.lightImpact();
    if (_playing) { await _audioPlayer.pause(); setState(() => _playing = false); return; }
    if (_streamUrl != null) { await _audioPlayer.play(UrlSource(_streamUrl!)); setState(() => _playing = true); return; }
    setState(() => _loadingAudio = true);
    try {
      if (widget.track.previewUrl?.isNotEmpty == true) {
        _streamUrl = widget.track.previewUrl!;
      } else {
        final query = Uri.encodeComponent('${widget.track.title} ${widget.track.artist}');
        final response = await http.get(Uri.parse('https://itunes.apple.com/search?term=$query&entity=song&limit=1'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['results']?.isNotEmpty == true) _streamUrl = data['results'][0]['previewUrl'];
        }
      }
      if (_streamUrl != null) {
        await _audioPlayer.play(UrlSource(_streamUrl!));
        if (mounted) setState(() { _playing = true; _loadingAudio = false; });
      } else throw Exception('No snippet found');
    } catch (e) {
      if (mounted) {
        setState(() => _loadingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No audio snippet available.')));
      }
    }
  }

  Future<void> _openSpotify() async {
    final url = Uri.parse('https://open.spotify.com/track/${widget.track.id}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.track;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.dominantColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.dominantColor.withOpacity(0.2), width: 1)),
      child: Row(children: [
        GestureDetector(
          onTap: _togglePlay,
          child: AnimatedBuilder(animation: _pulse,
            builder: (_, child) => Transform.scale(scale: _playing ? _pulse.value : 1.0, child: child),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: Image.network(t.albumArt, width: 44, height: 44, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 44, height: 44,
                  color: t.dominantColor.withOpacity(0.3),
                  child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20)))))),
        const SizedBox(width: 10),
        Expanded(child: GestureDetector(
          onTap: _togglePlay,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, color: BT.textPrimary, fontSize: 13)),
            Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: BT.textSecondary, fontSize: 11.5)),
          ]))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _openSpotify,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(color: BT.spotify, borderRadius: BorderRadius.circular(20)),
            child: const Text('↗ Spotify', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _loadingAudio ? null : _togglePlay,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _playing ? t.dominantColor : t.dominantColor.withOpacity(0.15),
              shape: BoxShape.circle),
            child: _loadingAudio
              ? Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(t.dominantColor)))
              : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: _playing ? Colors.white : t.dominantColor, size: 18))),
      ]),
    );
  }
}