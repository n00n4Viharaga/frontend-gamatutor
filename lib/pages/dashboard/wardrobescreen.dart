import 'package:avatar_builder/avatar_builder.dart';
import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/avatar_models.dart';
import 'package:gamatutor_kanban/service/avatarService.dart' as AvatarService;

class AvatarCustomizerScreen extends StatefulWidget {
  final int userXp;
  const AvatarCustomizerScreen({Key? key, required this.userXp})
    : super(key: key);

  @override
  State<AvatarCustomizerScreen> createState() => _AvatarCustomizerScreenState();
}

class _AvatarCustomizerScreenState extends State<AvatarCustomizerScreen> {
  AvatarConfig _config = AvatarConfig();
  bool _isSaving = false;

  // ★ DAFTAR RAMBUT & BAJU KHUSUS CEWEK/COWOK
  // ★ DAFTAR LENGKAP RAMBUT CEWEK (Termasuk Hijab & Rambut Besar)
  final List<String> _femaleHair = [
    'hijab', // ★ Tambahan: Hijab
    'longHairBigHair', // ★ Tambahan: Rambut Besar
    'longHairBob',
    'longHairBun',
    'longHairCurly',
    'longHairCurvy',
    'longHairDreads',
    'longHairFrida',
    'longHairFro',
    'longHairFroBand',
    'longHairMiaWallace',
    'longHairNotTooLong',
    'longHairShavedSides',
    'longHairStraight',
    'longHairStraight2',
    'longHairStraightStrand',
  ];

  final List<String> _femaleClothes = [
    'blazerAndShirt',
    'blazerAndSweater',
    'collarAndSweater',
    'overall',
    'shirtCrewNeck',
  ];

  // ★ DAFTAR HARGA XP (Silakan sesuaikan)
  // Jika tidak ada di list ini, berarti gratis (0 XP)
  final Map<String, int> _xpCosts = {
    'longHairBigHair': 100,
    'longHairBun': 150,
    'hat': 50,
    'turban': 75,
    'blazerAndShirt': 100,
    'overall': 120,
    'beardMedium': 50, // Jenggot butuh XP
    'beardLight': 30,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingAvatar();
  }

  Future<void> _loadExistingAvatar() async {
    try {
      final saved = await AvatarService.getUserAvatarConfig();
      if (saved != null) {
        setState(() => _config = AvatarConfig.fromJson(saved));
      }
    } catch (e) {
      debugPrint('Gagal load avatar: $e');
    }
  }

