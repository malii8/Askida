import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/product_service.dart';
import '../models/user_model.dart';
import '../models/product_model.dart';

class CorporateProductsScreen extends StatefulWidget {
  final String? corporateId;

  const CorporateProductsScreen({super.key, this.corporateId});

  @override
  State<CorporateProductsScreen> createState() =>
      _CorporateProductsScreenState();
}

class _CorporateProductsScreenState extends State<CorporateProductsScreen> {
  final UserService _userService = UserService();
  final ProductService _productService = ProductService();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Yönetimi'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Ürün Ekle',
          ),
        ],
      ),
      body: StreamBuilder<List<ProductModel>>(
        stream: _productService.getCorporateProducts(_userModel?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return _buildEmptyState();
          }

          return _buildProductList(products);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 120,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz ürün eklenmemiş',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Text(
            'Bireysel kullanıcıların askıya bırakabileceği\nürünlerinizi buraya ekleyin',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('İlk Ürünü Ekle'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<ProductModel> products) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                _getCategoryIcon(product.category),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.category,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
                if (product.price != null)
                  Text(
                    '₺ ${product.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                      fontSize: 14,
                    ),
                  ),
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Düzenle'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Sil', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showProductDialog(product: product);
                } else if (value == 'delete') {
                  _deleteProduct(product.id);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showProductDialog({ProductModel? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    final priceController = TextEditingController(
      text: product?.price?.toString() ?? '',
    );
    final imageUrlController = TextEditingController(
      text: product?.imageUrl ?? '',
    );
    final categories = _productService.getCategories();
    String selectedCategory = product?.category ?? categories.first;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        Icons.inventory,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bilgi kartı
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Mağazanıza yeni ürün ekleyin',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ürün Adı
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ürün Adı *',
                            hintText: 'Ürün adını girin',
                            prefixIcon: Icon(Icons.inventory),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kategori
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          items:
                              categories.map((category) {
                                return DropdownMenuItem(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getCategoryIcon(category),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(category),
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Fiyat
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fiyat (₺) *',
                            hintText: '250',
                            prefixIcon: Icon(Icons.attach_money),
                            prefixText: '₺ ',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Açıklama
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Açıklama *',
                            hintText: 'Ürün hakkında detaylar...',
                            prefixIcon: Icon(Icons.description),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resim URL
                        TextField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Ürün Resmi URL (Opsiyonel)',
                            hintText: 'https://example.com/image.jpg',
                            prefixIcon: Icon(Icons.image),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bilgi metinleri
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Bilgi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                '• Eklediğiniz ürünler mağaza sayfasında görünecek',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '• Kullanıcılar bu ürünleri askıya alabilecek',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '• Fiyat sadece referans amaçlıdır',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '• Ürünleri sonradan düzenleyebilirsiniz',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty &&
                            priceController.text.trim().isNotEmpty &&
                            descriptionController.text.trim().isNotEmpty) {
                          final price = double.tryParse(
                            priceController.text.trim(),
                          );
                          if (price == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Lütfen geçerli bir fiyat girin'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          final productModel = ProductModel(
                            id:
                                product?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            name: nameController.text.trim(),
                            category: selectedCategory,
                            description: descriptionController.text.trim(),
                            price: price,
                            imageUrl:
                                imageUrlController.text.trim().isNotEmpty
                                    ? imageUrlController.text.trim()
                                    : null,
                            corporateId: _userModel?.uid ?? '',
                            corporateName:
                                _userModel?.organizationName ??
                                _userModel?.fullName ??
                                '',
                            createdAt: product?.createdAt ?? DateTime.now(),
                          );

                          // BuildContext'i async işlemden önce al
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          bool success;
                          if (product == null) {
                            success = await _productService.addProduct(
                              productModel,
                            );
                          } else {
                            success = await _productService.updateProduct(
                              productModel,
                            );
                          }

                          if (mounted) {
                            if (success) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        product == null
                                            ? 'Ürün başarıyla eklendi!'
                                            : 'Ürün başarıyla güncellendi!',
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Bir hata oluştu!'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen gerekli alanları doldurun'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.save, size: 18),
                          const SizedBox(width: 4),
                          Text(product == null ? 'Ürünü Kaydet' : 'Güncelle'),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  void _deleteProduct(String productId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ürünü Sil'),
            content: const Text('Bu ürünü silmek istediğinizden emin misiniz?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // BuildContext'i async işlemden önce al
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final success = await _productService.deleteProduct(
                    productId,
                  );
                  if (!mounted) return;

                  navigator.pop();

                  if (success) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Ürün başarıyla silindi!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Silme işlemi başarısız!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Gıda':
        return Icons.restaurant;
      case 'Kişisel Bakım':
        return Icons.face;
      case 'Temizlik':
        return Icons.cleaning_services;
      case 'Ev':
        return Icons.home;
      case 'Diğer':
        return Icons.category;
      default:
        return Icons.inventory;
    }
  }
}
