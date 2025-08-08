import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/aski_service.dart';
import '../services/product_service.dart';
import '../services/user_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final PageController _pageController = PageController();
  final AskiService _askiService = AskiService();
  final ProductService _productService = ProductService();
  final UserService _userService = UserService();

  int _currentStep = 0;
  bool _isLoading = false;

  // Seçim verileri
  UserModel? _selectedCorporate;
  String? _selectedCategory;
  ProductModel? _selectedProduct;

  // Askı detayları
  final _messageController = TextEditingController();

  // Veri listeleri
  List<UserModel> _corporates = [];
  List<String> _categories = [];
  List<ProductModel> _products = [];

  @override
  void initState() {
    super.initState();
    _loadCorporates();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCorporates() async {
    try {
      setState(() => _isLoading = true);
      // Tüm kullanıcıları yükleyip kurumsal olanları filtrele
      final allUsers = await _userService.getAllUsers();
      final corporates =
          allUsers
              .where(
                (user) =>
                    user.userType == UserType.corporate && user.isApproved,
              )
              .toList();
      setState(() {
        _corporates = corporates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Kurumlar yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _loadCategories() async {
    if (_selectedCorporate == null) return;

    try {
      setState(() => _isLoading = true);

      // Stream'i dinlemek için
      final productStream = _productService.getProductsByCorporate(
        _selectedCorporate!.uid,
      );
      productStream.listen((products) {
        final categories = products.map((p) => p.category).toSet().toList();
        if (mounted) {
          setState(() {
            _categories = categories;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Kategoriler yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _loadProducts() async {
    if (_selectedCorporate == null || _selectedCategory == null) return;

    try {
      setState(() => _isLoading = true);

      final productStream = _productService.getProductsByCorporate(
        _selectedCorporate!.uid,
      );
      productStream.listen((allProducts) {
        final filteredProducts =
            allProducts.where((p) => p.category == _selectedCategory).toList();
        if (mounted) {
          setState(() {
            _products = filteredProducts;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ürünler yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _createAski() async {
    if (_selectedProduct == null) return;

    try {
      setState(() => _isLoading = true);

      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) throw Exception('Kullanıcı bulunamadı');

      final askiId = await _askiService.createAski(
        _selectedProduct!,
        _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
      );

      setState(() => _isLoading = false);

      if (askiId != null && mounted) {
        // Başarı mesajı göster ve ana sayfaya dön
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Askı başarıyla oluşturuldu!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Ana sayfaya dön
        Navigator.pop(context, true);
      } else {
        _showError('Askı oluşturulurken hata oluştu');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Askı oluşturulurken hata oluştu: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      // Veri yükleme
      if (_currentStep == 1) _loadCategories();
      if (_currentStep == 2) _loadProducts();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Askı Oluştur'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildCorporateSelection(),
                _buildCategorySelection(),
                _buildProductSelection(),
                _buildAskiDetails(),
              ],
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            _buildStepCircle(i),
            if (i < 3) _buildStepLine(i),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step) {
    final isActive = step <= _currentStep;
    final isCompleted = step < _currentStep;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color:
            isActive
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child:
            isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                  '${step + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = step < _currentStep;

    return Expanded(
      child: Container(
        height: 3,
        color:
            isCompleted
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildCorporateSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kurum Seçin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Askınızı hangi kuruma bağışlamak istiyorsunuz?',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _corporates.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz onaylanmış kurum yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _corporates.length,
                      itemBuilder: (context, index) {
                        final corporate = _corporates[index];
                        final isSelected =
                            _selectedCorporate?.uid == corporate.uid;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCorporate = corporate;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.1)
                                        : Colors.white,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Center(
                                      child: Text(
                                        corporate.companyName?.isNotEmpty ==
                                                true
                                            ? corporate.companyName![0]
                                                .toUpperCase()
                                            : corporate.fullName[0]
                                                .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          corporate.companyName ??
                                              corporate.fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          corporate.email,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Seçin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hangi kategoriden ürün bağışlamak istiyorsunuz?',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _categories.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu kurumda henüz ürün yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.1)
                                      : Colors.white,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 40,
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Colors.grey.shade600,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _getCategoryName(category),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        isSelected
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ürün Seçin',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hangi ürünü askıya asmak istiyorsunuz?',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _products.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu kategoride ürün yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final isSelected = _selectedProduct?.id == product.id;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProduct = product;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.1)
                                        : Colors.white,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.inventory,
                                      color: Colors.blue.shade600,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (product.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            product.description,
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAskiDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Askı Detayları',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Son olarak askınız için bir mesaj ekleyin.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          // Seçilen bilgilerin özeti
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
                const Text(
                  'Askı Özeti',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildSummaryRow(
                  'Kurum',
                  _selectedCorporate?.companyName ??
                      _selectedCorporate?.fullName ??
                      '',
                ),
                _buildSummaryRow(
                  'Kategori',
                  _getCategoryName(_selectedCategory),
                ),
                _buildSummaryRow('Ürün', _selectedProduct?.name ?? ''),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Mesaj alanı
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Mesajınız (İsteğe bağlı)',
              hintText: 'Bu askı hakkında bir mesaj yazabilirsiniz...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Geri'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _getNextButtonAction(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback? _getNextButtonAction() {
    switch (_currentStep) {
      case 0:
        return _selectedCorporate != null ? _nextStep : null;
      case 1:
        return _selectedCategory != null ? _nextStep : null;
      case 2:
        return _selectedProduct != null ? _nextStep : null;
      case 3:
        return _createAski;
      default:
        return null;
    }
  }

  String _getNextButtonText() {
    switch (_currentStep) {
      case 0:
      case 1:
      case 2:
        return 'Devam Et';
      case 3:
        return 'Askı Oluştur';
      default:
        return 'Devam Et';
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'gıda':
      case 'food':
        return Icons.restaurant;
      case 'giyim':
      case 'clothing':
        return Icons.checkroom;
      case 'kitap':
      case 'books':
        return Icons.book;
      case 'oyuncak':
      case 'toys':
        return Icons.toys;
      case 'elektronik':
      case 'electronics':
        return Icons.phone_android;
      case 'ev eşyası':
      case 'household':
        return Icons.home;
      case 'temizlik':
      case 'cleaning':
        return Icons.cleaning_services;
      case 'kişisel bakım':
      case 'personal care':
        return Icons.face;
      default:
        return Icons.category;
    }
  }

  String _getCategoryName(String? category) {
    return category ?? 'Diğer';
  }
}
