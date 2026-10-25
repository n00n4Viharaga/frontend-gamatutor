import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/model/card.dart';
import 'package:gamatutor_kanban/model/cardlist.dart';
import 'package:gamatutor_kanban/pages/card/editCard.dart';
import 'package:gamatutor_kanban/pages/card/focusSession.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/cardService.dart';

class TaskDetailPage extends StatefulWidget {
  final Card card;
  final Function(Card, CardList) onStartSubtask;
  final Function(Card, CardList) onStopSubtask;
  final VoidCallback onNavigateToReflection;
  final Function(Card)? onEditCard;
  final VoidCallback? onDeleteCard;

  const TaskDetailPage({
    super.key,
    required this.card,
    required this.onStartSubtask,
    required this.onStopSubtask,
    required this.onNavigateToReflection,
    this.onEditCard,
    this.onDeleteCard,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final CardService _cardService = CardService();
  String? _strategyName;
  bool _isLoadingStrategy = true;

  @override
  void initState() {
    super.initState();
    _loadLearningStrategy();
  }

  Future<void> _loadLearningStrategy() async {
    if (widget.card.learningId == null || widget.card.learningId!.isEmpty) {
      if (mounted) {
        setState(() {
          _strategyName = 'Pomodoro';
          _isLoadingStrategy = false;
        });
      }
      return;
    }

    try {
      final token = await SecureTokenStorage.getToken();
      if (token != null) {
        final strategy = await CardService.getStrategyById(token, widget.card.learningId!);
        if (mounted) {
          setState(() {
            _strategyName = strategy?.learningStrategy ?? 'Pomodoro';
            _isLoadingStrategy = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _strategyName = 'Pomodoro';
            _isLoadingStrategy = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _strategyName = 'Pomodoro';
          _isLoadingStrategy = false;
        });
      }
    }
  }

  // ★ FUNGSI KONFIRMASI HAPUS
  void _showDeleteConfirmation() {
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Text('🗑️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('Hapus Tugas?', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tugas ini akan dihapus permanen beserta seluruh subtask dan catatannya. Kamu yakin?',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(dialogContext); // Tutup dialog
              widget.onDeleteCard?.call(); // Panggil fungsi hapus dari parent (board.dart)
              Navigator.pop(context, true); // Kembali ke Board
            },
            child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final String currentColumn = card.computedColumn.toLowerCase();

    final bool isTaskStarted = card.startTime != null;
    final bool isStrikeThroughEnabled = currentColumn != 'planning';

    // Konfigurasi Tombol Bawah
    String bottomButtonText = 'Mulai Sesi Fokus';
    Color bottomButtonColor = const Color(0xFF6366F1);
    VoidCallback? onBottomButtonPressed;

    if (currentColumn == 'planning') {
      bottomButtonText = 'Mulai Sesi Fokus';
      bottomButtonColor = const Color(0xFF6366F1);
      onBottomButtonPressed = () => _handleStartSession();
    } else if (currentColumn == 'monitoring') {
      bottomButtonText = 'Lanjut Sesi Fokus';
      bottomButtonColor = const Color(0xFF3B82F6);
      onBottomButtonPressed = () => _handleResumeSession();
    } else if (currentColumn == 'controlling') {
      bottomButtonText = 'Mulai Reflection';
      bottomButtonColor = const Color(0xFF10B981);
      onBottomButtonPressed = widget.onNavigateToReflection;
    } else if (currentColumn == 'reflection') {
      bottomButtonText = 'Tugas Selesai 🎉';
      bottomButtonColor = const Color(0xFF10B981);
      onBottomButtonPressed = null;
    }

    final totalSub = card.subtasks.length;
    final completedSub = card.subtasks.where((s) => s.endTimeList != null).length;
    final double progressRatio = totalSub > 0 ? (completedSub / totalSub) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Background abu terang
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
              onPressed: () => Navigator.pop(context, true),
            ),
          ),
        ),
        title: const Text(
          'Detail Tugas 📝',
          style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══════════════════════════════════════════
            // 1. HEADER (Status, Title, Strategy)
            // ═══════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.show_chart_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 4),
                            Text(
                              currentColumn.toUpperCase(),
                              style: const TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      // Strategy Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF9333EA)),
                            const SizedBox(width: 4),
                            _isLoadingStrategy
                                ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(
                                    _strategyName ?? 'Pomodoro',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFF9333EA)),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    card.title ?? 'Tanpa Judul',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.courseName ?? 'Mata Kuliah',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════
            // 2. BENTO GRID: Due Date & Priority
            // ═══════════════════════════════════════════
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text('Deadline', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.deadline != null ? '${card.deadline!.day}/${card.deadline!.month}/${card.deadline!.year}' : 'Tidak ada',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.flag_rounded, size: 14, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Text('Prioritas', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          card.priority?.toUpperCase() ?? 'MEDIUM',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w900,
                            color: card.priority?.toLowerCase() == 'high' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════
            // 3. DESKRIPSI & CATATAN
            // ═══════════════════════════════════════════
            if (card.description != null && card.description!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deskripsi 📄', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Text(card.description!, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (card.notes != null && card.notes!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFDE68A))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.note_alt_rounded, size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text('Catatan Fokus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(card.notes!, style: const TextStyle(fontSize: 13, color: Color(0xFF92400E), height: 1.5, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ═══════════════════════════════════════════
            // 4. SUBTASKS
            // ═══════════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Langkah Kecil 🪜', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      Text('$completedSub/$totalSub', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: currentColumn == 'planning' ? 0.0 : progressRatio,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  if (card.subtasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Belum ada langkah kecil.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                    ...card.subtasks.map((subtask) {
                      final bool isDone = isStrikeThroughEnabled && (subtask.endTimeList != null);
                      final bool isStarted = subtask.startTimeList != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: isDone ? const Color(0xFF10B981) : Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                subtask.subTitle ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                  color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Tombol Play/Stop Subtask
                            if (!isStarted && !isDone)
                              InkWell(
                                onTap: () async {
                                  await widget.onStartSubtask(card, subtask);
                                  if (mounted) setState(() {});
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle),
                                  child: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            if (isStarted && !isDone)
                              InkWell(
                                onTap: () async {
                                  await widget.onStopSubtask(card, subtask);
                                  if (mounted) setState(() {});
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                  child: const Icon(Icons.stop_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            if (isDone)
                              const Text('Selesai', style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══════════════════════════════════════════
            // 5. REFERENCES (URL)
            // ═══════════════════════════════════════════
            if (card.urlCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Link Referensi 🔗', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    const SizedBox(height: 12),
                    ...card.urlList.map((urlItem) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, size: 16, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                urlItem,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6), decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
      
      // ═══════════════════════════════════════════
      // BOTTOM NAVIGATION BAR (FLOATING STYLE)
      // ═══════════════════════════════════════════
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Tombol Edit
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  onPressed: (currentColumn == 'controlling' || currentColumn == 'reflection')
                      ? null // Disable edit jika sudah selesai
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditTaskPage(
                                card: widget.card,
                                onSaveUpdatedCard: (updatedCard) {
                                  if (widget.onEditCard != null) {
                                    widget.onEditCard!(updatedCard);
                                  }
                                },
                              ),
                            ),
                          );
                          if (mounted) {
                            setState(() => _isLoadingStrategy = true);
                            _loadLearningStrategy();
                          }
                        },
                  icon: Icon(
                    Icons.edit_rounded,
                    color: (currentColumn == 'controlling' || currentColumn == 'reflection')
                        ? Colors.grey.shade400
                        : const Color.fromARGB(255, 81, 84, 241),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              
              // Tombol Utama (Fokus/Reflection)
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onBottomButtonPressed,
                    icon: Icon(
                      currentColumn == 'planning' || currentColumn == 'monitoring' 
                          ? Icons.play_circle_fill_rounded 
                          : Icons.rate_review_rounded, 
                      color: Colors.white, 
                      size: 20
                    ),
                    label: Text(
                      bottomButtonText,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bottomButtonColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Tombol Hapus
              Container(
                decoration: BoxDecoration(
                  color: isTaskStarted ? const Color(0xFFF1F5F9) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  // ★ LOGIKA HAPUS: Jika sudah mulai (startTime != null), tombol mati.
                  onPressed: isTaskStarted ? null : _showDeleteConfirmation,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: isTaskStarted ? Colors.grey.shade400 : const Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Fungsi untuk memulai sesi fokus dari planning
  void _handleStartSession() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mulai Belajar? 🚀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Kamu mau belajar card ini? Semua subtask akan langsung dimulai secara bersamaan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final token = await SecureTokenStorage.getToken();
                if (token != null) {
                  final nowStr = DateTime.now().toIso8601String();
                  if (widget.card.startTime == null) {
                    await _cardService.updateCard(token, widget.card.cardId!, {
                      'nmMatkul': widget.card.courseName ?? '',
                      'title': widget.card.title ?? '',
                      'description': widget.card.description ?? '',
                      'learningId': widget.card.learningId ?? '',
                      'priority': widget.card.priority ?? 'sedang',
                      'difficulty': widget.card.difficulty ?? 'sedang',
                      'deadline': widget.card.deadline != null ? widget.card.deadline!.toIso8601String().split('T')[0] : null,
                      'startTime': nowStr,
                    });
                  }
                  for (var sub in widget.card.subtasks) {
                    if (sub.startTimeList == null && sub.clId != null) {
                      await _cardService.updateCardList(token, widget.card.cardId!, sub.clId!, {'subTitle': sub.subTitle, 'startTimeList': nowStr});
                      sub.startTimeList = DateTime.parse(nowStr);
                    }
                  }
                  widget.card.startTime = DateTime.parse(nowStr);
                }
              } catch (e) {
                debugPrint('Gagal mencatat start otomatis: $e');
              }

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FocusSessionPage(
                    card: widget.card,
                    onStartSubtask: widget.onStartSubtask,
                    onStopSubtask: widget.onStopSubtask,
                    onNavigateToReflection: () {
                      Navigator.pop(context);
                      widget.onNavigateToReflection();
                    },
                  ),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
            child: const Text('Ya, Mulai', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk lanjut sesi fokus dari monitoring
  void _handleResumeSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FocusSessionPage(
          card: widget.card,
          onStartSubtask: widget.onStartSubtask,
          onStopSubtask: widget.onStopSubtask,
          onNavigateToReflection: () {
            Navigator.pop(context);
            widget.onNavigateToReflection();
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}