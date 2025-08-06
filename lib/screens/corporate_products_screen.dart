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
            onPressed: _showAddProductDialog,
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
            onPressed: _showAddProductDialog,
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
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                product.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(product.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kategori: ${product.category}'),
                if (product.description.isNotEmpty)
                  Text(
                    product.description,
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
                  _showEditProductDialog(product);
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

  void _showAddProductDialog() {
    _showProductDialog();
  }

  void _showEditProductDialog(ProductModel product) {
    _showProductDialog(product: product);
  }

  void _showProductDialog({ProductModel? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final descriptionController = TextEditingController(
      text: product?.description ?? '',
    );
    final categories = _productService.getCategories();
    String selectedCategory = product?.category ?? categories.first;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    product == null ? 'Yeni Ürün Ekle' : 'Ürünü Düzenle',
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ürün Adı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            categories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Açıklama (Opsiyonel)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('İptal'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty) {
                          final productModel = ProductModel(
                            id:
                                product?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            name: nameController.text.trim(),
                            category: selectedCategory,
                            description: descriptionController.text.trim(),
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
                                  content: Text(
                                    product == null
                                        ? 'Ürün başarıyla eklendi!'
                                        : 'Ürün başarıyla güncellendi!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Bir hata oluştu!'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: Text(product == null ? 'Ekle' : 'Güncelle'),
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
}



