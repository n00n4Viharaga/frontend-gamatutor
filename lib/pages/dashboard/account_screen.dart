import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/user.dart';
import 'package:gamatutor_kanban/model/Rekomendasi.dart';
import 'package:gamatutor_kanban/pages/dashboard/wardrobescreen.dart';
import 'package:gamatutor_kanban/pages/dashboard/widgets/user_avatar_profile.dart';
import 'package:gamatutor_kanban/service/loginService.dart';
import 'package:avatar_builder/avatar_builder.dart';
import 'package:provider/provider.dart';
import 'package:gamatutor_kanban/utils/theme_provider.dart';

class AccountScreen extends StatelessWidget {
  final User? currentUser;
  final Rekomendasi? quizProfile;
  final int userXp;
  final Avataaar? currentAvatar;
  final Future<void> Function()? onAvatarUpdated;

  const AccountScreen({
    Key? key,
    this.currentUser,
    this.quizProfile,
    this.userXp = 0,
    this.currentAvatar,
    this.onAvatarUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name =
        "${currentUser?.firstName ?? 'Super'} ${currentUser?.lastName ?? 'Admin'}";
    final username = currentUser?.username ?? '@superadmin';
    final profileBadge = quizProfile?.userProfile ?? 'The Explorer';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Akun',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            Text(
              'Kelola pengaturan akunmu',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),

            // ─── PROFIL CARD (Bento Style) ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).cardColor),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).cardColor,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar (Bisa diganti pake LayeredAvatar jika ada)
                  currentAvatar != null
                      ? UserAvatarProfile(
                          avatar: currentAvatar!,
                          size: 70,
                          isCircle: true,
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6366F1),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          username,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Badge Profile MSLQ
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '✨ $profileBadge',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9333EA),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── MENU: KUSTOMISASI KARAKTER ───
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AvatarCustomizerScreen(userXp: userXp),
                  ),
                );
                if (onAvatarUpdated != null) {
                  await onAvatarUpdated!();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Text('🎨', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sesuaikan Karakter',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── PENGATURAN APLIKASI ───
            Text(
              'PENGATURAN APLIKASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).cardColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.purple,
                    title: 'Mode Gelap',
                    trailing: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (val) {
                            themeProvider.toggleTheme(val);
                          },
                          activeColor: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildMenuItem(
                    context,
                    icon: Icons.notifications_active_rounded,
                    iconColor: Colors.blue,
                    title: 'Notifikasi Belajar',
                    trailing: Switch(
                      value: true,
                      onChanged: (v) {},
                      activeColor: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── TENTANG AKU ───
            Text(
              'TENTANG AKU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color:Theme.of(context).textTheme.bodyLarge?.color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color:Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color:Theme.of(context).cardColor),
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.person_outline_rounded,
                    iconColor: Colors.indigo,
                    title: 'Edit Profil',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── LOGOUT BUTTON ───
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await LoginService().logout();
                  if (context.mounted) {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  }
                },
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color.fromARGB(255, 255, 253, 253),
                  size: 18,
                ),
                label: Text(
                  'Keluar',
                  style: TextStyle(
                    color:Color.fromARGB(255, 255, 253, 253),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color:Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          // Ikon warnanya tetap (misal ungu, biru) agar tetap berwarna-warni
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            // ★ Ini sudah benar dari kamu
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        trailing:
            trailing ??
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              // ★ Ganti panah kanan agar menyesuaikan tema (putih saat gelap)
              color:
                  Theme.of(context).iconTheme.color?.withOpacity(0.5) ??
                  Colors.grey,
            ),
        onTap: () {},
      ),
    );
  }
}