  Future<void> _saveAvatar() async {
    setState(() => _isSaving = true);
    try {
      await AvatarService.saveUserAvatarConfig(_config.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karakter berhasil disimpan! ✨'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _randomize() {
    setState(() {
      // Acak berdasarkan gender yang dipilih
      Avataaar randomAvatar;
      do {
        randomAvatar = Avataaar.random();
      } while (_isWrongGender(randomAvatar)); // Pastikan acakan sesuai gender

      _config = AvatarConfig.fromAvataaar(randomAvatar, gender: _config.gender);
    });
  }

  bool _isWrongGender(Avataaar av) {
    final hairName = av.topType.toString().split('.').last;
    final clothesName = av.clotheType.toString().split('.').last;
    if (_config.gender == 'female') {
      return !_femaleHair.contains(hairName) ||
          !_femaleClothes.contains(clothesName);
    } else {
      return _femaleHair.contains(hairName) ||
          _femaleClothes.contains(clothesName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _config.toAvataaar();
    final isFemale = _config.gender == 'female';

    // Dynamic Tabs (Jenggot hilang kalau cewek)
    final tabs = [
      const Tab(text: 'Rambut'),
      const Tab(text: 'Wajah'),
      if (!isFemale) const Tab(text: 'Jenggot'),
      const Tab(text: 'Baju'),
      const Tab(text: 'Aksesoris'),
      const Tab(text: 'Warna'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Kustomisasi Karakter',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.casino_rounded, color: Colors.orange),
              onPressed: _randomize,
            ),
            TextButton(
              onPressed: _isSaving ? null : _saveAvatar,
              child: const Text(
                'Simpan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFF6366F1),
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey,
            tabs: tabs,
          ),
        ),
        body: Column(
          children: [
            // ★ TOGGLE GENDER (Pria / Wanita)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildGenderButton('male', '👦 Pria', Icons.male),
                  const SizedBox(width: 16),
                  _buildGenderButton('female', '👧 Wanita', Icons.female),
                ],
              ),
            ),
            const Divider(height: 1),

            // Preview Avatar Utama
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.white,
              child: Center(child: AvatarWidget(avatar: avatar, size: 150)),
            ),
            const Divider(height: 1),

            // Isi Tab
            Expanded(
              child: TabBarView(
                children: [
                  _buildGridTab(TopType.values, _config.topType, (val) {
                    setState(() => _config = _config.copyWith(topType: val));
                  }, 'topType'),

                  _buildFaceTab(),

                  if (!isFemale)
                    _buildGridTab(
                      FacialHairType.values,
                      _config.facialHairType,
                      (val) {
                        setState(
                          () => _config = _config.copyWith(facialHairType: val),
                        );
                      },
                      'facialHairType',
                    ),

                  _buildGridTab(ClotheType.values, _config.clotheType, (val) {
                    setState(() => _config = _config.copyWith(clotheType: val));
                  }, 'clotheType'),

                  _buildGridTab(
                    AccessoriesType.values,
                    _config.accessoriesType,
                    (val) {
                      setState(
                        () => _config = _config.copyWith(accessoriesType: val),
                      );
                    },
                    'accessoriesType',
                  ),

                  _buildColorTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderButton(String gender, String label, IconData icon) {
    final isSelected = _config.gender == gender;
    return GestureDetector(
      onTap: () {
        setState(() {
          // Saat ganti gender, reset rambut/baju agar tidak aneh
          final newHair = gender == 'female'
              ? TopType.longHairStraight
              : TopType.shortHairShortFlat;
          final newClothe = gender == 'female'
              ? ClotheType.collarSweater
              : ClotheType.hoodie;
          _config = _config.copyWith(
            gender: gender,
            topType: newHair.toString().split('.').last,
            clotheType: newClothe.toString().split('.').last,
            facialHairType: 'blank',
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bentuk Mata',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildWrappedGrid(
            EyeType.values,
            _config.eyeType,
            (val) => setState(() => _config = _config.copyWith(eyeType: val)),
            'eyeType',
          ),
          const SizedBox(height: 24),
          const Text(
            'Bentuk Alis',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildWrappedGrid(
            EyebrowType.values,
            _config.eyebrowType,
            (val) =>
                setState(() => _config = _config.copyWith(eyebrowType: val)),
            'eyebrowType',
          ),
          const SizedBox(height: 24),
          const Text(
            'Bentuk Mulut',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildWrappedGrid(
            MouthType.values,
            _config.mouthType,
            (val) => setState(() => _config = _config.copyWith(mouthType: val)),
            'mouthType',
          ),
        ],
      ),
    );
  }

  Widget _buildGridTab(
    List<dynamic> values,
    String selected,
    Function(String) onSelected,
    String category,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildWrappedGrid(values, selected, onSelected, category),
    );
  }

  Widget _buildWrappedGrid(
    List<dynamic> values,
    String selected,
    Function(String) onSelected,
    String category,
  ) {
    final currentAv = _config.toAvataaar();
    final isFemale = _config.gender == 'female';

    // ★ FILTERING GENDER
    final filteredValues = values.where((e) {
      final name = e.toString().split('.').last;

      if (category == 'topType') {
        if (isFemale && !_femaleHair.contains(name)) return false;
        if (!isFemale && _femaleHair.contains(name)) return false;
      }

      if (category == 'clotheType') {
        // Cewek punya baju khusus, Cowok punya baju khusus
        if (isFemale && !_femaleClothes.contains(name)) return false;
        if (!isFemale &&
            _femaleClothes.contains(name) &&
            name != 'shirtCrewNeck')
          return false;
      }

      if (category == 'facialHairType' && isFemale) {
        return name == 'blank'; // Cewek gak boleh jenggot
      }

      return true;
    }).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: filteredValues.map((e) {
        final name = e.toString().split('.').last;
        final isSelected = name == selected;

        // ★ CEK KUNCI XP
        final int requiredXp = _xpCosts[name] ?? 0;
        final bool isLocked = widget.userXp < requiredXp;

        final miniAvatar = Avataaar(
          topType: category == 'topType' ? e : currentAv.topType,
          accessoriesType: category == 'accessoriesType'
              ? e
              : currentAv.accessoriesType,
          hairColor: currentAv.hairColor,
          facialHairType: category == 'facialHairType'
              ? e
              : currentAv.facialHairType,
          clotheType: category == 'clotheType' ? e : currentAv.clotheType,
          clotheColor: currentAv.clotheColor,
          eyeType: category == 'eyeType' ? e : currentAv.eyeType,
          eyebrowType: category == 'eyebrowType' ? e : currentAv.eyebrowType,
          mouthType: category == 'mouthType' ? e : currentAv.mouthType,
          skinColor: currentAv.skinColor,
        );

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Butuh $requiredXp XP untuk membuka ini! 🔒'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              onSelected(name);
            }
          },
          child: Container(
            width: 80,
            height: 100, // Sedikit lebih tinggi untuk menampung ikon gembok
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Avatar (Jika dikunci, warnanya jadi abu-abu)
                ColorFiltered(
                  colorFilter: isLocked
                      ? const ColorFilter.matrix([
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0.2126,
                          0.7152,
                          0.0722,
                          0,
                          0,
                          0,
                          0,
                          0,
                          1,
                          0,
                        ]) // Grayscale
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.multiply,
                        ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [AvatarWidget(avatar: miniAvatar, size: 60)],
                  ),
                ),

                // Ikon Gembok & Harga XP
                if (isLocked)
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$requiredXp',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Ikon Centang jika dipilih
                if (isSelected && !isLocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6366F1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Warna Kulit',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildColorPicker(
          SkinColor.values.map((e) => e.color).toList(),
          _config.skinColor,
          (hex) => setState(() => _config = _config.copyWith(skinColor: hex)),
        ),
        const SizedBox(height: 24),
        const Text(
          'Warna Rambut',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildColorPicker(
          HairColor.values.map((e) => e.color).toList(),
          _config.hairColor,
          (hex) => setState(() => _config = _config.copyWith(hairColor: hex)),
        ),
        const SizedBox(height: 24),
        const Text('Warna Baju', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildColorPicker(
          ClotheColor.values.map((e) => e.color).toList(),
          _config.clotheColor,
          (hex) => setState(() => _config = _config.copyWith(clotheColor: hex)),
        ),
      ],
    );
  }

  Widget _buildColorPicker(
    List<int> colors,
    String selectedHex,
    Function(String) onSelected,
  ) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((colorValue) {
        final hex =
            '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2)}';
        final isSelected = hex == selectedHex;

        return GestureDetector(
          onTap: () => onSelected(hex),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(colorValue),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
