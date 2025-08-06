import 'package:flutter/material.dart';
import '../models/aski_model.dart';
import '../models/user_model.dart';
import '../services/aski_service.dart';
import '../services/user_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final AskiService _askiService = AskiService();
  final UserService _userService = UserService();

  List<AskiModel> _askiList = [];
  List<AskiModel> _filteredAskiList = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  String _selectedCategory = 'Tümü';
  AskiStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
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
      final askiStream = _askiService.getActiveAskis();
      askiStream.listen((askiList) {
        if (mounted) {
          setState(() {
            _askiList = askiList;
            _applyFilters();
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
    List<AskiModel> filtered = List.from(_askiList);

    // Durum filtresi
    if (_selectedStatus != null) {
      filtered =
          filtered.where((aski) => aski.status == _selectedStatus).toList();
    }

    // Kategori filtresi için product bilgisini almak gerekiyor
    // Şimdilik sadece isme göre arama yapabiliriz
    if (_selectedCategory != 'Tümü') {
      filtered =
          filtered
              .where(
                (aski) => aski.productName.toLowerCase().contains(
                  _selectedCategory.toLowerCase(),
                ),
              )
              .toList();
    }

    setState(() {
      _filteredAskiList = filtered;
    });
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
                    setState(() {
                      // Dialog'dan main state'e değerleri aktar
                    });
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
        itemCount: displayList.length + (_currentUser?.userType == UserType.corporate ? 1 : 0),
        itemBuilder: (context, index) {
          // Kurumsal kullanıcılar için QR tarama kartı
          if (_currentUser?.userType == UserType.corporate && index == 0) {
            return _buildQRScannerCard();
          }
          
          // Normal askı kartları
          final askiIndex = _currentUser?.userType == UserType.corporate ? index - 1 : index;
          final aski = displayList[askiIndex];
          return _buildAskiCard(aski);
        },
      ),
    );
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
                    child: InkWell(
                      onTap:
                          aski.status == AskiStatus.active
                              ? () {
                                if (_currentUser?.userType ==
                                    UserType.corporate) {
                                  // Kurumsal kullanıcılar askıdan ürün alamaz
                                  _showCorporateInfoDialog();
                                } else {
                                  // Bireysel kullanıcılar için ürün alma
                                  if (aski.donorUserId == _currentUser?.uid) {
                                    // Kendi ürününü alamaz
                                    _showOwnProductDialog();
                                  } else {
                                    // Ürünü al ve QR göster
                                    _showTakeProductDialog(aski);
                                  }
                                }
                              }
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              aski.status == AskiStatus.active
                                  ? (_currentUser?.userType ==
                                          UserType.corporate
                                      ? Colors.grey.shade50
                                      : (aski.donorUserId == _currentUser?.uid
                                          ? Colors.red.shade50
                                          : Colors.green.shade50))
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                aski.status == AskiStatus.active
                                    ? (_currentUser?.userType ==
                                            UserType.corporate
                                        ? Colors.grey.shade200
                                        : (aski.donorUserId == _currentUser?.uid
                                            ? Colors.red.shade200
                                            : Colors.green.shade200))
                                    : Colors.grey.shade300,
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
                                  aski.status == AskiStatus.active
                                      ? (_currentUser?.userType ==
                                              UserType.corporate
                                          ? Colors.grey.shade600
                                          : (aski.donorUserId ==
                                                  _currentUser?.uid
                                              ? Colors.red.shade600
                                              : Colors.green.shade600))
                                      : Colors.grey.shade500,
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
                                      aski.status == AskiStatus.active
                                          ? (_currentUser?.userType ==
                                                  UserType.corporate
                                              ? Colors.grey.shade700
                                              : (aski.donorUserId ==
                                                      _currentUser?.uid
                                                  ? Colors.red.shade700
                                                  : Colors.green.shade700))
                                          : Colors.grey.shade600,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (aski.status == AskiStatus.active &&
                                _currentUser?.userType != UserType.corporate &&
                                aski.donorUserId != _currentUser?.uid)
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.green.shade600,
                                size: 16,
                              ),
                          ],
                        ),
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

  Widget _buildQRScannerCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR Kod Tarayıcı',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Müşteri QR kodunu okutun',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Açıklama
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Nasıl Çalışır?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Müşteri askıdan ürün almak istediğinde QR kodunu gösterir\n'
                      '2. Bu butona tıklayarak QR tarayıcıyı açın\n'
                      '3. Müşterinin QR kodunu okutun\n'
                      '4. Ürünü teslim edin ve işlemi tamamlayın',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // QR Tarama Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/qrValidator');
                  },
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(
                    'QR Kod Tarayıcıyı Aç',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
              const Text('QR Okut'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ürün: ${aski.productName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bağışçı: ${aski.donorUserName}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kurum: ${aski.corporateName}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu ürün için QR kodunu görmek istediğinizden emin misiniz?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR kodunu göstererek mağazada ürünü teslim alabilirsiniz. Kurumsal kullanıcı QR\'ı taratıp teslim ettikten sonra askı tamamlanır.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _takeProduct(aski);
              },
              icon: const Icon(Icons.check),
              label: const Text('QR Okut'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  // Ürün alma işlemi
  void _takeProduct(AskiModel aski) async {
    try {
      if (_currentUser == null) return;

      // ASKIYI DÜŞÜRME! Sadece QR göster
      // QR göster
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/qrDisplay',
          arguments: {
            'askiId': aski.id,
            'productName': aski.productName,
            'corporateName': aski.corporateName,
            'isPickup': true, // Teslim alma için
          },
        );
      }

      // Başarı mesajı
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.qr_code, color: Colors.white),
                const SizedBox(width: 8),
                Text('QR kodu gösteriliyor. Mağazada bu kodu okutun.'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Hata: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
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
