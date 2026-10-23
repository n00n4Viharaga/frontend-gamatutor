import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AddCardView extends StatefulWidget {
  final String token;
  final Function onCardCreated;

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

  // Controller Form Utama (Cards)
  final TextEditingController _matkulController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();

  String? _selectedMatkul;
  String? _selectedStrategyId;
  String? _selectedPriority;
  String? _selectedDifficulty;
  DateTime? _selectedDeadline;
  // Variabel untuk menyimpan tanggal dan waktu deadline
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Subtasks(Masuk ke tabel card_list)
  final List<TextEditingController> _subTaskControllers = [];
  // URL (Masyk ke tabel Card)
  final List<TextEditingController> _urlController = [];

  // State untuk Help-Seeking & Collaboration (Masuk ke card_list_collab)
  bool _isHelpSeekingSelected = false;
  final List<Map<String, dynamic>> _availableFriends = [];
  final List<String> _selectedCollaboratorIds = [];

  // Controller untuk menampilkan teks pada input field
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  List<dynamic> _strategies =
      []; // Data semua strategi dari tabel learning_strats
  List<String> _unlockedFeatures =
      []; // Data dari kolom unlocked_features JSONB
  bool _isLoadingStrategies = true;

  @override
  void initState() {
    super.initState();
    // Tambah 1 subtask kosong default
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

      // Ekstrak userId langsung dari token JWT yang tersimpan
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final String userId =
          decodedToken['userId'] ??
          decodedToken['id']; // Sesuaikan key payload backend Anda

      // Eksekusi paralel menggunakan Future.wait agar cepat & tidak gantung
      final results = await Future.wait([
        CardService.getAllStrategies(),
        rekomendasiService.getUnlockedFeatures(
          userId,
          token,
        ), // Masukkan userId ke sini
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

  // Fungsi untuk memilih Tanggal
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
        // Format tanggal sesuai keinginan, contoh: 28 Feb 2025
        _dateController.text =
            "${picked.day} ${_getMonthName(picked.month)} ${picked.year}";
      });
    }
  }

  // Fungsi untuk memilih Waktu
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        // Format waktu menjadi HH:mm
        _timeController.text = picked.format(context);
      });
    }
  }

  // Helper untuk mengubah angka bulan menjadi nama singkat
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tugas Baru',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _submitForm,
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- MATA KULIAH ---
              const Text(
                'Mata Kuliah *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _matkulController,
                decoration: InputDecoration(
                  hintText: 'Ketik atau pilih mata kuliah...',
                  prefixIcon: const Icon(Icons.book_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Mata kuliah wajib diisi'
                    : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Algoritma', 'Basis Data', 'Kalkulus']
                    .map(
                      (matkul) => ActionChip(
                        label: Text(matkul),
                        onPressed: () {
                          setState(() {
                            _matkulController.text = matkul;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),

              // --- NAMA TUGAS ---
              const Text(
                'Nama Tugas *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Apa yang mau dikerjakan?',
                  prefixIcon: const Icon(Icons.task_alt),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Nama tugas wajib diisi'
                    : null,
              ),
              const SizedBox(height: 16),

              // --- DESKRIPSI ---
              const Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Deskripsi tambahan (opsional)...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- STRATEGI BELAJAR (Dari Rekomendasi user_Quiz) ---
              const Text(
                'Strategi Belajar *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _isLoadingStrategies
                  ? const Center(child: CircularProgressIndicator())
                  : Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _strategies.map((strategy) {
                        final String label = strategy['learningStrategy']; // misal: "Organization"
                        final String keyCode =
                            strategy['keyCode']; // misal: "organization"
                        final String learningId =
                            strategy['learningId']; // UUID

                        // 2. Cek apakah strategi ini ada di unlocked_features user
                        bool isUnlocked = _unlockedFeatures.contains(keyCode);
                        bool isSelected = _selectedStrategyId == learningId;

                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(label),
                              // 3. Jika terkunci, kasih ikon gembok kecil
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
                              : Colors.grey[200], // Agak abu-abu jika terkunci
                          labelStyle: TextStyle(
                            color: !isUnlocked
                                ? Colors
                                      .grey // Teks abu-abu jika terkunci
                                : (isSelected
                                      ? const Color(0xFF4F46E5)
                                      : Colors.black),
                            fontWeight: FontWeight.bold,
                          ),
                          // 4. KUNCI UTAMA: Jika tidak unlocked, set NULL agar TIDAK BISA DIPILIH
                          onSelected: !isUnlocked
                              ? null
                              : (selected) {
                                  setState(() {
                                    _selectedStrategyId = selected
                                        ? learningId
                                        : null;
                                  });
                                },
                        );
                      }).toList(),
                    ),
              const SizedBox(height: 16),
              // --- PRIORITAS ---
              const Text(
                'Prioritas *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityButton('Rendah', 'low'),
                  const SizedBox(width: 8),
                  _buildPriorityButton('Sedang', 'medium'),
                  const SizedBox(width: 8),
                  _buildPriorityButton('Tinggi', 'high'),
                  const SizedBox(width: 8),
                  _buildPriorityButton('Kritis', 'critical'),
                ],
              ),
              const SizedBox(height: 24),
              // --- TINGKAT KESULITAN (DIFFICULTY) ---
              const Text(
                'Tingkat Kesulitan *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 24),
              // --- SUBTASKS (Masuk ke tabel card_list) ---
              const Text(
                'SUBTASKS',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ..._subTaskControllers.asMap().entries.map((entry) {
                int index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            hintText: 'Subtaks ${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _subTaskControllers.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addSubTaskField,
                icon: const Icon(Icons.add, color: Color(0xFF4F46E5)),
                label: const Text(
                  'Tambah Subtaks',
                  style: TextStyle(color: Color(0xFF4F46E5)),
                ),
              ),
              const SizedBox(height: 16),

              // --- URL ---
              const Text(
                'URL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ..._urlController.asMap().entries.map((entry) {
                int index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            hintText: 'URL ${index + 1}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _urlController.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addURLField,
                icon: const Icon(Icons.add, color: Color(0xFF4F46E5)),
                label: const Text(
                  'Tambah URL',
                  style: TextStyle(color: Color(0xFF4F46E5)),
                ),
              ),
              const SizedBox(height: 16),
              // --- DEADLINE ---
              Row(
                children: const [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: Color(0xFF0D9488),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Deadline',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Kotak Pilih Tanggal
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: InputDecoration(
                        hintText: 'Pilih Tanggal',
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Kotak Pilih Waktu
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _timeController,
                      readOnly: true,
                      onTap: () => _selectTime(context),
                      decoration: InputDecoration(
                        hintText: '23:59',
                        suffixIcon: const Icon(
                          Icons.access_time,
                          size: 20,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // --- BAGIAN KONDISIONAL: TAMBAHKAN TEMAN (Hanya muncul jika Help-Seeking dipilih) ---
              if (_isHelpSeekingSelected) ...[
                const Divider(thickness: 1.5),
                const SizedBox(height: 8),
                const Text(
                  'TAMBAHKAN TEMAN (Help-Seeking)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih teman dengan strategi Elaboration untuk berkolaborasi.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),

                TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari teman...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // List Teman Berelasi Elaboration
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _availableFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _availableFriends[index];
                    final isSelected = _selectedCollaboratorIds.contains(
                      friend['userId'],
                    );

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
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
                          'Status: ${friend['status']} • Strategi: ${friend['strategy']}',
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
                                _selectedCollaboratorIds.add(friend['userId']);
                              }
                            });
                          },
                          child: Text(
                            isSelected ? 'Batal' : 'Tambah',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyChip(Map<String, dynamic> strategy) {
    final String label = strategy['learningStrategy']; // Contoh: "Organization"
    final String keyCode = strategy['keyCode']; // Contoh: "organization"
    final String learningId = strategy['learningId']; // UUID dari database

    // Cek apakah strategi ini terbuka (unlocked) berdasarkan JSONB user_quiz_results
    bool isUnlocked = _unlockedFeatures.contains(keyCode);
    bool isSelected = _selectedStrategyId == learningId;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (!isUnlocked) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.lock,
              size: 14,
              color: Colors.grey,
            ), // Indikator terkunci
          ],
        ],
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFEEF2FF),
      backgroundColor: isUnlocked
          ? Colors.white
          : Colors.grey[200], // Warna abu jika terkunci
      labelStyle: TextStyle(
        color: !isUnlocked
            ? Colors
                  .grey // Teks abu jika terkunci
            : (isSelected ? const Color(0xFF4F46E5) : Colors.black),
        fontWeight: FontWeight.bold,
      ),
      // PENTING: Jika tidak unlocked, set onSelected ke NULL agar disable
      onSelected: !isUnlocked
          ? null
          : (selected) {
              setState(() {
                _selectedStrategyId = selected ? learningId : null;

                // Cek apakah strategi yang dipilih adalah Help-Seeking
                _isHelpSeekingSelected = (keyCode == 'help_seeking');
                if (!_isHelpSeekingSelected) {
                  _selectedCollaboratorIds.clear();
                }
              });
            },
    );
  }

  Widget _buildPriorityButton(String label, String value) {
    bool isSelected = _selectedPriority == value;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          side: BorderSide(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => setState(() => _selectedPriority = value),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF4F46E5) : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String value,
  ) {
    bool isSelected = _selectedDifficulty == value;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? const Color(0xFFFEF3C7) // Warna kuning lembut untuk kesulitan
              : (isSelected ? const Color(0xFFF8FAFC) : Colors.white),
          side: BorderSide(
            color: isSelected ? const Color(0xFFD97706) : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: isSelected
            ? null
            : () => setState(() => _selectedDifficulty = value),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFD97706)
                : (isSelected ? Colors.grey : Colors.black),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

      if (_selectedDate != null && _selectedDeadline!.isAfter(DateTime.now())) {
        _selectedDeadline = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime?.hour ??
              23, // Default jam 23:59 jika waktu tidak dipilih
          _selectedTime?.minute ?? 59,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tanggal harus setelah hari ini!')),
        );
        return;
      }

      List<String> urlList = _urlController
          .map((controller) => controller.text.trim())
          .where((url) => url.isNotEmpty)
          .toList();

      String combinedUrls = urlList.join(', ');

      List<String> subtaksList = _subTaskControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final payload = {
        'nmMatkul': _matkulController.text,
        'title': _titleController.text,
        'description': _descController.text,
        'learningId': fetchedLearningId,
        'priority': _selectedPriority,
        'difficulty': _selectedDifficulty,
        'deadline': _selectedDeadline?.toIso8601String(),
        'startTime': DateTime.now().toIso8601String(),
        'subtasks':
            subtaksList, // Dikirim sebagai List string, bukan string koma
        'URL': combinedUrls,
        'collaborators': _selectedCollaboratorIds,
      };

      // Kirim ke backend service Anda
      widget.onCardCreated(payload);
      Navigator.pop(context);
    }
  }
}
