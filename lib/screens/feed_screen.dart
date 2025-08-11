import 'package:flutter/material.dart';
import 'dart:async'; // StreamSubscription için eklendi
import '../models/aski_model.dart';
import '../models/user_model.dart';
import '../services/aski_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart'; // NotificationService eklendi
import '../models/notification_model.dart'; // NotificationModel eklendi
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth eklendi
import 'dart:developer' as developer; // Log için eklendi
import '../models/application_model.dart'; // ApplicationModel eklendi

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final AskiService _askiService = AskiService();
  final UserService _userService = UserService();
  final NotificationService _notificationService =
      NotificationService(); // NotificationService örneği
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;

  List<AskiModel> _askiList = [];
  final List<AskiModel> _filteredAskiList = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = 'Tümü';
  AskiStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenForNotifications(); // Bildirimleri dinlemeye başla
  }

  Future<void> _loadData() async {
    try {
      // Kullanıcı bilgilerini yükle
      final currentUser = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = currentUser;
        });
      }

      // Aktif askıları yükle
      final askiStream = _askiService.getFilteredAskis(
        category: _selectedCategory,
        status: _selectedStatus, // Durum filtresi eklendi
        takenByUserId:
            _selectedStatus == AskiStatus.taken
                ? _currentUser?.uid
                : null, // Alınan askılar için kullanıcı ID'si
      );
      askiStream.listen((askiList) {
        if (mounted) {
          setState(() {
            _askiList = askiList;
            _filteredAskiList.clear(); // Mevcut filtreli listeyi temizle
            _filteredAskiList.addAll(askiList); // Yeni listeyi ekle
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenForNotifications() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    _notificationSubscription = _notificationService
        .getUserNotificationsStream(
          userId: currentUserUid,
          includeRead: true,
        ) // Okunmuş bildirimleri de dahil et
        .listen((notifications) async {
          developer.log(
            'FeedScreen: Yeni bildirimler geldi. Sayı: ${notifications.length}',
            name: 'FeedScreen',
          );
          for (var notification in notifications) {
            if (!notification.isRead) {
              if (mounted) {
                developer.log(
                  'FeedScreen: SnackBar gösteriliyor: ${notification.message}',
                  name: 'FeedScreen',
                );
                _showNotificationSnackBar(notification);
                // SnackBar'ın görünmesi için kısa bir gecikme ekle
                await Future.delayed(
                  const Duration(seconds: 1),
                ); // Gecikmeyi 1 saniyeye çıkar
              }
              _notificationService.markAsRead(notification.id);
              break; // Sadece ilk okunmamış bildirimi göster
            }
          }
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _showNotificationSnackBar(NotificationModel notification) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Görüntüle',
          textColor: Colors.white,
          onPressed: () {
            // Always navigate to the notifications screen
            Navigator.of(context).pushNamed('/notifications');
          },
        ),
      ),
    );
  }

  void _showError(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Askıda'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _AskiSearchDelegate(
                  _filteredAskiList.isNotEmpty ? _filteredAskiList : _askiList,
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
    );
  }

  void _applyFilters() {
    // _loadData'yı yeniden tetikleyerek filtrelemeyi Firestore seviyesinde yap
    setState(() {
      _isLoading = true;
    });
    _loadData();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filtrele'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kategori Filtresi
                  const Text(
                    'Kategori:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items:
                        [
                              'Tümü',
                              'Ekmek',
                              'Su',
                              'Çorba',
                              'Meyve',
                              'Sebze',
                              'Et',
                              'Süt',
                              'Giyim',
                              'Ayakkabı',
                              'Diğer',
                            ]
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedCategory = value ?? 'Tümü';
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Durum Filtresi
                  const Text(
                    'Durum:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AskiStatus?>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tümü')),
                      ...AskiStatus.values.map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(_getStatusText(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Filtreleri sıfırla
                    setState(() {
                      _selectedCategory = 'Tümü';
                      _selectedStatus = null;
                    });
                    setDialogState(() {
                      _selectedCategory = 'Tümü';
                      _selectedStatus = null;
                    });
                    _applyFilters();
                  },
                  child: const Text('Sıfırla'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildContent() {
    final displayList =
        _filteredAskiList.isNotEmpty ? _filteredAskiList : _askiList;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz askı bulunmuyor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'İlk askıyı sen oluştur ve\npaylaşım zincirini başlat!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/createPost');
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('İlk Askıyı Oluştur'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final aski = displayList[index];
          return _buildAskiCard(aski);
        },
      ), // ListView.builder kapanışı
    ); // RefreshIndicator kapanışı
  }

  Widget _buildAskiCard(AskiModel aski) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header - Kullanıcı bilgisi ve durum
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        aski.donorUserName.isNotEmpty
                            ? aski.donorUserName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aski.donorUserName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          _formatDate(aski.createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(aski.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(aski.status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Ürün bilgisi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer,
                          color: Colors.blue.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            aski.productName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (aski.message != null && aski.message!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          aski.message!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Alt kısım - QR kod bilgisi ve aksiyon butonu
              Row(
                children: [
                  Expanded(
                    child: _buildAskiCardActions(aski), // Yeni metod çağrısı
                  ),
                ],
              ),
            ],
          ),
        ),
      ), // Padding kapanışı
    ); // Card kapanışı
  }

  // Yeni metod: Askı kartı aksiyonlarını gönderi tipine göre oluştur
  Widget _buildAskiCardActions(AskiModel aski) {
    // Eğer askı aktif değilse, aksiyon gösterme
    if (aski.status != AskiStatus.active) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade500, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getStatusText(aski.status),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Aktif askılar için gönderi tipine göre aksiyonlar
    if (aski.postType == PostType.firstComeFirstServe) {
      return InkWell(
        onTap: () {
          if (_currentUser?.userType == UserType.corporate) {
            _showCorporateInfoDialog();
          } else {
            if (aski.donorUserId == _currentUser?.uid) {
              _showOwnProductDialog();
            } else {
              _showTakeProductDialog(aski);
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                _currentUser?.userType == UserType.corporate
                    ? Colors.grey.shade50
                    : (aski.donorUserId == _currentUser?.uid
                        ? Colors.red.shade50
                        : Colors.green.shade50),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  _currentUser?.userType == UserType.corporate
                      ? Colors.grey.shade200
                      : (aski.donorUserId == _currentUser?.uid
                          ? Colors.red.shade200
                          : Colors.green.shade200),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _currentUser?.userType == UserType.corporate
                    ? Icons.info
                    : (aski.donorUserId == _currentUser?.uid
                        ? Icons.block
                        : Icons.shopping_cart),
                color:
                    _currentUser?.userType == UserType.corporate
                        ? Colors.grey.shade600
                        : (aski.donorUserId == _currentUser?.uid
                            ? Colors.red.shade600
                            : Colors.green.shade600),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentUser?.userType == UserType.corporate
                      ? 'Sadece mağazada QR okut'
                      : (aski.donorUserId == _currentUser?.uid
                          ? 'Kendi ürününüz'
                          : 'QR Okut'),
                  style: TextStyle(
                    color:
                        _currentUser?.userType == UserType.corporate
                            ? Colors.grey.shade700
                            : (aski.donorUserId == _currentUser?.uid
                                ? Colors.red.shade700
                                : Colors.green.shade700),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_currentUser?.userType != UserType.corporate &&
                  aski.donorUserId != _currentUser?.uid)
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.green.shade600,
                  size: 16,
                ),
            ],
          ),
        ),
      );
    } else if (aski.postType == PostType.randomSelection) {
      // Rastgele seçim askıları için farklı aksiyonlar
      if (aski.donorUserId == _currentUser?.uid) {
        // Sadece askı sahibi görebilir
        // Askı sahibi ise başvuruları gör ve rastgele seç
        return InkWell(
          onTap: () => _showApplicationsDialog(aski), // Yeni dialog
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.people_alt, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Başvuruları Görüntüle',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.blue.shade600,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      } else if (_currentUser?.userType == UserType.individual) {
        // Bireysel kullanıcı ise başvur butonu
        return InkWell(
          onTap: () => _applyToRandomAski(aski), // Yeni metod
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.how_to_reg, color: Colors.purple.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Başvur',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.purple.shade600,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      } else {
        // Kurumsal kullanıcı ise bilgi mesajı
        return InkWell(
          onTap: _showCorporateInfoDialog,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.grey.shade600, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kurumsal kullanıcılar başvuru yapamaz',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    return const SizedBox.shrink(); // Varsayılan olarak boş döndür
  }

  // Yeni metod: Rastgele seçim askısına başvur
  Future<void> _applyToRandomAski(AskiModel aski) async {
    if (_currentUser == null) {
      _showError('Başvuru yapmak için giriş yapmalısınız.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await _askiService.applyToAski(aski.id);
      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Askıya başarıyla başvurdunuz!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          _showError('Başvuru yapılamadı veya zaten başvuruldu.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Başvuru sırasında hata oluştu: $e');
      }
    }
  }

  // Yeni metod: Başvuruları görüntüle ve rastgele seç
  void _showApplicationsDialog(AskiModel aski) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Başvurular'),
          content: StreamBuilder<List<ApplicationModel>>(
            stream: _askiService.getApplicationsForAski(aski.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('Henüz başvuru yok.'));
              }

              final applications = snapshot.data!;

              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: applications.length,
                  itemBuilder: (context, index) {
                    final app = applications[index];
                    return ListTile(
                      title: Text(app.applicantUserName),
                      subtitle: Text(app.status.displayName),
                      trailing:
                          app.status == ApplicationStatus.accepted
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                              : app.status == ApplicationStatus.rejected
                              ? const Icon(Icons.cancel, color: Colors.red)
                              : null,
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Kapat'),
            ),
            if (aski.status == AskiStatus.active &&
                aski.donorUserId ==
                    _currentUser?.uid) // Sadece askı sahibi seçebilir
              ElevatedButton(
                onPressed: () async {
                  final currentContext =
                      context; // BuildContext'i async işlemden önce yakala
                  setState(() => _isLoading = true);
                  final selectedApplicant = await _askiService
                      .selectRandomApplicant(aski.id);
                  if (mounted) {
                    setState(() => _isLoading = false);
                    if (selectedApplicant != null) {
                      if (currentContext.mounted) {
                        // Add this check
                        ScaffoldMessenger.of(currentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Kazanan seçildi: ${selectedApplicant.applicantUserName}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      if (dialogContext.mounted) {
                        // dialogContext'in mounted olup olmadığını kontrol et
                        Navigator.pop(dialogContext); // Dialogu kapat
                      }
                    } else {
                      _showError('Kazanan seçilemedi veya başvuru yok.');
                    }
                  }
                },
                child: const Text('Rastgele Seç'),
              ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} gün önce';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} saat önce';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} dakika önce';
    } else {
      return 'Şimdi';
    }
  }

  Color _getStatusColor(AskiStatus status) {
    switch (status) {
      case AskiStatus.active:
        return Colors.green;
      case AskiStatus.taken:
        return Colors.blue;
      case AskiStatus.expired:
        return Colors.orange;
      case AskiStatus.cancelled:
        return Colors.red;
      case AskiStatus.completed:
        return Colors.purple; // Choose an appropriate color
    }
  }

  String _getStatusText(AskiStatus status) {
    switch (status) {
      case AskiStatus.active:
        return 'Aktif';
      case AskiStatus.taken:
        return 'Alındı';
      case AskiStatus.expired:
        return 'Süresi Doldu';
      case AskiStatus.cancelled:
        return 'İptal Edildi';
      case AskiStatus.completed:
        return 'Tamamlandı'; // Add text for completed status
    }
  }

  // Kurumsal kullanıcılar için bilgi dialogu
  void _showCorporateInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              const Text('Bilgi'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kurumsal kullanıcılar askıdan ürün alamaz.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Müşteriler mağazanıza geldiğinde QR kodunu okutarak ürünü teslim edebilirsiniz.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anladım'),
            ),
          ],
        );
      },
    );
  }

  // Kendi ürünü için uyarı dialogu
  void _showOwnProductDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade600),
              const SizedBox(width: 8),
              const Text('Uyarı'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kendi bıraktığınız ürünü alamazsınız.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Bu ürün başka bir kullanıcı tarafından alınabilir.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  // Ürün alma onay dialogu
  void _showTakeProductDialog(AskiModel aski) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Ürün Al'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu ürünü almak istediğinizi onaylıyor musunuz?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ürün: ${aski.productName}'),
                    Text('Firma: ${aski.corporateName}'),
                    Text('Bağışçı: ${aski.donorUserName}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Onayladığınızda QR kod gösterilecek. Bu QR kodu firmaya göstererek ürününüzü alabilirsiniz.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToQRDisplay(aski);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('QR Kodu Göster'),
            ),
          ],
        );
      },
    );
  }

  // QR kod ekranına yönlendir
  void _navigateToQRDisplay(AskiModel aski) async {
    // async eklendi
    final currentContext = context; // BuildContext'i async işlemden önce yakala
    Navigator.pushNamed(
      currentContext,
      '/qrDisplay',
      arguments: {
        'askiId': aski.id,
        'productName': aski.productName,
        'corporateName': aski.corporateName,
        'corporateId': aski.corporateId,
        'applicantUserId': _currentUser?.uid,
      },
    );

    // Bilgi mesajı
    if (currentContext.mounted) {
      // mounted kontrolü eklendi
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.qr_code, color: Colors.white),
              SizedBox(width: 8),
              Text('QR kodu mağazada gösterin'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

class _AskiSearchDelegate extends SearchDelegate {
  final List<AskiModel> askiList;

  _AskiSearchDelegate(this.askiList);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredList =
        askiList
            .where(
              (aski) =>
                  aski.productName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  aski.donorUserName.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();

    if (filteredList.isEmpty) {
      return const Center(child: Text('Arama sonucu bulunamadı'));
    }

    return ListView.builder(
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final aski = filteredList[index];
        return ListTile(
          title: Text(aski.productName),
          subtitle: Text(aski.donorUserName),
          leading: const Icon(Icons.local_offer),
          onTap: () {
            close(context, aski);
          },
        );
      },
    );
  }
}
