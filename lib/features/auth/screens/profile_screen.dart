import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/widgets/glass_card.dart';
import '../services/auth_storage_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final u = await AuthStorageService.instance.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = u;
      });
    }
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 26,
          opacity: 0.98,
          tint: Colors.white,
          borderColor: AppColors.leafGreen.withValues(alpha: 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.leafGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Change Password',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: true,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      decoration: _buildInputDecoration('Current Password', Icons.lock_outline_rounded),
                      validator: (v) => v == null || v.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: true,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      decoration: _buildInputDecoration('New Password', Icons.lock_open_rounded),
                      validator: (v) => (v == null || v.length < 6) ? 'Password must be 6+ chars' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      decoration: _buildInputDecoration('Confirm Password', Icons.check_circle_outline_rounded),
                      validator: (v) {
                        if (v != newPassCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.leafGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('farmsense_user_password', newPassCtrl.text);
                        if (!mounted || !ctx.mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: AppColors.leafGreen,
                            content: Text(
                              'Password updated successfully!',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                            ),
                          ),
                        );
                      }
                    },
                    child: Text('Update Password', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, size: 18, color: AppColors.leafGreen),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.leafGreen.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.leafGreen.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.leafGreen, width: 1.5),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          borderRadius: 26,
          opacity: 0.98,
          tint: Colors.white,
          borderColor: AppColors.leafGreen.withValues(alpha: 0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.leafGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to sign out of Megha AI?',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF334155),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.leafGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await AuthStorageService.instance.logout();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _user?.fullName.isNotEmpty == true ? _user!.fullName : 'Sujay V';
    final email = _user?.email.isNotEmpty == true ? _user!.email : 'sujay@megha.ai';
    final phone = _user?.phone.isNotEmpty == true ? _user!.phone : '+91 98765 43210';
    final location = _user?.farmLocation.isNotEmpty == true ? _user!.farmLocation : 'Bengaluru, Karnataka (12.93940° N, 77.69470° E)';

    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.bgTop, AppColors.bgMid, AppColors.bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildAppBar(context)),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),

                // User Avatar Header Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      borderRadius: 24,
                      borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.leafGreen.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.leafGreen,
                              size: 44,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Smart Agronomist • Active',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.leafGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 350.ms),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Starting Profile Information Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18),
                      borderRadius: 22,
                      borderColor: AppColors.leafGreen.withValues(alpha: 0.35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROFILE DETAILS',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildProfileRow(Icons.person_outline_rounded, 'Full Name', fullName),
                          const SizedBox(height: 12),
                          _buildProfileRow(Icons.email_outlined, 'Email Address', email),
                          const SizedBox(height: 12),
                          _buildProfileRow(Icons.phone_outlined, 'Phone Number', phone),
                          const SizedBox(height: 12),
                          _buildProfileRow(Icons.location_on_outlined, 'Farm Location', location),
                          const SizedBox(height: 12),
                          _buildProfileRow(Icons.calendar_today_rounded, 'Account Status', 'Active • Verified'),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 350.ms),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // Account Actions (Change Password & Sign Out)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        // Change Password Button
                        GestureDetector(
                          onTap: _showChangePasswordDialog,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            borderRadius: 18,
                            borderColor: AppColors.leafGreen.withValues(alpha: 0.3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: AppColors.leafGreen.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: AppColors.leafGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Change Password',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Update your login credentials',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 350.ms),

                        const SizedBox(height: 12),

                        // Logout Button
                        GestureDetector(
                          onTap: _showLogoutConfirmation,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            borderRadius: 18,
                            borderColor: Colors.red.withValues(alpha: 0.3),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sign Out',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: Colors.red,
                                        ),
                                      ),
                                      Text(
                                        'Log out of your current session',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.red,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 250.ms, duration: 350.ms),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.leafGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textPrimary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'User Profile',
                style: GoogleFonts.poppins(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.leafGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
