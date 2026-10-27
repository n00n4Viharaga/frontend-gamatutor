import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AddCardView extends StatefulWidget {
  final String token;
  final Future<void> Function(Map<String, dynamic>) onCardCreated;

  const AddCardView({
    super.key,
    required this.token,
    required this.onCardCreated,
  });

  @override
  State<AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<AddCardView> {
  final _formKey = GlobalKey<FormState>();

  // Controller Form Utama
  final TextEditingController _matkulController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  String? _selectedStrategyId;
  String? _selectedPriority = 'medium'; // Default
  String? _selectedDifficulty = 'medium'; // Default
  DateTime? _selectedDeadline;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Subtasks & URL
  final List<TextEditingController> _subTaskControllers = [];
  final List<TextEditingController> _urlController = [];

  // State untuk Help-Seeking
  bool _isHelpSeekingSelected = false;
  final List<Map<String, dynamic>> _availableFriends = [];
  final List<String> _selectedCollaboratorIds = [];

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  List<dynamic> _strategies = [];
  List<String> _unlockedFeatures = [];
  bool _isLoadingStrategies = true;

  @override
  void initState() {
    super.initState();
    _addSubTaskField();
    _addURLField();
    _loadStrategyData();
  }

  void _addSubTaskField() {
    setState(() {
      _subTaskControllers.add(TextEditingController());
    });
  }

  void _addURLField() {
    setState(() {
      _urlController.add(TextEditingController());
    });
  }

  Future<void> _loadStrategyData() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) {
        setState(() => _isLoadingStrategies = false);
        return;
      }

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final String userId = decodedToken['userId'] ?? decodedToken['id'];

      final results = await Future.wait([
        CardService.getAllStrategies(),
        rekomendasiService.getUnlockedFeatures(userId, token),
      ]);

      setState(() {
        _strategies = results[0];
        _unlockedFeatures = (results[1]).map((e) => e.toString()).toList();
        _isLoadingStrategies = false;
      });

      if (_unlockedFeatures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda belum menyelesaikan kuis strategi belajar!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading strategy data: $e');
      setState(() {
        _strategies = [];
        _unlockedFeatures = [];
        _isLoadingStrategies = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate != null && _selectedDate!.isAfter(tomorrow)
          ? _selectedDate!
          : tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            "${picked.day} ${_getMonthName(picked.month)} ${picked.year}";
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return months[month - 1];
  }

  // ─── HELPER UNTUK SECTION HEADER (Gaya Gen-Z) ───
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPER UNTUK TEXTFIELD (Lebih Soft & Modern) ───
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Background abu terang
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tugas Baru ✨',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      '📚',
                      'Info Tugas',
                      subtitle: 'Apa yang mau kamu pelajari?',
                    ),
                    _buildTextField(
                      controller: _matkulController,
                      hint: 'Mata Kuliah (misal: Algoritma)',
                      icon: Icons.book_rounded,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Algoritma', 'Basis Data', 'Kalkulus'].map((
                        matkul,
                      ) {
                        return ActionChip(
                          label: Text(
                            matkul,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onPressed: () =>
                              setState(() => _matkulController.text = matkul),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _titleController,
                      hint: 'Nama Tugas (misal: Tugas 1 Sorting)',
                      icon: Icons.task_alt_rounded,
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descController,
                      hint: 'Deskripsi tambahan (opsional)...',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════════
              // 2. STRATEGI BELAJAR
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      '🧠',
                      'Strategi Belajar',
                      subtitle: 'Pilih senjata rahasiamu!',
                    ),
                    _isLoadingStrategies
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: _strategies.map((strategy) {
                              final String label = strategy['learningStrategy'];
                              final String keyCode = strategy['keyCode'];
                              final String learningId = strategy['learningId'];

                              bool isUnlocked = _unlockedFeatures.contains(
                                keyCode,
                              );
                              bool isSelected =
                                  _selectedStrategyId == learningId;

                              // Emoji berdasarkan strategi
                              String emoji = '🔹';
                              if (keyCode.contains('time')) emoji = '⏱️';
                              if (keyCode.contains('help')) emoji = '🤝';
                              if (keyCode.contains('organization'))
                                emoji = '🏗️';
                              if (keyCode.contains('elaboration'))
                                emoji = '🕸️';
                              if (keyCode.contains('rehearsal')) emoji = '🧠';

                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$emoji $label'),
                                    if (!isUnlocked) ...[
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.lock,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFEEF2FF),
                                backgroundColor: isUnlocked
                                    ? Colors.white
                                    : Colors.grey[100],
                                labelStyle: TextStyle(
                                  color: !isUnlocked
                                      ? Colors.grey
                                      : (isSelected
                                            ? const Color(0xFF4F46E5)
                                            : Colors.black87),
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                onSelected: !isUnlocked
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _selectedStrategyId = selected
                                              ? learningId
                                              : null;
                                          _isHelpSeekingSelected =
                                              (keyCode == 'help_seeking');
                                          if (!_isHelpSeekingSelected)
                                            _selectedCollaboratorIds.clear();
                                        });
                                      },
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════════
              // 3. PRIORITAS & KESULITAN (Gaya Tombol Warna)
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      '🚦',
                      'Prioritas',
                      subtitle: 'Seberapa penting tugas ini?',
                    ),
                    Row(
                      children: [
                        _buildPriorityButton('Rendah', 'low', Colors.green),
                        const SizedBox(width: 8),
                        _buildPriorityButton('Sedang', 'medium', Colors.orange),
                        const SizedBox(width: 8),
                        _buildPriorityButton('Tinggi', 'high', Colors.red),
                        const SizedBox(width: 8),
                        _buildPriorityButton(
                          'Kritis',
                          'critical',
                          Colors.purple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader(
                      '🔥',
                      'Tingkat Kesulitan',
                      subtitle: 'Seberapa menantang?',
                    ),
                    Row(
                      children: [
                        _buildDifficultyButton('Mudah', 'easy'),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Sedang', 'medium'),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Sulit', 'hard'),
                        const SizedBox(width: 8),
                        _buildDifficultyButton('Expert', 'expert'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════════
              // 4. DEADLINE
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      '📅',
                      'Deadline',
                      subtitle: 'Kapan harus selesai?',
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _dateController,
                            hint: 'Pilih Tanggal',
                            icon: Icons.calendar_today_rounded,
                            readOnly: true,
                            onTap: () => _selectDate(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _timeController,
                            hint: '23:59',
                            icon: Icons.access_time_rounded,
                            readOnly: true,
                            onTap: () => _selectTime(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ═══════════════════════════════════════════
              // 5. SUBTASKS & URL
              // ═══════════════════════════════════════════
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      '🪜',
                      'Langkah Kecil',
                      subtitle: 'Pecah tugas besar jadi kecil',
                    ),
                    ..._subTaskControllers.asMap().entries.map((entry) {
                      int index = entry.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: entry.value,
                                hint: 'Subtaks ${index + 1}',
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => setState(
                                () => _subTaskControllers.removeAt(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addSubTaskField,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFF4F46E5),
                      ),
                      label: const Text(
                        'Tambah Langkah',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    _buildSectionHeader(
                      '🔗',
                      'Link Referensi',
                      subtitle: 'Sumber belajar (opsional)',
                    ),
                    ..._urlController.asMap().entries.map((entry) {
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
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () => setState(
                                () => _urlController.removeAt(index),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addURLField,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFF4F46E5),
                      ),
                      label: const Text(
                        'Tambah Link',
                        style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ═══════════════════════════════════════════
              // 6. KOLABORASI (HELP-SEEKING)
              // ═══════════════════════════════════════════
              if (_isHelpSeekingSelected) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), // Kuning soft
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        '🤝',
                        'Ajak Teman Kolaborasi',
                        subtitle: 'Belajar bareng lebih seru!',
                      ),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari username teman...',
                          hintStyle: const TextStyle(fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_availableFriends.isEmpty)
                        const Center(
                          child: Text(
                            'Belum ada teman yang terhubung.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _availableFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _availableFriends[index];
                            final isSelected = _selectedCollaboratorIds
                                .contains(friend['userId']);
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFE0E7FF),
                                  child: Text(friend['name'][0]),
                                ),
                                title: Text(
                                  friend['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  'Strategi: ${friend['strategy']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? Colors.red.shade50
                                        : const Color(0xFF4F46E5),
                                    foregroundColor: isSelected
                                        ? Colors.red
                                        : Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedCollaboratorIds.remove(
                                          friend['userId'],
                                        );
                                      } else {
                                        _selectedCollaboratorIds.add(
                                          friend['userId'],
                                        );
                                      }
                                    });
                                  },
                                  child: Text(
                                    isSelected ? 'Batal' : 'Pilih',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ═══════════════════════════════════════════
              // TOMBOL SIMPAN BESAR DI BAWAH
              // ═══════════════════════════════════════════
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _submitForm,
                  child: const Text(
                    'Buat Tugas Sekarang 🚀',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HELPER TOMBOL PRIORITAS (Warna-warni) ───
  Widget _buildPriorityButton(String label, String value, Color color) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPriority = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HELPER TOMBOL KESULITAN (Warna-warni) ───
  Widget _buildDifficultyButton(String label, String value) {
    bool isSelected = _selectedDifficulty == value;
    Color color = value == 'easy'
        ? Colors.green
        : value == 'medium'
        ? Colors.orange
        : value == 'hard'
        ? Colors.red
        : Colors.purple;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedDifficulty = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedStrategyId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih strategi belajar terlebih dahulu!'),
          ),
        );
        return;
      }

      final String? fetchedLearningId = await CardService.fetchLearningIdByName(
        _selectedStrategyId!,
      );
      if (fetchedLearningId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengambil ID strategi dari server!'),
          ),
        );
        return;
      }

      // ★ PERBAIKAN 1: Logika penentuan Deadline yang pasti terisi
      DateTime finalDeadline;
      if (_selectedDate != null) {
        // Jika user memilih tanggal, gabungkan dengan jam
        finalDeadline = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime?.hour ?? 23,
          _selectedTime?.minute ?? 59,
        );
      } else {
        // Jika user lupa/tidak memilih, set default besok jam 23:59
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        finalDeadline = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          23,
          59,
        );
      }

      List<String> urlList = _urlController
          .map((c) => c.text.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      String combinedUrls = urlList.join(', ');

      List<String> subtaksList = _subTaskControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // ★ PERBAIKAN 2: Nama key disesuaikan dengan Sequelize (camelCase)
      final payload = {
        'courseName': _matkulController.text
            .trim(), // Sequelize biasanya pakai camelCase
        'title': _titleController.text,
        'description': _descController.text,
        'learningId':
            fetchedLearningId, // ★ Gunakan learningId (bukan learningStrat)
        'priority': _selectedPriority,
        'difficulty': _selectedDifficulty,
        'deadline': finalDeadline.toIso8601String(), // ★ Pasti terisi
        'startTime': null,
        'subtasks': subtaksList,
        'url': combinedUrls,
        'collaborators': _selectedCollaboratorIds,
      };

      print("PAYLOAD FINAL KARTU: $payload");

      try {
        // ✅ TUNGGU save selesai dulu
        await widget.onCardCreated(payload);

        if (!mounted) return;
        Navigator.pop(context, true); // ✅ POP HANYA DI SINI
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
