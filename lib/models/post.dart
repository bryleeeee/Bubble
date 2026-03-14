import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// THEME (Extracted for use in models/widgets)
class BT {
  static const Color bg       = Color(0xFFFAFAFD);
  static const Color card     = Color(0xFFFFFFFF);
  static const Color divider  = Color(0xFFF0F0F5);
  static const Color pastelBlue   = Color(0xFFADD4EC);
  static const Color pastelPink   = Color(0xFFFFB3C8);
  static const Color pastelYellow = Color(0xFFFFF0A0);
  static const Color pastelPurple = Color(0xFFCFB8E8);
  static const Color pastelMint   = Color(0xFFB8EDD6);
  static const Color pastelCoral  = Color(0xFFFFBDAD);
  static const Color textPrimary   = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary  = Color(0xFFADB5BD);
  static const Color heartRed   = Color(0xFFFF6B8A);
  static const Color repostTeal = Color(0xFF4ECDC4);
  static const Color spotify    = Color(0xFF1DB954);

  static Color pastelAt(int index) {
    const list = [pastelBlue, pastelPink, pastelPurple, pastelMint, pastelYellow, pastelCoral];
    return list[index % list.length];
  }
}

// MUSIC TRACK
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final Color dominantColor;
  final String? previewUrl;

  const MusicTrack({
    required this.id, required this.title, required this.artist,
    required this.albumArt, this.dominantColor = const Color(0xFFADD4EC),
    this.previewUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'title': title, 'artist': artist,
    'albumArt': albumArt, 'dominantColor': dominantColor.value,
    'previewUrl': previewUrl,
  };

  factory MusicTrack.fromMap(Map<String, dynamic> map) => MusicTrack(
    id: map['id'] ?? '', title: map['title'] ?? '',
    artist: map['artist'] ?? '', albumArt: map['albumArt'] ?? '',
    dominantColor: map['dominantColor'] != null ? Color(map['dominantColor']) : BT.pastelBlue,
    previewUrl: map['previewUrl'],
  );
}

// MOOD TAG
enum MoodTag { rant, vent, hotTake, none }

extension MoodTagX on MoodTag {
  String get label {
    switch (this) {
      case MoodTag.rant:    return '😤 Rant';
      case MoodTag.vent:    return '😭 Vent';
      case MoodTag.hotTake: return '🔥 Hot Take';
      case MoodTag.none:    return '';
    }
  }
  Color get fg {
    switch (this) {
      case MoodTag.rant:    return const Color(0xFFE05C6B);
      case MoodTag.vent:    return const Color(0xFF5B8FD5);
      case MoodTag.hotTake: return const Color(0xFFE07B3A);
      case MoodTag.none:    return Colors.transparent;
    }
  }
  Color get bg {
    switch (this) {
      case MoodTag.rant:    return const Color(0xFFFFE8EC);
      case MoodTag.vent:    return const Color(0xFFE5EFFF);
      case MoodTag.hotTake: return const Color(0xFFFFF3E5);
      case MoodTag.none:    return Colors.transparent;
    }
  }
  String get name => toString().split('.').last;
  static MoodTag fromString(String s) =>
      MoodTag.values.firstWhere((m) => m.name == s, orElse: () => MoodTag.none);
}

// POST MODEL
class Post {
  final String id;
  final String author;
  final String avatarSeed;
  final int avatarColorIndex;
  final String timestamp;
  final String text;
  final MoodTag mood;
  int likes;
  int commentCount;
  int repostCount;
  final List<String> imageUrls;
  final MusicTrack? music;

  final bool isRepost;
  final String? repostedBy;
  final String? originalPostId;
  final String? originalAuthor;
  final String? originalAvatarSeed;
  final int originalAvatarColorIndex;
  final String? originalText;
  final String? originalTimestamp;
  final List<String> originalImageUrls;

  Post({
    required this.id, required this.author, required this.avatarSeed,
    this.avatarColorIndex = 0, required this.timestamp, required this.text,
    required this.mood, required this.likes, required this.commentCount,
    this.repostCount = 0, this.imageUrls = const [], this.music,
    this.isRepost = false, this.repostedBy, this.originalPostId,
    this.originalAuthor, this.originalAvatarSeed, this.originalAvatarColorIndex = 0,
    this.originalText, this.originalTimestamp, this.originalImageUrls = const [],
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String formattedTime = 'Just now';
    if (data['createdAt'] != null) {
      DateTime dt = (data['createdAt'] as Timestamp).toDate();
      formattedTime = DateFormat('MMM d, yyyy • h:mm a').format(dt);
    }
    List<String> parsedUrls = [];
    if (data['imageUrls'] != null) parsedUrls = List<String>.from(data['imageUrls']);
    else if (data['imageUrl'] != null) parsedUrls = [data['imageUrl'] as String];
    List<String> originalParsedUrls = [];
    if (data['originalImageUrls'] != null) originalParsedUrls = List<String>.from(data['originalImageUrls']);
    else if (data['originalImageUrl'] != null) originalParsedUrls = [data['originalImageUrl'] as String];

    return Post(
      id: doc.id, author: data['author'] ?? 'Unknown',
      avatarSeed: data['avatarSeed'] ?? 'X', avatarColorIndex: data['avatarColorIndex'] ?? 0,
      timestamp: formattedTime, text: data['text'] ?? '',
      mood: MoodTagX.fromString(data['mood'] ?? 'none'),
      likes: data['likes'] ?? 0, commentCount: data['commentCount'] ?? 0,
      repostCount: data['repostCount'] ?? 0, imageUrls: parsedUrls,
      music: data['music'] != null ? MusicTrack.fromMap(data['music']) : null,
      isRepost: data['isRepost'] ?? false, repostedBy: data['repostedBy'],
      originalPostId: data['originalPostId'], originalAuthor: data['originalAuthor'],
      originalAvatarSeed: data['originalAvatarSeed'],
      originalAvatarColorIndex: data['originalAvatarColorIndex'] ?? 0,
      originalText: data['originalText'], originalTimestamp: data['originalTimestamp'],
      originalImageUrls: originalParsedUrls,
    );
  }
}