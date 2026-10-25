import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/model/card.dart';
import 'package:gamatutor_kanban/model/cardlist.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class EditTaskPage extends StatefulWidget {
  final Card card;
  final Function(Card) onSaveUpdatedCard;

  const EditTaskPage({
    super.key,
    required this.card,
    required this.onSaveUpdatedCard,
  });

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _matkulController = TextEditingController(text: widget.card.courseName ?? '');
  late final TextEditingController _titleController = TextEditingController(text: widget.card.title ?? '');
  late final TextEditingController _descController = TextEditingController(text: widget.card.description ?? '');

  late String _selectedPriority;
  late String _selectedDifficulty;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  DateTime? _selectedDeadline;
  TimeOfDay? _selectedTime;

  final List<TextEditingController> _subTaskControllers = [];
  final List<TextEditingController> _urlControllers = [];

  List<dynamic> _strategies = [];
  List<String> _unlockedFeatures = [];
  String? _selectedStrategyId;
  bool _isLoadingStrategies = true;

  late List<CardList> _originalSubtasks;

  final List<dynamic> _friendsList = [];
  final List<String> _selectedCollaborators = [];
  bool _isLoadingFriends = false;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.card.priority ?? 'medium';
    _selectedDifficulty = widget.card.difficulty ?? 'medium';
    _selectedDeadline = widget.card.deadline ?? DateTime.now();
    _selectedStrategyId = widget.card.learningId;
    _originalSubtasks = List.from(widget.card.subtasks);
    _loadFriendsData();

    if (widget.card.deadline != null) {
      _dateController.text = "${widget.card.deadline!.day} ${_getMonthName(widget.card.deadline!.month)} ${widget.card.deadline!.year}";
      _timeController.text = "${widget.card.deadline!.hour.toString().padLeft(2, '0')}:${widget.card.deadline!.minute.toString().padLeft(2, '0')}";
      _selectedTime = TimeOfDay(hour: widget.card.deadline!.hour, minute: widget.card.deadline!.minute);
    }

    if (widget.card.subtasks.isNotEmpty) {
      for (var sub in widget.card.subtasks) {
        _subTaskControllers.add(TextEditingController(text: sub.subTitle ?? ''));
      }
    } else {
      _subTaskControllers.add(TextEditingController());
    }

    if (widget.card.urlList.isNotEmpty) {
      for (var url in widget.card.urlList) {
        _urlControllers.add(TextEditingController(text: url));
      }
    } else {
      _urlControllers.add(TextEditingController());
    }

    _loadStrategyData();
  }

  void _addSubTaskField() => setState(() => _subTaskControllers.add(TextEditingController()));
  void _addURLField() => setState(() => _urlControllers.add(TextEditingController()));

  Future<void> _loadStrategyData() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoadingStrategies = false);
        return;
      }

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final String userId = decodedToken['userId'] ?? decodedToken['id'];

      final results = await Future.wait([
        CardService.getAllStrategies(),
        rekomendasiService.getUnlockedFeatures(userId, token),
      ]);

      if (mounted) {
        setState(() {
          _strategies = results[0];
          _unlockedFeatures = results[1] as List<String>;
          _isLoadingStrategies = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading strategy data: $e');
      if (mounted) setState(() => _isLoadingStrategies = false);
    }
  }

  Future<void> _loadFriendsData() async {
    if (mounted) setState(() => _isLoadingFriends = true);
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;
      if (mounted) setState(() => _isLoadingFriends = false);
    } catch (e) {
      debugPrint('Error loading friends: $e');
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  void _showAddCollaboratorDialog() {
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cari & Tambah Teman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(hintText: 'Masukkan username...', prefixIcon: Icon(Icons.search)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final query = searchController.text.trim();
                if (query.isNotEmpty) {
                  Navigator.pop(context);
                  try {
                    final token = await SecureTokenStorage.getToken();
                    if (token != null && widget.card.cardId != null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil menambahkan kolaborator!'), backgroundColor: Colors.green));
                      _loadFriendsData();
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Tambah', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  bool get _isHelpSeekingStrategy {
    if (_selectedStrategyId == null) return false;
    final selected = _strategies.firstWhere((s) => s['learningId'] == _selectedStrategyId, orElse: () => null);
    if (selected == null) return false;
    final keyCode = (selected['keyCode'] ?? '').toString().toLowerCase();
    final name = (selected['learningStrategy'] ?? '').toString().toLowerCase();
    return keyCode.contains('help') || name.contains('help');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline != null && _selectedDeadline!.isAfter(today) ? _selectedDeadline! : today,
      firstDate: today,
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
        _dateController.text = "${picked.day} ${_getMonthName(picked.month)} ${picked.year}";
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      });
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  @override
  void dispose() {
    _matkulController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    for (var c in _subTaskControllers) { c.dispose(); }
    for (var c in _urlControllers) { c.dispose(); }
    super.dispose();
  }

  Widget _buildSectionHeader(String emoji, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    bool enabled = true,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      enabled: enabled,
      onTap: onTap,
      validator: validator,
      style: TextStyle(color: enabled ? const Color(0xFF0F172A) : Colors.grey.shade600, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: enabled ? const Color(0xFF6366F1) : Colors.grey.shade400),
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: enabled ? const Color(0xFFE2E8F0) : Colors.transparent)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ★ LOGIKA BARU: Pisahkan antara Info Utama & Status Selesai
    final bool isMainInfoLocked = widget.card.startTime != null; // Terkunci jika tugas utama sudah jalan
    final bool isCardFinished = widget.card.reflectionCompletedAt != null || widget.card.endTime != null; // Terkunci total jika sudah selesai

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Tugas ✏️', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: isCardFinished ? null : _submitForm, // Tombol simpan mati jika tugas sudah berakhir
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCardFinished 
                      ? [Colors.grey.shade400, Colors.grey.shade500] 
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              if (isMainInfoLocked)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔒', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tugas sudah dimulai. Info utama dikunci. Kamu masih bisa menambah subtask/link baru, tapi subtask yang sudah berjalan tidak bisa diedit/dihapus.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. INFO DASAR
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('📚', 'Info Tugas', subtitle: 'Detail dasar tugasmu'),
                    _buildTextField(
                      controller: _matkulController,
                      hint: 'Mata Kuliah',
                      icon: Icons.book_rounded,
                      enabled: !isMainInfoLocked, // ★ Hanya terkunci jika info utama jalan
                      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Nama Tugas',
                      icon: Icons.task_alt_rounded,
                      enabled: !isMainInfoLocked, // ★ Hanya terkunci jika info utama jalan
                      validator: (val) => val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descController,
                      hint: 'Deskripsi tambahan (opsional)...',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                      enabled: !isMainInfoLocked, // ★ Hanya terkunci jika info utama jalan
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. STRATEGI, PRIORITAS & KESULITAN
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('🧠', 'Strategi & Prioritas', subtitle: 'Sesuaikan dengan kebutuhanmu'),
                    _isLoadingStrategies
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _strategies.map((strategy) {
                              final String label = strategy['learningStrategy'];
                              final String keyCode = strategy['keyCode'];
                              final String learningId = strategy['learningId'];

                              bool isUnlocked = _unlockedFeatures.contains(keyCode);
                              bool isSelected = _selectedStrategyId == learningId;

                              String emoji = '🔹';
                              if (keyCode.contains('time')) emoji = '⏱️';
                              if (keyCode.contains('help')) emoji = '🤝';
                              if (keyCode.contains('organization')) emoji = '🏗️';
                              if (keyCode.contains('elaboration')) emoji = '🕸️';
                              if (keyCode.contains('rehearsal')) emoji = '🧠';

                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$emoji $label'),
                                    if (!isUnlocked) ...[const SizedBox(width: 4), const Icon(Icons.lock, size: 14, color: Colors.grey)],
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFEEF2FF),
                                backgroundColor: isUnlocked ? Colors.white : Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: !isUnlocked ? Colors.grey : (isSelected ? const Color(0xFF4F46E5) : Colors.black87),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300, width: isSelected ? 2 : 1),
                                ),
                                onSelected: (isMainInfoLocked || !isUnlocked)
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _selectedStrategyId = selected ? learningId : null;
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 20),
                    const Text('Prioritas *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPriorityButton('Rendah', 'low', Colors.green, isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildPriorityButton('Sedang', 'medium', Colors.orange, isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildPriorityButton('Tinggi', 'high', Colors.red, isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildPriorityButton('Kritis', 'critical', Colors.purple, isMainInfoLocked),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Tingkat Kesulitan *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDifficultyButton('Mudah', 'easy', isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Sedang', 'medium', isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Sulit', 'hard', isMainInfoLocked),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Expert', 'expert', isMainInfoLocked),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. DEADLINE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('📅', 'Deadline', subtitle: 'Kapan harus selesai?'),
                    Row(
                      children: [
                        Expanded(flex: 3, child: _buildTextField(controller: _dateController, hint: 'Pilih Tanggal', icon: Icons.calendar_today_rounded, readOnly: true, onTap: () => _selectDate(context))),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: _buildTextField(controller: _timeController, hint: '23:59', icon: Icons.access_time_rounded, readOnly: true, onTap: () => _selectTime(context))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. SUBTASKS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('🪜', 'Langkah Kecil', subtitle: 'Pecah tugas besar jadi kecil'),
                    ..._subTaskControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      
                      // ★ Cek apakah subtask spesifik ini sudah berjalan
                      bool isSubtaskLocked = index < _originalSubtasks.length && _originalSubtasks[index].startTimeList != null;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: entry.value,
                                hint: 'Subtaks ${index + 1}',
                                icon: isSubtaskLocked ? Icons.check_circle : Icons.radio_button_unchecked_rounded,
                                enabled: !isSubtaskLocked, // ★ Hanya terkunci jika subtask ini sudah jalan
                              ),
                            ),
                            // ★ Tombol hapus HILANG jika subtask sudah jalan
                            if (!isSubtaskLocked)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: () => setState(() => _subTaskControllers.removeAt(index)),
                              ),
                          ],
                        ),
                      );
                    }),
                    
                    // ★ Tombol "Tambah Langkah" TETAP MUNCUL selama tugas belum selesai total
                    if (!isCardFinished)
                      TextButton.icon(
                        onPressed: _addSubTaskField,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5)),
                        label: const Text('Tambah Langkah', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. URL / LINKS
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('🔗', 'Link Referensi', subtitle: 'Sumber belajar (opsional)'),
                    ..._urlControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: entry.value,
                                hint: 'https://...',
                                icon: Icons.link_rounded,
                                enabled: !isCardFinished, // ★ Hanya terkunci jika tugas selesai total
                              ),
                            ),
                            if (!isCardFinished)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: () => setState(() => _urlControllers.removeAt(index)),
                              ),
                          ],
                        ),
                      );
                    }),
                    
                    // ★ Tombol "Tambah Link" TETAP MUNCUL selama tugas belum selesai total
                    if (!isCardFinished)
                      TextButton.icon(
                        onPressed: _addURLField,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5)),
                        label: const Text('Tambah Link', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),

              // 6. KOLABORASI
              if (_isHelpSeekingStrategy) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFDE68A))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('🤝', 'Kolaborasi Teman', subtitle: 'Belajar bareng lebih seru!'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(child: Text('Ajak teman untuk mengerjakan tugas ini bersama-sama.', style: TextStyle(fontSize: 12, color: Colors.black87))),
                          TextButton.icon(
                            onPressed: _showAddCollaboratorDialog,
                            icon: const Icon(Icons.person_add_rounded, size: 18, color: Color(0xFF4F46E5)),
                            label: const Text('Tambah', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _isLoadingFriends
                          ? const Center(child: CircularProgressIndicator())
                          : _friendsList.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                  child: const Center(child: Text('Belum ada teman kolaborasi.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                                )
                              : Wrap(
                                  spacing: 8.0,
                                  children: _friendsList.map((friend) {
                                    final friendId = friend['userId'] ?? friend['id'];
                                    final friendName = friend['username'] ?? 'Teman';
                                    bool isSelected = _selectedCollaborators.contains(friendId);
                                    return FilterChip(
                                      label: Text(friendName),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedCollaborators.add(friendId);
                                          } else {
                                            _selectedCollaborators.remove(friendId);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCardFinished ? Colors.grey : const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: isCardFinished ? null : _submitForm,
                  child: Text(
                    isCardFinished ? 'Tugas Telah Selesai' : 'Simpan Perubahan 🚀',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityButton(String label, String value, Color color, bool isMainInfoLocked) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: GestureDetector(
        onTap: isMainInfoLocked ? null : () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPriority = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isMainInfoLocked ? const Color(0xFFF1F5F9) : (isSelected ? color.withOpacity(0.15) : Colors.white),
            border: Border.all(color: isMainInfoLocked ? Colors.transparent : (isSelected ? color : Colors.grey.shade300), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isMainInfoLocked ? Colors.grey : (isSelected ? color : Colors.grey.shade600)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(String label, String value, bool isMainInfoLocked) {
    bool isSelected = _selectedDifficulty == value;
    Color color = value == 'easy' ? Colors.green : value == 'medium' ? Colors.orange : value == 'hard' ? Colors.red : Colors.purple;
    return Expanded(
      child: GestureDetector(
        onTap: isMainInfoLocked ? null : () {
          HapticFeedback.selectionClick();
          setState(() => _selectedDifficulty = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isMainInfoLocked ? const Color(0xFFF1F5F9) : (isSelected ? color.withOpacity(0.15) : Colors.white),
            border: Border.all(color: isMainInfoLocked ? Colors.transparent : (isSelected ? color : Colors.grey.shade300), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isMainInfoLocked ? Colors.grey : (isSelected ? color : Colors.grey.shade600)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedStrategyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih strategi belajar terlebih dahulu!')));
        return;
      }

      if (_selectedDeadline != null) {
        _selectedDeadline = DateTime(_selectedDeadline!.year, _selectedDeadline!.month, _selectedDeadline!.day, _selectedTime?.hour ?? 23, _selectedTime?.minute ?? 59);
      }

      List<String> urlList = _urlControllers.map((c) => c.text.trim()).where((u) => u.isNotEmpty).toList();
      String combinedUrls = urlList.join(', ');

      List<Map<String, dynamic>> subtasksPayload = [];
      List<CardList> updatedSubtasksList = [];

      for (int i = 0; i < _subTaskControllers.length; i++) {
        String title = _subTaskControllers[i].text.trim();
        if (title.isEmpty) continue;

        if (i < _originalSubtasks.length) {
          final existingSub = _originalSubtasks[i];
          existingSub.subTitle = title; 
          
          subtasksPayload.add({
            'clId': existingSub.clId,
            'subTitle': title,
            'startTimeList': existingSub.startTimeList?.toIso8601String(),
            'endTimeList': existingSub.endTimeList?.toIso8601String(),
          });
          updatedSubtasksList.add(existingSub);
        } else {
          subtasksPayload.add({'subTitle': title, 'startTimeList': null, 'endTimeList': null});
          updatedSubtasksList.add(CardList(cardId: widget.card.cardId, subTitle: title));
        }
      }

      final String? finalStartTime = widget.card.startTime?.toIso8601String();

      final updatedDataJson = {
        'nmMatkul': _matkulController.text.trim(),
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'learningId': _selectedStrategyId,
        'priority': _selectedPriority,
        'difficulty': _selectedDifficulty,
        'deadline': _selectedDeadline?.toIso8601String(),
        'startTime': finalStartTime,
        'subtasks': subtasksPayload, 
        'URL': combinedUrls,
      };

      try {
        final token = await SecureTokenStorage.getToken();
        if (token != null && widget.card.cardId != null) {
          final cardService = CardService();
          bool cardSuccess = await cardService.updateCard(token, widget.card.cardId!, updatedDataJson);
          if (!cardSuccess) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan perubahan kartu utama!')));
            return;
          }
        }
      } catch (e) {
        debugPrint('Error submit update: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan saat menyimpan: $e')));
        return;
      }

      widget.card.subtasks = updatedSubtasksList;
      widget.card.courseName = _matkulController.text.trim();
      widget.card.title = _titleController.text.trim();
      widget.card.description = _descController.text.trim();
      widget.card.learningId = _selectedStrategyId;
      widget.card.priority = _selectedPriority;
      widget.card.difficulty = _selectedDifficulty;
      widget.card.deadline = _selectedDeadline;
      widget.card.url = combinedUrls;

      widget.onSaveUpdatedCard(widget.card);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }
}