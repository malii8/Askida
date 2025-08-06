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
          const SnackBar(
            content: Text('Ayarlar kaydedildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayarlar kaydedilirken hata: $e')),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Çıkış yapılırken hata: $e')));
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
                style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            const SnackBar(
              content: Text('Hesap silme talebi alındı'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
                                  ? Colors.blue
                                  : Colors.green,
                          child: Icon(
                            _currentUser!.userType == UserType.corporate
                                ? Icons.business
                                : Icons.person,
                            color: Colors.white,
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(_currentUser!.email),
                              Text(
                                _currentUser!.userType.displayName,
                                style: TextStyle(color: Colors.grey[600]),
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
          const Text(
            'Bildirim Ayarları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Başvuru Bildirimleri'),
                  subtitle: const Text('Postlarınıza yapılan başvurular'),
                  value: _applicationNotifications,
                  onChanged: (value) {
                    setState(() => _applicationNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Ürün Teslim Bildirimleri'),
                  subtitle: const Text('Ürünleriniz teslim alındığında'),
                  value: _productClaimedNotifications,
                  onChanged: (value) {
                    setState(() => _productClaimedNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Yeni Post Bildirimleri'),
                  subtitle: const Text('İlginizi çekebilecek yeni postlar'),
                  value: _newPostNotifications,
                  onChanged: (value) {
                    setState(() => _newPostNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Sistem Bildirimleri'),
                  subtitle: const Text('Önemli sistem güncellemeleri'),
                  value: _adminNotifications,
                  onChanged: (value) {
                    setState(() => _adminNotifications = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('E-posta Bildirimleri'),
                  subtitle: const Text('Bildirimleri e-posta ile al'),
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() => _emailNotifications = value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Gelişmiş Bildirim Ayarları'),
                  subtitle: const Text('Tüm bildirim türlerini yönet'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.pushNamed(context, '/notificationSettings');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Gizlilik ayarları
          const Text(
            'Gizlilik Ayarları',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Profili Göster'),
                  subtitle: const Text(
                    'Profilinizi diğer kullanıcılara göster',
                  ),
                  value: _showProfile,
                  onChanged: (value) {
                    setState(() => _showProfile = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Postları Göster'),
                  subtitle: const Text('Postlarınızı herkese açık göster'),
                  value: _showPosts,
                  onChanged: (value) {
                    setState(() => _showPosts = value);
                  },
                ),
                SwitchListTile(
                  title: const Text('Direkt Mesajlara İzin Ver'),
                  subtitle: const Text(
                    'Diğer kullanıcıların size mesaj göndermesine izin ver',
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
          const Text(
            'Hesap İşlemleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.blue),
                  title: const Text('Profili Düzenle'),
                  subtitle: const Text('Profil bilgilerinizi güncelleyin'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Profil düzenleme sayfasına git
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil düzenleme yakında eklenecek'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.orange),
                  title: const Text('Şifre Değiştir'),
                  subtitle: const Text('Hesap güvenliğinizi artırın'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Şifre değiştirme sayfasına git
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Şifre değiştirme yakında eklenecek'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.green),
                  title: const Text('Verilerimi İndir'),
                  subtitle: const Text(
                    'Kişisel verilerinizin kopyasını indirin',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Veri indirme yakında eklenecek'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.grey),
                  title: const Text('Çıkış Yap'),
                  subtitle: const Text('Hesabınızdan güvenli çıkış yapın'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _logout,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Hesabı Sil'),
                  subtitle: const Text('Hesabınızı kalıcı olarak silin'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Uygulama bilgileri
          const Text(
            'Uygulama',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info, color: Colors.blue),
                  title: const Text('Hakkında'),
                  subtitle: const Text('Askıda uygulaması v1.0.0'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Askıda',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(
                        Icons.shopping_basket,
                        size: 48,
                      ),
                      children: const [
                        Text('Paylaşım ve yardımlaşma platformu'),
                        SizedBox(height: 16),
                        Text('© 2025 Askıda Platformu'),
                      ],
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.policy, color: Colors.purple),
                  title: const Text('Gizlilik Politikası'),
                  subtitle: const Text('Verilerinizi nasıl koruduğumuz'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gizlilik politikası yakında eklenecek'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support, color: Colors.green),
                  title: const Text('Destek'),
                  subtitle: const Text('Yardım ve destek alın'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Destek sistemi yakında eklenecek'),
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
