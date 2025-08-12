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
import 'package:askida/models/product_model.dart'; // ProductModel için eklendi
import 'package:askida/services/product_service.dart'; // ProductService için eklendi

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
  final ProductService _productService = ProductService(); // Yeni eklendi
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;

  List<AskiModel> _askiList = [];
  final List<AskiModel> _filteredAskiList = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = 'Tümü';
  AskiStatus? _selectedStatus;
  List<String> _availableCategories = ['Tümü']; // Initialize with default

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

      // Kategorileri yükle
      final categories = await _productService.getAllCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
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
        backgroundColor:
            Theme.of(
              context,
            ).colorScheme.primary, // Use primary color for notifications
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Görüntüle',
          textColor:
              Theme.of(context)
                  .colorScheme
                  .onPrimary, // Use onPrimary for text on primary background
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
        backgroundColor:
            Theme.of(context).colorScheme.error, // Use error color for errors
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
                        _availableCategories
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
              color: Theme.of(context).colorScheme.outline, // Use outline color
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz askı bulunmuyor',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color:
                    Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant, // Use onSurfaceVariant
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'İlk askıyı sen oluştur ve\npaylaşım zincirini başlat!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
              ), // Use onSurfaceVariant with opacity
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
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ], // Use theme colors for gradient
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
                  FutureBuilder<UserModel?>(
                    future: _userService.getUserById(
                      aski.donorUserId,
                    ), // Fetch donor user details
                    builder: (context, snapshot) {
                      String? profileImageUrl = snapshot.data?.profileImageUrl;
                      String displayName =
                          aski.donorUserName.isNotEmpty
                              ? aski.donorUserName
                              : 'Bilinmiyor';
                      String initial =
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?';

                      return Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(
                                (255 * 0.3).round(),
                              ), // Use withAlpha
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child:
                            profileImageUrl != null &&
                                    profileImageUrl.isNotEmpty
                                ? ClipOval(
                                  child: Image.network(
                                    profileImageUrl,
                                    fit: BoxFit.cover,
                                    width: 50,
                                    height: 50,
                                    errorBuilder:
                                        (context, error, stackTrace) => Center(
                                          child: Text(
                                            initial,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                        ),
                                  ),
                                )
                                : Center(
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aski.donorUserName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _formatDate(aski.createdAt),
                          style: TextStyle(
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant, // Use onSurfaceVariant
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(aski.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(aski.status),
                      style: TextStyle(
                        color:
                            Theme.of(
                              context,
                            ).colorScheme.onPrimary, // Text on status color
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Ürün bilgisi
              FutureBuilder<ProductModel?>(
                future: _productService.getProduct(
                  aski.productId,
                ), // Fetch product details
                builder: (context, snapshot) {
                  String? productImageUrl = snapshot.data?.imageUrl;
                  return Row(
                    children: [
                      if (productImageUrl != null && productImageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Image.network(
                            productImageUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder:
                                (context, error, stackTrace) => Icon(
                                  Icons.image,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  size: 60,
                                ),
                          ),
                        )
                      else
                        Icon(
                          Icons.bookmark,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 24,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        aski.productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (aski.message != null && aski.message!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 32.0),
                  child: Text(
                    aski.message!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ), // Use onSurfaceVariant
                  ),
                ),
              const SizedBox(height: 16),
              // Aksiyon butonu
              _buildAskiCardActions(aski), // Yeni metod çağrısı
            ],
          ),
        ),
      ),
    ); // Card kapanışı
  }

  // Yeni metod: Askı kartı aksiyonlarını gönderi tipine göre oluştur
  Widget _buildAskiCardActions(AskiModel aski) {
    // Eğer askı aktif değilse, aksiyon gösterme
    if (aski.status != AskiStatus.active) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              Theme.of(context)
                  .colorScheme
                  .surfaceContainerLowest, // Use surfaceContainerLowest
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ), // Use outlineVariant
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ), // Use onSurfaceVariant
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getStatusText(aski.status),
                style: TextStyle(
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Use onSurfaceVariant
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
      if (_currentUser?.userType == UserType.corporate) {
        // Corporate user sees QR scan option (for delivery confirmation)
        return InkWell(
          onTap: () {
            Navigator.of(context).pushNamed('/qrValidator');
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest, // Use surfaceContainerLowest
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ), // Use outlineVariant
            ),
            child: Row(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Use onSurfaceVariant
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR Okut (Teslimat Onayı)', // Changed text
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant, // Use onSurfaceVariant
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant, // Use onSurfaceVariant
                  size: 16,
                ),
              ],
            ),
          ),
        );
      } else if (aski.donorUserId == _currentUser?.uid) {
        // Donor sees their own product
        return InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(
                    context,
                  ).colorScheme.errorContainer, // Use errorContainer
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error,
              ), // Use error color
            ),
            child: Row(
              children: [
                Icon(
                  Icons.block,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  size: 20,
                ), // Use onErrorContainer
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kendi ürününüz',
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onErrorContainer, // Use onErrorContainer
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Individual user can take the aski
        return InkWell(
          onTap: () => _takeFirstComeFirstServeAski(aski), // New method
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer, // Use primaryContainer
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
              ), // Use primary color
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer, // Use onPrimaryContainer
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Askıyı Al', // Changed text
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer, // Use onPrimaryContainer
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer, // Use onPrimaryContainer
                  size: 16,
                ),
              ],
            ),
          ),
        );
      }
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
              color:
                  Theme.of(
                    context,
                  ).colorScheme.secondaryContainer, // Use secondaryContainer
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary,
              ), // Use secondary color
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_alt,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  size: 20,
                ), // Use onSecondaryContainer
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Başvuruları Görüntüle',
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer, // Use onSecondaryContainer
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onSecondaryContainer, // Use onSecondaryContainer
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
              color:
                  Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer, // Use tertiaryContainer
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary,
              ), // Use tertiary color
            ),
            child: Row(
              children: [
                Icon(
                  Icons.how_to_reg,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                  size: 20,
                ), // Use onTertiaryContainer
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Başvur',
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer, // Use onTertiaryContainer
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .onTertiaryContainer, // Use onTertiaryContainer
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
              color:
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainerLowest, // Use surfaceContainerLowest
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ), // Use outlineVariant
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ), // Use onSurfaceVariant
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kurumsal kullanıcılar başvuru yapamaz',
                    style: TextStyle(
                      color:
                          Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant, // Use onSurfaceVariant
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
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Askıya başarıyla başvurdunuz!'),
            backgroundColor:
                Theme.of(context).colorScheme.primary, // Use primary color
          ),
        );
      } else {
        _showError('Başvuru yapılamadı veya zaten başvuruldu.');
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

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 300.0, // Constrain the height of the list
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: applications.length,
                      itemBuilder: (context, index) {
                        final app = applications[index];
                        return FutureBuilder<UserModel?>(
                          future: _userService.getUserById(app.applicantUserId),
                          builder: (context, userSnapshot) {
                            String? profileImageUrl =
                                userSnapshot.data?.profileImageUrl;
                            String displayName =
                                app.applicantUserName.isNotEmpty
                                    ? app.applicantUserName
                                    : 'Bilinmiyor';
                            String initial =
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 0.0,
                              ),
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha((255 * 0.2).round()),
                                  backgroundImage:
                                      profileImageUrl != null &&
                                              profileImageUrl.isNotEmpty
                                          ? NetworkImage(profileImageUrl)
                                              as ImageProvider
                                          : null,
                                  child:
                                      profileImageUrl == null ||
                                              profileImageUrl.isEmpty
                                          ? Text(
                                            initial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : null,
                                ),
                                title: Text(app.applicantUserName),
                                subtitle: Text(app.status.displayName),
                                trailing:
                                    app.status == ApplicationStatus.accepted
                                        ? Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                        : app.status ==
                                            ApplicationStatus.rejected
                                        ? Icon(Icons.cancel, color: Colors.red)
                                        : null,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Kapat'),
                        ),
                        if (applications.isNotEmpty &&
                            aski.postType ==
                                PostType
                                    .randomSelection) // Only show if there are applications and it's random selection
                          ElevatedButton(
                            onPressed: () async {
                              final currentDialogContext =
                                  dialogContext; // Capture context before async gap
                              final selectedApplicant = await _askiService
                                  .selectRandomApplicant(aski.id);
                              if (!currentDialogContext.mounted) {
                                return; // Check mounted status of captured context
                              }
                              if (selectedApplicant != null) {
                                ScaffoldMessenger.of(
                                  currentDialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Rastgele seçilen kişi: ${selectedApplicant.applicantUserName}',
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                );
                                Navigator.pop(
                                  currentDialogContext,
                                ); // Close dialog after selection
                              } else {
                                ScaffoldMessenger.of(
                                  currentDialogContext,
                                ).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Rastgele kişi seçilemedi.',
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                  ),
                                );
                              }
                            },
                            child: const Text('Rastgele Seç'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
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
        return Theme.of(context).colorScheme.primary; // Use primary color
      case AskiStatus.taken:
        return Theme.of(context).colorScheme.secondary; // Use secondary color
      case AskiStatus.expired:
        return Colors.orange; // Keep orange for now, as it's not in the palette
      case AskiStatus.cancelled:
        return Theme.of(context).colorScheme.error; // Use error color
      case AskiStatus.completed:
        return Colors.purple; // Keep purple for now, as it's not in the palette
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
              Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.primary,
              ), // Use primary color
              const SizedBox(width: 8),
              const Text('Bilgi'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kurumsal kullanıcılar askıdan ürün alamaz.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ), // Use onSurface
              ),
              const SizedBox(height: 12),
              Text(
                'Müşteriler mağazanıza geldiğinde QR kodunu okutarak ürünü teslim edebilirsiniz.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ), // Use onSurfaceVariant
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

  Future<void> _takeFirstComeFirstServeAski(AskiModel aski) async {
    if (_currentUser == null) {
      _showError('Kullanıcı bilgileri yüklenemedi.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final success = await _askiService.takeAski(
        askiId: aski.id,
        takenByUserId: _currentUser!.uid,
        takenByUserName: _currentUser!.fullName,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${aski.productName} adlı askı başarıyla alındı! QR kodunuzu göstermek için yönlendiriliyorsunuz.',
            ),
            backgroundColor:
                Theme.of(context).colorScheme.primary, // Use primary color
          ),
        );
        // Send notification to the donor
        final NotificationService notificationService = NotificationService();
        await notificationService.createNotification(
          userId: aski.donorUserId,
          title: NotificationType.askiTaken.displayName,
          message:
              '${_currentUser!.fullName} adlı kullanıcı ${aski.productName} adlı askınızı aldı.',
          type: NotificationType.askiTaken,
          relatedPostId: aski.id,
          data: {
            'askiId': aski.id,
            'productName': aski.productName,
            'takerName': _currentUser!.fullName,
            'takerId': _currentUser!.uid,
          },
        );
        // Navigate to QRDisplayScreen
        if (!mounted) return;
        Navigator.of(context).pushNamed(
          '/qrDisplay',
          arguments: {
            'askiId': aski.id,
            'productName': aski.productName,
            'corporateName': aski.corporateName,
            'corporateId': aski.corporateId,
            'applicantUserId': _currentUser!.uid,
            'postType': aski.postType.name, // Pass postType
          },
        );
      } else {
        _showError('Askı alınırken bir hata oluştu veya zaten alınmış.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Askı alınırken hata: $e');
      }
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
