import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserService _userService = UserService();
  UserModel? _currentUser;
  bool _isLoading = true;

  // Bildirim ayarları
  bool _applicationNotifications = true;
  bool _productClaimedNotifications = true;
  bool _newPostNotifications = false;
  bool _adminNotifications = true;
  bool _emailNotifications = false;

  // Gizlilik ayarları
  bool _showProfile = true;
  bool _showPosts = true;
  bool _allowDirectMessages = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  Future<void> _loadUserSettings() async {
    try {
      final user = await _userService.getCurrentUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
          // Kullanıcının mevcut ayarlarını yükle (gerçek uygulamada Firestore'dan gelecek)
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ayarlar yüklenirken hata: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Ayarları Firestore'a kaydet (gelecekte implementasyon)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ayarlar kaydedildi'),
            backgroundColor:
                Theme.of(context).colorScheme.primary, // Use primary color
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ayarlar kaydedilirken hata: $e'),
            backgroundColor:
                Theme.of(context).colorScheme.error, // Use error color
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Çıkış yaptıktan sonra giriş ekranına yönlendir
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Çıkış yapılırken hata: $e'),
            backgroundColor:
                Theme.of(context).colorScheme.error, // Use error color
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hesabı Sil'),
            content: const Text(
              'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ), // Use error color
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        // Hesap silme işlemi (gelecekte implementasyon)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Hesap silme talebi alındı'),
              backgroundColor:
                  Theme.of(
                    context,
                  ).colorScheme.secondary, // Use secondary color
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor:
                  Theme.of(context).colorScheme.error, // Use error color
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Kaydet',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Kullanıcı bilgileri
          if (_currentUser != null) ...[
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              _currentUser!.userType == UserType.corporate
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondary // Use secondary for corporate
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary, // Use primary for individual
                          child: Icon(
                            _currentUser!.userType == UserType.corporate
                                ? Icons.business
                                : Icons.person,
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .onPrimary, // Use onPrimary for icon color
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentUser!.fullName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _currentUser!.email,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.7).round()),
                                ),
                              ),
                              Text(
                                _currentUser!.userType.displayName,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.6).round()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Bildirim ayarları
          Text(
            'Bildirim Ayarları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Başvuru Bildirimleri',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Postlarınıza yapılan başvurular',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _applicationNotifications,
                  onChanged: (value) {
                    setState(() => _applicationNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'Ürün Teslim Bildirimleri',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Ürünleriniz teslim alındığında',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _productClaimedNotifications,
                  onChanged: (value) {
                    setState(() => _productClaimedNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'Yeni Post Bildirimleri',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'İlginizi çekebilecek yeni postlar',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _newPostNotifications,
                  onChanged: (value) {
                    setState(() => _newPostNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'Sistem Bildirimleri',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Önemli sistem güncellemeleri',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _adminNotifications,
                  onChanged: (value) {
                    setState(() => _adminNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'E-posta Bildirimleri',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Bildirimleri e-posta ile al',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.tune,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    'Gelişmiş Bildirim Ayarları',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Tüm bildirim türlerini yönet',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/notificationSettings');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Gizlilik ayarları
          Text(
            'Gizlilik Ayarları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(
                    'Profili Göster',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Profilinizi diğer kullanıcılara göster',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _showProfile,
                  onChanged: (value) {
                    setState(() => _showProfile = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'Postları Göster',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Postlarınızı herkese açık göster',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _showPosts,
                  onChanged: (value) {
                    setState(() => _showPosts = value);
                  },
                ),
                SwitchListTile(
                  title: Text(
                    'Direkt Mesajlara İzin Ver',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Diğer kullanıcıların size mesaj göndermesine izin ver',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  value: _allowDirectMessages,
                  onChanged: (value) {
                    setState(() => _allowDirectMessages = value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Hesap işlemleri
          Text(
            'Hesap İşlemleri',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                  ), // Use primary color
                  title: Text(
                    'Profili Düzenle',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Profil bilgilerinizi güncelleyin',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    // Profil düzenleme sayfasına git
                    Navigator.pushNamed(context, '/editProfile');
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.security,
                    color: Theme.of(context).colorScheme.secondary,
                  ), // Use secondary color
                  title: Text(
                    'Şifre Değiştir',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Hesap güvenliğinizi artırın',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    // Şifre değiştirme sayfasına git
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Şifre değiştirme yakında eklenecek',
                        ),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.secondary, // Use secondary color
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.download,
                    color: Theme.of(context).colorScheme.primary,
                  ), // Use primary color
                  title: Text(
                    'Verilerimi İndir',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Kişisel verilerinizin kopyasını indirin',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Veri indirme yakında eklenecek'),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.primary, // Use primary color
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ), // Keep grey for logout
                  title: Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Hesabınızdan güvenli çıkış yapın',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: _logout,
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ), // Use error color
                  title: Text(
                    'Hesabı Sil',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: Text(
                    'Hesabınızı kalıcı olarak silin',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Uygulama bilgileri
          Text(
            'Uygulama',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                  ), // Use primary color
                  title: Text(
                    'Hakkında',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Askıda uygulaması v1.0.0',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Askıda',
                      applicationVersion: '1.0.0',
                      applicationIcon: Icon(
                        Icons.shopping_basket,
                        size: 48,
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.primary, // Use primary color
                      ),
                      children: [
                        Text(
                          'Paylaşım ve yardımlaşma platformu',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '© 2025 Askıda Platformu',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.policy,
                    color: Theme.of(context).colorScheme.secondary,
                  ), // Use secondary color
                  title: Text(
                    'Gizlilik Politikası',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Verilerinizi nasıl koruduğumuz',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Gizlilik politikası yakında eklenecek',
                        ),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.secondary, // Use secondary color
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.support,
                    color: Theme.of(context).colorScheme.primary,
                  ), // Use primary color
                  title: Text(
                    'Destek',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Yardım ve destek alın',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Destek sistemi yakında eklenecek'),
                        backgroundColor:
                            Theme.of(
                              context,
                            ).colorScheme.primary, // Use primary color
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
