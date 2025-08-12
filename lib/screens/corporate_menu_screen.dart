import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class CorporateMenuScreen extends StatefulWidget {
  const CorporateMenuScreen({super.key});

  @override
  State<CorporateMenuScreen> createState() => _CorporateMenuScreenState();
}

class _CorporateMenuScreenState extends State<CorporateMenuScreen> {
  final UserService _userService = UserService();
  UserModel? _userModel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userModel = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _userModel = userModel;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Sadece kurumsal kullanıcılar bu sayfayı görebilir
    if (_userModel?.userType != UserType.corporate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erişim Reddedildi')),
        body: const Center(
          child: Text('Bu sayfaya sadece kurumsal kullanıcılar erişebilir.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurumsal Menü'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hoş geldiniz, ${_userModel?.organizationName ?? _userModel?.fullName}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildMenuCard(
                    context,
                    title: 'Ürün Yönetimi',
                    subtitle: 'Ürünlerinizi kaydedin ve yönetin',
                    icon: Icons.inventory,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/corporateProducts',
                        arguments: {'corporateId': _userModel?.uid},
                      );
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'QR Doğrulama',
                    subtitle: 'Askıdan alınacak ürünleri doğrulayın',
                    icon: Icons.qr_code_scanner,
                    color: Theme.of(context).colorScheme.tertiary,
                    onTap: () {
                      Navigator.pushNamed(context, '/qrValidator');
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'Askı Geçmişi',
                    subtitle: 'Ürünlerinizin askı geçmişini görün',
                    icon: Icons.history,
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      _showComingSoon(context, 'Askı Geçmişi');
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: 'İstatistikler',
                    subtitle: 'Askı ve alım istatistikleriniz',
                    icon: Icons.analytics,
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () {
                      _showComingSoon(context, 'İstatistikler');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Yakında'),
            content: Text('$feature özelliği yakında eklenecek.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }
}
