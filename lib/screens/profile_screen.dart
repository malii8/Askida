import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/aski_model.dart';
import '../services/user_service.dart';
import '../services/aski_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final UserService _userService = UserService();
  final AskiService _askiService = AskiService();

  UserModel? _currentUser;
  bool _isLoading = true;
  Map<String, int> _stats = {'total': 0, 'active': 0, 'taken': 0, 'expired': 0};
  List<AskiModel> _userAskis = [];
  List<AskiModel> _takenAskis = [];

  late TabController _tabController;
  final GlobalKey _takenAskisListKey =
      GlobalKey(); // QR ile alınan ürünler listesi için key

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
    ); // Askılarım ve Geçmiş tabları için
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final currentUser = await _userService.getCurrentUser();

      if (currentUser != null) {
        // Kullanıcının askılarını yükle
        final userAskisStream = _askiService.getUserAskis(currentUser.uid);
        userAskisStream.listen((askis) {
          if (mounted) {
            setState(() {
              _userAskis = askis;
              _stats = _calculateStats(askis);
            });
          }
        });

        // Kullanıcının aldığı askıları yükle (takenByUserId'si currentUser.uid olan askılar)
        final takenAskisStream = _askiService.getFilteredAskis(
          status:
              AskiStatus
                  .completed, // Change from AskiStatus.taken to AskiStatus.completed
          takenByUserId: currentUser.uid,
        );
        takenAskisStream.listen((takenAskis) {
          if (mounted) {
            setState(() {
              _takenAskis = takenAskis;
            });
          }
        });

        if (mounted) {
          setState(() {
            _currentUser = currentUser;
            _isLoading = false;
            _updateTabController();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateTabController() {
    // Bireysel kullanıcılar için sadece Askılarım ve Geçmiş tabları (2 adet)
    // Kurumsal kullanıcılar için sadece Askılarım tabı (1 adet)
    final tabLength = _currentUser?.userType == UserType.individual ? 2 : 1;
    _tabController.dispose();
    _tabController = TabController(length: tabLength, vsync: this);
  }

  Map<String, int> _calculateStats(List<AskiModel> askis) {
    return {
      'total': askis.length,
      'active': askis.where((a) => a.status == AskiStatus.active).length,
      'taken':
          askis
              .where((a) => a.status == AskiStatus.completed)
              .length, // Changed to completed
      'expired': askis.where((a) => a.status == AskiStatus.expired).length,
      'completed':
          askis
              .where((a) => a.status == AskiStatus.completed)
              .length, // Added for consistency
    };
  }

  void _onStatCardTap(String cardTitle) {
    switch (cardTitle) {
      case 'Aldığım Askılar':
        // Aldığım Askılar listesine kaydır
        Scrollable.ensureVisible(
          _takenAskisListKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case 'Toplam Askım':
      case 'Aktif Askılar':
        // Askılarım sekmesine git
        _tabController.animateTo(0);
        break;
      case 'Alınan Askılar':
        // Geçmiş sekmesine git (bireysel kullanıcılar için 2. tab)
        if (_currentUser?.userType == UserType.individual) {
          _tabController.animateTo(1);
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Kullanıcı bilgileri yüklenemedi')),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // Changed to SingleChildScrollView
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildStatsCards(),
            // QR ile Aldığım Ürünler listesi sadece bireysel kullanıcılar için
            if (_currentUser?.userType == UserType.individual) ...[
              _buildTakenAskisList(),
            ],
            _buildTabSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.shadow.withAlpha((255 * 0.3).round()),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profil Resmi / Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(
              (255 * 0.2).round(),
            ), // Use withAlpha
            backgroundImage:
                _currentUser?.profileImageUrl != null &&
                        _currentUser!.profileImageUrl!.isNotEmpty
                    ? NetworkImage(_currentUser!.profileImageUrl!)
                        as ImageProvider
                    : null,
            child:
                _currentUser?.profileImageUrl == null ||
                        _currentUser!.profileImageUrl!.isEmpty
                    ? Text(
                      _currentUser!.fullName.isNotEmpty
                          ? _currentUser!.fullName[0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 20),
          Text(
            _currentUser!.fullName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser!.email,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getUserTypeColor().withAlpha(
                (255 * 0.1).round(),
              ), // Use withAlpha
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getUserTypeColor()),
            ),
            child: Text(
              _getUserTypeText(),
              style: TextStyle(
                color: _getUserTypeColor(),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (_currentUser?.userType ==
              UserType.corporate) // Show approval status for corporate users
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _currentUser!.isApproved
                    ? 'Onaylı Kurumsal Kullanıcı'
                    : 'Onay Bekliyor',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      _currentUser!.isApproved
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final List<Map<String, dynamic>> stats = [
      {
        'title': 'Toplam Askım',
        'value': _stats['total'] ?? 0,
        'icon': Icons.local_offer,
        'color': Theme.of(context).colorScheme.primary,
      },
      {
        'title': 'Aktif Askılar',
        'value': _stats['active'] ?? 0,
        'icon': Icons.check_circle,
        'color': Theme.of(context).colorScheme.tertiary,
      },
      {
        'title': 'Alınan Askılar',
        'value': _stats['taken'] ?? 0,
        'icon': Icons.shopping_bag,
        'color': Theme.of(context).colorScheme.secondary,
      },
    ];

    // Bireysel kullanıcılar için "Aldığım Askılar" kartını ekleme
    if (_currentUser?.userType == UserType.individual) {
      stats.add({
        'title': 'Aldığım Askılar',
        'value': _takenAskis.length,
        'icon': Icons.favorite,
        'color': Theme.of(context).colorScheme.error,
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 20,
      ), // Adjusted margin
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return InkWell(
            onTap: () => _onStatCardTap(stat['title'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withAlpha((255 * 0.15).round()),
                    blurRadius: 12, // Adjusted blur
                    offset: const Offset(0, 6), // Adjusted offset
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        stat['icon'] as IconData,
                        color: stat['color'] as Color,
                        size: 28, // Increased icon size
                      ),
                      Text(
                        '${stat['value']}',
                        style: TextStyle(
                          fontSize: 28, // Increased font size
                          fontWeight: FontWeight.bold,
                          color: stat['color'] as Color,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    stat['title'] as String,
                    style: TextStyle(
                      fontSize: 14, // Increased font size
                      fontWeight: FontWeight.w600,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Aldığım Askılar (QR ile alınan ürünler) kutusu
  Widget _buildTakenAskisList() {
    if (_currentUser?.userType != UserType.individual) {
      return const SizedBox.shrink();
    }

    return Container(
      key: _takenAskisListKey, // GlobalKey ataması
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.shadow.withAlpha((255 * 0.08).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.qr_code_scanner,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'QR ile Aldığım Ürünler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bu listede QR kod okutarak aldığınız ürünler görünür.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
            ),
          ),
          const SizedBox(height: 12),
          if (_takenAskis.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 48,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.3).round()),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Henüz QR ile aldığınız bir ürün yok.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _takenAskis.length,
              itemBuilder: (context, index) {
                final aski = _takenAskis[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withAlpha((255 * 0.1).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag,
                          color: Theme.of(context).colorScheme.error,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aski.productName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              aski.corporateName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.6).round()),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDate(
                          aski.takenAt ?? aski.createdAt,
                        ), // Teslim alınma zamanı
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.5).round()),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabSection() {
    final tabs = <Widget>[const Tab(text: 'Askılarım')];
    // Bireysel kullanıcılar için sadece "Geçmiş" tabı
    if (_currentUser?.userType == UserType.individual) {
      tabs.add(const Tab(text: 'Geçmiş'));
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.shadow.withAlpha((255 * 0.15).round()),
            blurRadius: 12, // Adjusted blur
            offset: const Offset(0, 6), // Adjusted offset
          ),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: tabs,
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          SizedBox(
            height: 400, // Fixed height for TabBarView
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserAskisTab(),
                if (_currentUser?.userType == UserType.individual) ...[
                  _buildHistoryTab(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAskisTab() {
    if (_userAskis.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_offer_outlined,
        title: 'Henüz askın yok',
        subtitle: 'İlk askını oluştur ve paylaşım zincirini başlat!',
        buttonText: 'Askı Oluştur',
        onPressed: () => Navigator.pushNamed(context, '/createPost'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userAskis.length,
      itemBuilder: (context, index) {
        final aski = _userAskis[index];
        return _buildAskiCard(aski);
      },
    );
  }

  Widget _buildHistoryTab() {
    final completedAskis =
        _userAskis
            .where(
              (a) =>
                  a.status == AskiStatus.taken ||
                  a.status == AskiStatus.expired,
            )
            .toList();

    if (completedAskis.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'Geçmiş yok',
        subtitle: 'Tamamlanan askıların burada görünecek',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedAskis.length,
      itemBuilder: (context, index) {
        final aski = completedAskis[index];
        return _buildAskiCard(aski);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? buttonText,
    VoidCallback? onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((255 * 0.3).round()),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
              ),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Text(buttonText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAskiCard(AskiModel aski, {bool isReceived = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    aski.status,
                  ).withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.local_offer,
                  color: _getStatusColor(aski.status),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aski.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isReceived)
                      Text(
                        'Bağışçı: ${aski.donorUserName}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.6).round()),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(aski.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(aski.status),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(aski.createdAt),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (aski.message != null && aski.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Text(
                aski.message!,
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getUserTypeColor() {
    return _currentUser?.userType == UserType.corporate
        ? Theme.of(context)
            .colorScheme
            .secondary // Kurumsal için secondary
        : Theme.of(context).colorScheme.primary; // Bireysel için primary
  }

  String _getUserTypeText() {
    return _currentUser?.userType == UserType.corporate
        ? 'Kurumsal Kullanıcı'
        : 'Bireysel Kullanıcı';
  }

  Color _getStatusColor(AskiStatus status) {
    switch (status) {
      case AskiStatus.active:
        return Theme.of(context).colorScheme.primary; // Aktif için primary
      case AskiStatus.taken:
        return Theme.of(context).colorScheme.secondary; // Alındı için secondary
      case AskiStatus.expired:
        return Theme.of(context).colorScheme.error; // Süresi doldu için error
      case AskiStatus.cancelled:
        return Theme.of(context).colorScheme.error; // İptal edildi için error
      case AskiStatus.completed:
        return Theme.of(
          context,
        ).colorScheme.tertiary; // Tamamlandı için tertiary
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
}
