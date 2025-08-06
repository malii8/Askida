import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/aski_model.dart';
import '../services/user_service.dart';
import '../services/aski_service.dart';

import 'settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        final allAskisStream = _askiService.getActiveAskis();
        allAskisStream.listen((allAskis) {
          final takenByUser =
              allAskis
                  .where((aski) => aski.takenByUserId == currentUser.uid)
                  .toList();
          if (mounted) {
            setState(() {
              _takenAskis = takenByUser;
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
    final tabLength = _currentUser?.userType == UserType.individual ? 3 : 1;
    _tabController.dispose();
    _tabController = TabController(length: tabLength, vsync: this);
  }

  Map<String, int> _calculateStats(List<AskiModel> askis) {
    return {
      'total': askis.length,
      'active': askis.where((a) => a.status == AskiStatus.active).length,
      'taken': askis.where((a) => a.status == AskiStatus.taken).length,
      'expired': askis.where((a) => a.status == AskiStatus.expired).length,
    };
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
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildProfileHeader(),
                _buildStatsCards(),
                _buildTabSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _currentUser!.fullName.isNotEmpty
                    ? _currentUser!.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _currentUser!.fullName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _currentUser!.email,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getUserTypeColor().withValues(alpha: 0.1),
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
          if (_currentUser!.userType == UserType.corporate) ...[
            const SizedBox(height: 16),
            if (_currentUser!.companyName != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentUser!.companyName!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      {
        'title': 'Toplam Askım',
        'value': _stats['total'] ?? 0,
        'icon': Icons.local_offer,
        'color': Colors.blue,
      },
      {
        'title': 'Aktif Askılar',
        'value': _stats['active'] ?? 0,
        'icon': Icons.check_circle,
        'color': Colors.green,
      },
      {
        'title': 'Alınan Askılar',
        'value': _stats['taken'] ?? 0,
        'icon': Icons.shopping_bag,
        'color': Colors.orange,
      },
    ];

    // Kurumsal kullanıcılar için "Aldığım Askılar" kartını ekleme
    if (_currentUser?.userType == UserType.individual) {
      stats.add({
        'title': 'Aldığım Askılar',
        'value': _takenAskis.length,
        'icon': Icons.favorite,
        'color': Colors.red,
      });
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
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
                      size: 24,
                    ),
                    Text(
                      '${stat['value']}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: stat['color'] as Color,
                      ),
                    ),
                  ],
                ),
                Text(
                  stat['title'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabSection() {
    final tabs = <Widget>[const Tab(text: 'Askılarım')];

    // Bireysel kullanıcılar için "Aldıklarım" ve "Geçmiş" tabları
    if (_currentUser?.userType == UserType.individual) {
      tabs.add(const Tab(text: 'Aldıklarım'));
      tabs.add(const Tab(text: 'Geçmiş'));
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          SizedBox(
            height: 400,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUserAskisTab(),
                if (_currentUser?.userType == UserType.individual) ...[
                  _buildTakenAskisTab(),
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

  Widget _buildTakenAskisTab() {
    if (_takenAskis.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'Henüz askı almadın',
        subtitle: 'QR kod tarayarak askılardan ürün alabilirsin!',
        buttonText: 'QR Kod Tara',
        onPressed: () => Navigator.pushNamed(context, '/qrScanner'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _takenAskis.length,
      itemBuilder: (context, index) {
        final aski = _takenAskis[index];
        return _buildAskiCard(aski, isReceived: true);
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
            Icon(icon, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            if (buttonText != null && onPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
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
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                  color: _getStatusColor(aski.status).withValues(alpha: 0.1),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isReceived)
                      Text(
                        'Bağışçı: ${aski.donorUserName}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(aski.createdAt),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                aski.message!,
                style: TextStyle(
                  color: Colors.grey.shade700,
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
        ? Colors.blue
        : Colors.green;
  }

  String _getUserTypeText() {
    return _currentUser?.userType == UserType.corporate
        ? 'Kurumsal Kullanıcı'
        : 'Bireysel Kullanıcı';
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
