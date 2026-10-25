// config/profile_meta.dart
import 'package:flutter/material.dart';

/// Metadata visual untuk setiap profil MSLQ
class ProfileMeta {
  final String key;              // 'organization', 'elaboration', dst
  final String displayName;      // 'The Architect'
  final String emoji;            // untuk display besar & shareable
  final IconData icon;           // untuk chip / compact UI
  final Color color;             // warna brand utama profil
  final Color lightBg;           // untuk background soft
  final String tagline;          // deskripsi singkat 1 baris
  final String description;      // penjelasan lebih panjang

  const ProfileMeta({
    required this.key,
    required this.displayName,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.lightBg,
    required this.tagline,
    required this.description,
  });
}

/// Master mapping: 6 kategori MSLQ + fallback
const Map<String, ProfileMeta> kProfileMeta = {
  'organization': ProfileMeta(
    key: 'organization',
    displayName: 'Rapi Jali',
    emoji: '🏗️',
    icon: Icons.architecture_rounded,
    color: Color(0xFF6366F1),
    lightBg: Color(0xFFEEF2FF),
    tagline: 'Kamu suka bikin struktur dari kekacauan',
    description:
        'Kamu paling kuat saat menyusun materi yang berantakan jadi rapi. '
        'Mind map, tabel, dan outline adalah senjata utamamu.',
  ),
  'time_management': ProfileMeta(
    key: 'time_management',
    displayName: 'Deadline Slayer',
    emoji: '⚔️',
    icon: Icons.event_note_rounded,
    color: Color(0xFFEC4899),
    lightBg: Color(0xFFFCE7F3),
    tagline: 'Deadline adalah teman, bukan musuh',
    description:
        'Kamu jago mengatur waktu. Kalender, to-do list, dan jadwal belajar '
        'udah jadi bagian hidupmu.',
  ),
  'metacognitive_self_regulation': ProfileMeta(
    key: 'metacognitive_self_regulation',
    displayName: 'Sadar Diri',
    emoji: '🪞',
    icon: Icons.psychology_alt_rounded,
    color: Color(0xFF8B5CF6),
    lightBg: Color(0xFFF3E8FF),
    tagline: 'Kamu sadar saat belajar & saat tidak',
    description:
        'Kamu bisa mendeteksi kebingungan sendiri dan mengubah strategi. '
        'Kesadaran diri ini adalah superpower.',
  ),
  'help_seeking': ProfileMeta(
    key: 'help_seeking',
    displayName: 'Anti Malu Bertanya',
    emoji: '🤝',
    icon: Icons.groups_rounded,
    color: Color(0xFF06B6D4),
    lightBg: Color(0xFFCFFAFE),
    tagline: 'Belajar bareng lebih seru daripada sendirian',
    description:
        'Kamu nggak takut bertanya ke dosen, asisten, atau teman. '
        'Diskusi adalah caramu memahami materi.',
  ),
  'elaboration': ProfileMeta(
    key: 'elaboration',
    displayName: 'Juru Analogi',
    emoji: '🧠',
    icon: Icons.hub_rounded,
    color: Color.fromARGB(255, 92, 156, 228),
    lightBg: Color(0xFFFEF3C7),
    tagline: 'Kamu menghubungkan titik-titik materi',
    description:
        'Kamu cepat mengaitkan materi baru dengan yang lama, membuat analogi, '
        'dan menjelaskan ulang dengan bahasamu sendiri.',
  ),
  'rehearsal': ProfileMeta(
    key: 'rehearsal',
    displayName: 'Mesin Hafalan',
    emoji: '📚',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF10B981),
    lightBg: Color(0xFFD1FAE5),
    tagline: 'Latihan berulang adalah kunci hafalanmu',
    description:
        'Kamu paling efektif dengan pengulangan: flashcard, latihan soal, '
        'dan membaca ulang berkali-kali.',
  ),
  'all_rounder': ProfileMeta(
    key: 'all_rounder',
    displayName: 'Powerful',
    emoji: '⭐',
    icon: Icons.workspace_premium_rounded,
    color: Color.fromARGB(255, 8, 140, 234),
    lightBg: Color(0xFFFEF9C3),
    tagline: 'Seimbang di semua aspek — jarang, tapi nyata',
    description:
        'Kamu punya strategi belajar yang merata di semua kategori. '
        'Tidak ada titik lemah yang menonjol.',
  ),
};

/// Fallback untuk user yang belum quiz
const ProfileMeta kLearnerMeta = ProfileMeta(
  key: 'learner',
  displayName: 'Misterius',
  emoji: '❓',
  icon: Icons.auto_awesome_rounded,
  color: Color(0xFF94A3B8),
  lightBg: Color(0xFFF1F5F9),
  tagline: 'Profil belajarmu belum terpetakan',
  description: 'Ikuti kuis 24 soal untuk mengenali gaya belajarmu.',
);

/// Helper: cari metadata dari nama profil (case-insensitive, fuzzy)
ProfileMeta resolveProfileMeta(String? profileName, {String? dominantStrategy}) {
  // 1) Coba via dominant strategy (paling akurat)
  if (dominantStrategy != null && kProfileMeta.containsKey(dominantStrategy)) {
    return kProfileMeta[dominantStrategy]!;
  }

  // 2) Coba via display name
  if (profileName != null) {
    for (final meta in kProfileMeta.values) {
      if (meta.displayName.toLowerCase() == profileName.toLowerCase()) {
        return meta;
      }
    }
    // Fuzzy match untuk All-Rounder
    if (profileName.toLowerCase().contains('all-rounder') ||
        profileName.toLowerCase().contains('all rounder')) {
      return kProfileMeta['all_rounder']!;
    }
  }

  // 3) Fallback
  return kLearnerMeta;
}