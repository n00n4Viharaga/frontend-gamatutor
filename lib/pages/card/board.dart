import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/model/card.dart';
import 'package:gamatutor_kanban/model/cardlist.dart';
import 'package:gamatutor_kanban/pages/card/newCard.dart';
import 'package:gamatutor_kanban/pages/card/taskDetail.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:confetti/confetti.dart';

class KanbanBoardView extends StatefulWidget {
  const KanbanBoardView({super.key});

  @override
  State<KanbanBoardView> createState() => _KanbanBoardViewState();
}

class _KanbanBoardViewState extends State<KanbanBoardView> {
  final CardService _cardService = CardService();
  List<Card> _cards = [];
  bool _isLoading = true;
  bool _isFabExpanded = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _fetchKanbanCards();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose(); // ★ Tambahkan ini
    super.dispose();
  }

  Future<void> _saveCardToBackend(Map<String, dynamic> cardData) async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;

      final createdCard = await _cardService.createCard(token, cardData);

      final String cardId =
          (createdCard['card_id'] ?? createdCard['cardId'] ?? createdCard['id'])
              .toString();

      if (cardData['subtasks'] != null &&
          (cardData['subtasks'] as List).isNotEmpty) {
        for (var subTitle in cardData['subtasks']) {
          await _cardService.createCardList(token, cardId, {
            'subTitle': subTitle,
          });
        }
      }

      if (cardData['collaborators'] != null &&
          (cardData['collaborators'] as List).isNotEmpty) {
        for (var friendUserId in cardData['collaborators']) {
          await _cardService.addCollaborator(token, cardId, {
            'friendId': friendUserId,
            'role': 'member',
          });
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas baru berhasil ditambahkan ke Planning!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan tugas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchKanbanCards() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (!mounted || token == null) return;

      final fetchedCards = await _cardService.getCardsByUser(token);
      if (!mounted) return;

      setState(() {
        _cards = fetchedCards;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String getActiveColumn(Card card) {
      // 1. Jika refleksi sudah diisi/selesai -> Reflection
      if (card.reflectionCompletedAt != null &&
          card.reflectionCompletedAt!.isNotEmpty) {
        return 'reflection';
      }

      // 2. Jika sudah ada endTime atau semua subtask selesai -> Controlling
      bool allSubtasksDone =
          card.subtasks.isNotEmpty &&
          card.subtasks.every((s) => s.endTimeList != null);
      if (card.endTime != null || allSubtasksDone) {
        return 'controlling';
      }

      // 3. Jika kartu utama sudah dimulai (startTime card != null) -> Monitoring
      // (Kita tidak lagi otomatis menjadikan Monitoring hanya karena subtask ter-start otomatis, melainkan berdasarkan card.startTime)
      if (card.startTime != null) {
        return 'monitoring';
      }

      // 4. Sisanya tetap Planning
      return 'planning';
    }

    final planningCards = _cards
        .where((c) => getActiveColumn(c) == 'planning')
        .toList();
    final monitoringCards = _cards
        .where((c) => getActiveColumn(c) == 'monitoring')
        .toList();
    final controllingCards = _cards
        .where((c) => getActiveColumn(c) == 'controlling')
        .toList();
    final reflectionCards = _cards
        .where((c) => getActiveColumn(c) == 'reflection')
        .toList();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Board',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_cards.length} Tugas Aktif',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.notifications_none,
                                  color: Colors.grey,
                                ),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'All',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.65,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildColumn(
                                'Planning',
                                Colors.lightBlue,
                                planningCards,
                                allowAdd: true,
                              ),
                              const SizedBox(width: 16),
                              _buildColumn(
                                'Monitoring',
                                Colors.blue,
                                monitoringCards,
                                allowAdd: false,
                              ),
                              const SizedBox(width: 16),
                              _buildColumn(
                                'Controlling',
                                Colors.orange,
                                controllingCards,
                                allowAdd: false,
                              ),
                              const SizedBox(width: 16),
                              _buildColumn(
                                'Reflection',
                                Colors.green,
                                reflectionCards,
                                allowAdd: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          floatingActionButton: Stack(
            alignment: Alignment.bottomRight,
            children: [
              if (_isFabExpanded) ...[
                GestureDetector(
                  onTap: () {
                    setState(() => _isFabExpanded = false);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 140),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_outline, color: Color(0xFF4F46E5)),
                        SizedBox(width: 8),
                        Text(
                          'Collaboration',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _isFabExpanded = false);
                    _showAddCardDialog();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 75),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.library_add, color: Color(0xFF4F46E5)),
                        SizedBox(width: 8, height: 2),
                        Text(
                          'Add Card',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              FloatingActionButton(
                backgroundColor: const Color(0xFF4F46E5),
                onPressed: () {
                  HapticFeedback.lightImpact(); // ★ Efek getar saat ditekan
                  setState(() {
                    _isFabExpanded = !_isFabExpanded;
                  });
                },
                child: AnimatedRotation(
                  turns: _isFabExpanded ? 0.125 : 0, // ★ Putar 45 derajat (seperti tanda X)
                  duration: const Duration(milliseconds: 250),
                  child: Icon(
                    _isFabExpanded ? Icons.add : Icons.add, // Ikon tetap plus, yang berputar adalah kontainernya
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        // ★ WIDGET CONFETTI OVERLAY
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.05,
            numberOfParticles: 30,
            gravity: 0.2,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(
    String title,
    Color dotColor,
    List<Card> cards, {
    required bool allowAdd,
  }) {
    final String colType = title.toLowerCase();
    Color bgColor;
    Color textColor;
    String emoji;

    switch (title) {
      case 'Planning':
        bgColor = const Color(0xFFEFF6FF); // Biru Muda
        textColor = const Color(0xFF2563EB);
        emoji = '📝';
        break;
      case 'Monitoring':
        bgColor = const Color(0xFFFFFBEB); // Kuning Muda
        textColor = const Color(0xFFD97706);
        emoji = '👀';
        break;
      case 'Controlling':
        bgColor = const Color(0xFFFDF2F8); // Pink Muda
        textColor = const Color(0xFFDB2777);
        emoji = '🎮';
        break;
      case 'Reflection':
      default:
        bgColor = const Color(0xFFECFDF5); // Hijau Muda
        textColor = const Color(0xFF059669);
        emoji = '🧘‍♂️';
        break;
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Background kolom sedikit abu
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER KOLOM
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${cards.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 👇 DIBUNGKUS EXPANDED AGAR AMAN DARI OVERFLOW DAN BISA DI-SCROLL
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cards.length + (allowAdd ? 1 : 0),
              itemBuilder: (context, index) {
                if (allowAdd && index == cards.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: InkWell(
                      onTap: () => _showAddCardDialog(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.add, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(
                                'Tambah tugas',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final card = cards[index];
                final totalSubtasks = card.subtasks.length;
                final completedSubtasks = card.subtasks
                    .where((s) => s.endTimeList != null)
                    .length;

                Color priorityColor = Colors.grey;
                if (card.priority?.toLowerCase() == 'high') priorityColor = const Color(0xFFEF4444);
                if (card.priority?.toLowerCase() == 'medium') priorityColor = const Color(0xFFF59E0B);
                if (card.priority?.toLowerCase() == 'low') priorityColor = const Color(0xFF10B981);


                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailPage(
                          card: card,
                          onStartSubtask: (selectedCard, subtask) =>
                              _handleStartSubtask(selectedCard, subtask),
                          onStopSubtask: (selectedCard, subtask) =>
                              _handleStopSubtask(selectedCard, subtask),
                          onNavigateToReflection: () =>
                              _showReflectionDialog(card),
                          onEditCard: (updatedCard) {
                            setState(() {
                              int index = _cards.indexWhere(
                                (c) => c.cardId == updatedCard.cardId,
                              );
                              if (index != -1) {
                                _cards[index] = updatedCard;
                              }
                            });
                          },
                        ),
                      ),
                    ).then((_) => _fetchKanbanCards());
                  },
                  // ★ 2. BUNGKUS DENGAN INTRINSICHEIGHT & ROW
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: IntrinsicHeight( // ★ Wajib agar garis prioritas menyesuaikan tinggi card
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ★ 3. GARIS WARNA PRIORITAS DI SISI KIRI
                            Container(
                              width: 6,
                              color: priorityColor,
                            ),
                            
                            // ★ 4. ISI CARD ANDA (Dibungkus Expanded)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    card.title ?? 'Tanpa Judul',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    card.courseName ?? 'Mata Kuliah',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade600,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (totalSubtasks > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  colType == 'planning'
                                                      ? '0/$totalSubtasks'
                                                      : '$completedSubtasks/$totalSubtasks',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (card.description != null && card.description!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            card.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                        if (card.subtasks.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          ...card.subtasks.map((subtask) {
                                            final bool isDone = subtask.endTimeList != null;

                                            return Container(
                                              margin: const EdgeInsets.symmetric(vertical: 3),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      subtask.subTitle ?? '',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: isDone ? Colors.grey.shade400 : Colors.grey.shade800,
                                                        decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (subtask.startTimeList == null)
                                                    SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child: IconButton(
                                                        onPressed: () => _handleStartSubtask(card, subtask),
                                                        icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        style: IconButton.styleFrom(
                                                          backgroundColor: const Color(0xFF4F46E5),
                                                          shape: const CircleBorder(),
                                                        ),
                                                      ),
                                                    ),
                                                  if (subtask.startTimeList != null && subtask.endTimeList == null)
                                                    SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child: IconButton(
                                                        onPressed: () => _handleStopSubtask(card, subtask),
                                                        icon: const Icon(Icons.stop_rounded, size: 16, color: Colors.white),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        style: IconButton.styleFrom(
                                                          backgroundColor: const Color(0xFFEF4444),
                                                          shape: const CircleBorder(),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    color: const Color(0xFFF8FAFC),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (card.priority != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: priorityColor.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              card.priority!.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: priorityColor,
                                              ),
                                            ),
                                          ),
                                        if (card.urlCount > 0)
                                          Row(
                                            children: [
                                              Icon(Icons.link, size: 12, color: Colors.grey.shade500),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${card.urlCount}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (colType == 'controlling')
                                          ElevatedButton.icon(
                                            onPressed: () => _showReflectionDialog(card),
                                            icon: const Icon(Icons.rate_review_outlined, size: 12, color: Colors.white),
                                            label: const Text(
                                              'Mulai Refleksi',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              elevation: 0,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCardDialog() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCardView(
          token: token,
          onCardCreated: (cardData) async {
            await _saveCardToBackend(cardData);
            _fetchKanbanCards();
          },
        ),
      ),
    );

    if (result == true) {
      _fetchKanbanCards();
    }
  }

  Future<void> _handleStartSubtask(Card card, CardList subtask) async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;

      final nowStr = DateTime.now().toIso8601String();

      if (card.startTime == null) {
        await _cardService.updateCard(token, card.cardId!, {
          'nmMatkul': card.courseName ?? '',
          'title': card.title ?? '',
          'description': card.description ?? '',
          'learningId': card.learningId ?? '',
          'priority': card.priority ?? 'sedang',
          'difficulty': card.difficulty ?? 'sedang',
          'deadline': card.deadline != null
              ? card.deadline!.toIso8601String().split('T')[0]
              : null,
          'startTime': nowStr,
        });
      }

      if (subtask.clId != null) {
        await _cardService.updateCardList(token, card.cardId!, subtask.clId!, {
          'subTitle': subtask.subTitle,
          'startTimeList': nowStr,
        });
      }

      _fetchKanbanCards();
    } catch (e) {
      debugPrint('Gagal memulai subtask: $e');
    }
  }

  Future<void> _handleStopSubtask(Card card, CardList subtask) async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;

      final nowStr = DateTime.now().toIso8601String();

      if (subtask.clId != null) {
        await _cardService.updateCardList(token, card.cardId!, subtask.clId!, {
          'subTitle': subtask.subTitle,
          'startTimeList': subtask.startTimeList?.toIso8601String(),
          'endTimeList': nowStr,
        });
      }

      final remainingUnfinished = card.subtasks
          .where((s) => s.clId != subtask.clId && s.endTimeList == null)
          .length;

      if (remainingUnfinished == 0) {
        await _cardService.updateCard(token, card.cardId!, {'endTime': nowStr});
      }

      _fetchKanbanCards();
    } catch (e) {
      debugPrint('Gagal menghentikan subtask: $e');
    }
  }

  void _showReflectionDialog(Card card) async {
    String? strategyLabel = 'Strategi Belajar';
    try {
      final token = await SecureTokenStorage.getToken();
      if (token != null && card.learningId != null) {
        final strategy = await CardService.getStrategyById(
          token,
          card.learningId!,
        );
        if (strategy != null) {
          strategyLabel = strategy.learningStrategy;
        }
      }
    } catch (e) {
      debugPrint('Gagal memuat strategi: $e');
    }
    final String cardTitle = card.title ?? 'Tugas Ini';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        int selectedEffectiveness = 3;
        int selectedConfidence = 3;
        String goalAchievement = 'Ya';
        final TextEditingController notesController = TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateModal) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text(
                        'Sesi Selesai! Kamu Luar Biasa ✨',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seberapa efektif strategi $strategyLabel bagimu?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            Icons.sentiment_satisfied_alt,
                            color: selectedEffectiveness == index + 1
                                ? const Color(0xFF4F46E5)
                                : Colors.grey.shade400,
                          ),
                          onPressed: () {
                            setStateModal(() {
                              selectedEffectiveness = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Seberapa yakin kamu menguasai materi ini sekarang?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: selectedConfidence.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      activeColor: const Color(0xFF4F46E5),
                      label: '$selectedConfidence',
                      onChanged: (val) {
                        setStateModal(() {
                          selectedConfidence = val.toInt();
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Apakah tugas ini membantumu mencapai $cardTitle?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Ya', 'Sebagian', 'Tidak'].map((val) {
                        bool isSelected = goalAchievement == val;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? const Color(0xFFEEF2FF)
                                    : Colors.white,
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : Colors.grey.shade300,
                                ),
                              ),
                              onPressed: () {
                                setStateModal(() {
                                  goalAchievement = val;
                                });
                              },
                              child: Text(
                                val,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : Colors.black,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ada catatan untuk dirimu di masa depan? (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Misal: Perlu latihan lebih banyak...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          _confettiController.play(); // Mainkan Confetti
                          HapticFeedback.heavyImpact(); // Getar HP
                          try {
                            final token = await SecureTokenStorage.getToken();
                            if (token == null) return;

                            await _cardService.updateCard(token, card.cardId!, {
                              'reflectionCompletedAt': DateTime.now()
                                  .toIso8601String(),
                              'satisfactionRating': selectedEffectiveness,
                              'reflectionQ1Strategy': selectedEffectiveness,
                              'reflectionQ2Confidence': selectedConfidence,
                              'reflectionQ3WhatLearned': goalAchievement,
                              'reflectionQ4Value': notesController.text.trim(),
                              'notes': notesController.text.trim(),
                            });

                            _fetchKanbanCards();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '🔥 Kerja bagus! Kamu menyelesaikan 1 tugas.',
                                ),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } catch (e) {
                            debugPrint('Gagal menyimpan refleksi: $e');
                          }
                        },
                        child: const Text(
                          'Simpan & Selesaikan Tugas',
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
            );
          },
        );
      },
    );
  }
}
