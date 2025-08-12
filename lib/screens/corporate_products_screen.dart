import 'package:flutter/material.dart';
import 'dart:developer' as developer;
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
            return Center(
              child: Text(
                'Hata: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
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
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withAlpha((255 * 0.4).round()),
          ),
          const SizedBox(height: 24),
          Text(
            'Henüz ürün eklenmemiş',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Bireysel kullanıcıların askıya bırakabileceği\nürünlerinizi buraya ekleyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showProductDialog(),
            icon: Icon(
              Icons.add,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            label: Text(
              'İlk Ürünü Ekle',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
          color: Theme.of(context).colorScheme.surface,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(
                _getCategoryIcon(product.category),
                color: Theme.of(context).colorScheme.onPrimary,
                size: 20,
              ),
            ),
            title: Text(
              product.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                      fontSize: 14,
                    ),
                  ),
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(
                          Icons.edit,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        title: Text(
                          'Düzenle',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Sil',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
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
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
              ),
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
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  title: Row(
                    children: [
                      Icon(
                        Icons.inventory,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
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
                            color: Theme.of(context).colorScheme.primary
                                .withAlpha((255 * 0.1).round()),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary
                                  .withAlpha((255 * 0.3).round()),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mağazanıza yeni ürün ekleyin',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Ürün Adı
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Ürün Adı *',
                            hintText: 'Ürün adını girin',
                            prefixIcon: Icon(
                              Icons.inventory,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.6).round()),
                            ),
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.5).round()),
                            ),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Kategori
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Kategori *',
                            prefixIcon: Icon(
                              Icons.category,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.6).round()),
                            ),
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
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
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        category,
                                        style: TextStyle(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedCategory = value!;
                            });
                          },
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Fiyat
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Fiyat (₺) *',
                            hintText: '250',
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.6).round()),
                            ),
                            prefixText: '₺ ',
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.5).round()),
                            ),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Açıklama
                        TextField(
                          controller: descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Açıklama *',
                            hintText: 'Ürün hakkında detaylar...',
                            prefixIcon: Icon(
                              Icons.description,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.6).round()),
                            ),
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.5).round()),
                            ),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resim URL
                        TextField(
                          controller: imageUrlController,
                          decoration: InputDecoration(
                            labelText: 'Ürün Resmi URL (Opsiyonel)',
                            hintText: 'https://example.com/image.jpg',
                            prefixIcon: Icon(
                              Icons.image,
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.6).round()),
                            ),
                            border: const OutlineInputBorder(),
                            labelStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.7).round()),
                            ),
                            hintStyle: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface
                                  .withAlpha((255 * 0.5).round()),
                            ),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bilgi metinleri
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bilgi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '• Eklediğiniz ürünler mağaza sayfasında görünecek',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.8).round()),
                                ),
                              ),
                              Text(
                                '• Kullanıcılar bu ürünleri askıya alabilecek',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.8).round()),
                                ),
                              ),
                              Text(
                                '• Fiyat sadece referans amaçlıdır',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.8).round()),
                                ),
                              ),
                              Text(
                                '• Ürünleri sonradan düzenleyebilirsiniz',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withAlpha((255 * 0.8).round()),
                                ),
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
                      child: Text(
                        'İptal',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final currentContext = context; // Capture context
                        final navigator = Navigator.of(currentContext);
                        final messenger = ScaffoldMessenger.of(currentContext);
                        final colorScheme =
                            Theme.of(
                              currentContext,
                            ).colorScheme; // Define colorScheme here
                        bool success = false;

                        if (nameController.text.trim().isNotEmpty &&
                            priceController.text.trim().isNotEmpty &&
                            descriptionController.text.trim().isNotEmpty) {
                          final price = double.tryParse(
                            priceController.text.trim(),
                          );
                          if (price == null) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Lütfen geçerli bir fiyat girin',
                                ),
                                backgroundColor: colorScheme.error,
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

                          // Log the corporateId before creating the product
                          developer.log(
                            'ProductModel Corporate ID: ${productModel.corporateId}',
                            name: 'CorporateProductsScreen',
                          );

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
                                      Icon(
                                        Icons.check_circle,
                                        color: colorScheme.onPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        product == null
                                            ? 'Ürün başarıyla eklendi!'
                                            : 'Ürün başarıyla güncellendi!',
                                        style: TextStyle(
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: colorScheme.tertiary,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.error,
                                        color: colorScheme.onError,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Bir hata oluştu!',
                                        style: TextStyle(
                                          color: colorScheme.onError,
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        } else {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Lütfen gerekli alanları doldurun',
                              ),
                              backgroundColor: colorScheme.secondary,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.save,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product == null ? 'Ürünü Kaydet' : 'Güncelle',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
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
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Ürünü Sil',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Bu ürünü silmek istediğinizden emin misiniz?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'İptal',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final currentContext = context; // Capture context
                  final navigator = Navigator.of(currentContext);
                  final messenger = ScaffoldMessenger.of(currentContext);
                  final colorScheme =
                      Theme.of(
                        currentContext,
                      ).colorScheme; // Define colorScheme here

                  final success = await _productService.deleteProduct(
                    productId,
                  );
                  if (!mounted) return;

                  navigator.pop();

                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Ürün başarıyla silindi!'),
                        backgroundColor: colorScheme.tertiary,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Silme işlemi başarısız!'),
                        backgroundColor: colorScheme.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text(
                  'Sil',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                  ),
                ),
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
