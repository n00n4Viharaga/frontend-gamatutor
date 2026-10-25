import 'dart:async';

import 'package:avatar_builder/avatar_builder.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gamatutor_kanban/model/card.dart';
import 'package:gamatutor_kanban/model/cardlist.dart';
import 'package:gamatutor_kanban/pages/card/editCard.dart';
import 'package:gamatutor_kanban/pages/dashboard/widgets/user_avatar_profile.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/avatarService.dart';
import 'package:gamatutor_kanban/service/avatarService.dart' as AvatarService;
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:confetti/confetti.dart';
import 'package:gamatutor_kanban/model/avatar_models.dart';

class FocusSessionPage extends StatefulWidget {
  final Card card;
  final Function(Card, CardList) onStartSubtask;
  final Function(Card, CardList) onStopSubtask;
  final VoidCallback onNavigateToReflection;

  const FocusSessionPage({
    super.key,
    required this.card,
    required this.onStartSubtask,
    required this.onStopSubtask,
    required this.onNavigateToReflection,
  });

  @override
  State<FocusSessionPage> createState() => _FocusSessionPageState();
}

class _FocusSessionPageState extends State<FocusSessionPage>
    with WidgetsBindingObserver {
  final CardService _cardService = CardService();
  String? _strategyName;
  bool _isLoadingStrategy = true;

  late Timer _timer;
  int _secondsElapsed = 0;
  bool _isPaused = false;
  List<Card> _cardsList = [];

  // ★ PISAHKAN CONTROLLER UNTUK CATATAN DAN DISTRAKSI
  late final TextEditingController _notesController = TextEditingController(
    text: widget.card.notes ?? '',
  );
  late final TextEditingController _distractionController =
      TextEditingController();

  int _blastedCount = 0;
  late ConfettiController _confettiController;

  // Avatar setup
  Avataaar? _currentAvatar;

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadLearningStrategy();
    _startFocusTimer();
    _loadCards();
    _persistFocusState();
    _restoreFocusState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final configJson = await AvatarService.getUserAvatarConfig();
    if (configJson != null && mounted) {
      setState(
        () => _currentAvatar = AvatarConfig.fromJson(configJson).toAvataaar(),
      );
    } else if (mounted) {
      setState(() => _currentAvatar = Avataaar.random());
    }
  }
  // ... (Fungsi _loadCards, _startFocusTimer, dll dibiarkan sama) ...

  Future<void> _loadCards() async {
    final token = await SecureTokenStorage.getToken();
    if (token != null) {
      try {
        final apiCards = await _cardService.getCardsByUser(token);
        if (mounted) {
          setState(() => _cardsList = apiCards);
        }
      } catch (e) {
        debugPrint('Gagal load cards: $e');
      }
    }
  }

  void _startFocusTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  Future<void> _persistFocusState() async {
    await SecureTokenStorage.saveFocusStartTime(
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _restoreFocusState() async {
    final startStr = await SecureTokenStorage.getFocusStartTime();
    if (startStr != null) {
      final start = DateTime.parse(startStr);
      final now = DateTime.now();
      final diff = now.difference(start).inSeconds;
      setState(() => _secondsElapsed = diff);
    }
  }

  Future<void> _scheduleFocusReminder() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Fokus Mode Masih Aktif',
      body: 'Sudah 2 menit kamu keluar, jangan lupa akhiri sesi!',
      scheduledDate: tz.TZDateTime.now(tz.local)
          .add(const Duration(minutes: 2)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'focus_channel',
          'Focus Mode',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(settings: initSettings);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _scheduleFocusReminder();
    } else if (state == AppLifecycleState.resumed) {
      _restoreFocusState();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    _notesController.dispose();
    _distractionController.dispose(); // ★ Dispose controller baru
    _confettiController.dispose();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadLearningStrategy() async {
    if (widget.card.learningId == null || widget.card.learningId!.isEmpty) {
      if (mounted) {
        // ★ Pastikan ada ini
        setState(() {
          _strategyName = 'Video Tutorial';
          _isLoadingStrategy = false;
        });
      }
      return;
    }

    try {
      final token = await SecureTokenStorage.getToken();
      if (token != null) {
        final strategy = await CardService.getStrategyById(
          token,
          widget.card.learningId!,
        );
        if (mounted) {
          // ★ Pastikan ada ini
          setState(() {
            _strategyName = strategy?.learningStrategy ?? 'Video Tutorial';
            _isLoadingStrategy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        // ★ Pastikan ada ini
        setState(() {
          _strategyName = 'Video Tutorial';
          _isLoadingStrategy = false;
        });
      }
    }
  }

  Future<void> launchSpotifyPlaylist() async {
    final Uri spotifyAppUri = Uri.parse(
      'spotify://playlist/37i9dQZF1DX8Uebhn9wzrS',
    );
    final Uri spotifyWebUri = Uri.parse(
      'https://open.spotify.com/playlist/37i9dQZF1DX8Uebhn9wzrS',
    );
    try {
      if (await canLaunchUrl(spotifyAppUri)) {
        await launchUrl(spotifyAppUri);
      } else {
        await launchUrl(spotifyWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching Spotify: $e');
    }
  }

  String _getPersonalBest() {
    int? bestMinutes;
    for (var card in _cardsList) {
      if (card.startTime != null && card.endTime != null) {
        final diff = card.endTime!.difference(card.startTime!);
        if (diff.inMinutes > 0) {
          if (bestMinutes == null || diff.inMinutes < bestMinutes) {
            bestMinutes = diff.inMinutes;
          }
        }
      }
    }
    if (bestMinutes == null) return '0MNT';
    final hours = bestMinutes ~/ 60;
    final minutes = bestMinutes % 60;
    return hours > 0 ? '${hours}J ${minutes}M' : '${minutes}MNT';
  }

  Future<void> _saveNotes() async {
    final token = await SecureTokenStorage.getToken();
    if (token != null) {
      final String notesText = _notesController.text.trim();
      if (notesText.isNotEmpty) {
        try {
          await _cardService.updateCard(token, widget.card.cardId!, {
            'notes': notesText,
          });
          widget.card.notes = notesText;
        } catch (e) {
          debugPrint('Gagal menyimpan catatan: $e');
        }
      }
    }
  }

  // --- AKHIRI SELURUH SESI & MASUK KE REFLEKSI ---
  Future<void> _handleEndSession() async {
    _timer.cancel();
    try {
      final token = await SecureTokenStorage.getToken();
      if (token != null) {
        final nowStr = DateTime.now().toIso8601String();
        await _saveNotes();

        for (var sub in widget.card.subtasks) {
          if (sub.endTimeList == null && sub.clId != null) {
            await _cardService.updateCardList(
              token,
              widget.card.cardId!,
              sub.clId!,
              {
                'subTitle': sub.subTitle,
                'startTimeList': sub.startTimeList?.toIso8601String(),
                'endTimeList': nowStr,
              },
            );
            sub.endTimeList = DateTime.parse(nowStr);
          }
        }
        await _cardService.updateCard(token, widget.card.cardId!, {
          'endTime': nowStr,
        });
      }
    } catch (e) {
      debugPrint('Gagal mengakhiri sesi: $e');
    }
    if (!mounted) return;
    widget.onNavigateToReflection();
  }

  // --- JEDA & SESUAIKAN ---
  void _handlePauseAndCustomize() async {
    setState(() => _isPaused = true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskPage(
          card: widget.card,
          onSaveUpdatedCard: (updatedCard) {
            setState(() {});
          },
        ),
      ),
    );
    if (mounted) setState(() => _isPaused = false);
  }

  // --- POP-UP WARNING KELUAR (BACK GESTURE) ---
  Future<bool> _onWillPop() async {
    final bool? exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('👋', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Mau Berhenti?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Sesi fokus kamu akan dijeda dan progres waktu akan berhenti. Yakin mau keluar?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Lanjut Fokus',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Berhenti',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (exit == true) {
      _timer.cancel(); // Matikan timer
      return true; // Izinkan pop navigasi
    }
    return false; // Tahan navigasi
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;

    // ★ BUNGKUS DENGAN PopScope UNTUK MENAHAN TOMBOL BACK
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(
          0xFFF8FAFC,
        ), // Background sedikit abu agar card putih menonjol
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            card.title ?? 'Sesi Fokus',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _handleEndSession,
              child: const Text(
                'AKHIRI',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SPOTIFY MINI PLAYER ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1DB954),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.music_note,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Lo-Fi Beats to Study To • Spotify',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF166534),
                            size: 20,
                          ),
                          onPressed: () => launchSpotifyPlaylist(),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- AVATAR & TIMER (DIPERBAGUS) ---
                  Center(
                    child: Column(
                      children: [
                        // Avatar dengan Lingkaran Glow
                        _currentAvatar != null
                            ? UserAvatarProfile(
                                avatar: _currentAvatar!,
                                size: 100,
                                isCircle: true, // Widget ini otomatis bikin bentuk lingkaran
                              )
                            : Container(
                                // Ini tampilan sementara (Skeleton/Loading) saat avatar belum selesai di-fetch dari API
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                        const SizedBox(height: 12),
                        // Timer Text
                        Text(
                          _formatTimer(_secondsElapsed),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          _isPaused ? 'PAUSED' : 'Avatarmu menemanimu fokus!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isPaused
                                ? const Color(0xFFD97706)
                                : Colors.grey,
                            fontStyle: _isPaused
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tombol Personal Best & Jeda
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.emoji_events_outlined,
                                    size: 14,
                                    color: Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'BEST: ${_getPersonalBest()}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _handlePauseAndCustomize,
                              icon: const Icon(Icons.pause_rounded, size: 14),
                              label: const Text(
                                'Jeda',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF4F46E5),
                                side: const BorderSide(
                                  color: Color(0xFFE0E7FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- STRATEGI BADGE ---
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFEEF2FF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          _isLoadingStrategy
                              ? const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'STRATEGI: ${_strategyName?.toUpperCase() ?? 'POMODORO'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- LANGKAH-LANGKAH / SUBTASKS ---
                  const Text(
                    'LANGKAH-LANGKAH',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (card.subtasks.isEmpty)
                    const Text(
                      'Tidak ada subtask.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else
                    ...card.subtasks.map((subtask) {
                      final bool isDone = subtask.endTimeList != null;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFF0FDF4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDone
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: isDone
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDone
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isDone
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                subtask.subTitle ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isDone
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isDone
                                      ? const Color(0xFF166534)
                                      : const Color(0xFF334155),
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (subtask.startTimeList == null)
                              TextButton(
                                onPressed: () =>
                                    widget.onStartSubtask(card, subtask),
                                child: const Text(
                                  'Mulai',
                                  style: TextStyle(fontSize: 11),
                                ),
                              )
                            else if (subtask.startTimeList != null &&
                                subtask.endTimeList == null)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  minimumSize: const Size(75, 30),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () =>
                                    _handleStopSingleSubtask(subtask),
                                icon: const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Akhiri',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'Selesai',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),

                  // --- DISTRACTION BLASTER (DIPERBAIKI) ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2), // Background pink soft
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: 18,
                                  color: Color(0xFFE11D48),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Distraction Blaster',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFFBE123C),
                                  ),
                                ),
                              ],
                            ),
                            if (_blastedCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '💥 $_blastedCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _distractionController, // ★ Pakai controller terpisah
                          decoration: InputDecoration(
                            hintText: 'Mau buka TikTok? Tulis di sini...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFDA4AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (_distractionController.text.isNotEmpty) {
                                setState(() => _blastedCount++);
                                _distractionController
                                    .clear(); // ★ Hanya hapus input distraksi
                                HapticFeedback.heavyImpact();
                                _confettiController.play();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '💥 BOOM! Distraksi dihancurkan! Fokus lagi yuk.',
                                    ),
                                    backgroundColor: Color(0xFF10B981),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: const Text(
                              'Hancurkan!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- CATATAN BELAJAR (Terpisah) ---
                  const Text(
                    'CATATAN BELAJAR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController, // ★ Pakai controller catatan
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tulis rangkuman atau hal penting di sini...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- TOMBOL SELESAI ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _handleEndSession,
                      icon: const Icon(
                        Icons.rate_review_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Selesai & Beri Refleksi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 20,
                emissionFrequency: 0.05,
                colors: const [
                  Colors.green,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- POP-UP KONFIRMASI SUBTASK ---
  void _handleStopSingleSubtask(CardList subtask) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '✨ Tuntasin subtask ini?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          'Mau tandai "${subtask.subTitle ?? ''}" sebagai selesai?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              _timer.cancel();
              await _saveNotes();
              await widget.onStopSubtask(widget.card, subtask);
              if (!mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text(
              'Gas, Selesai!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
