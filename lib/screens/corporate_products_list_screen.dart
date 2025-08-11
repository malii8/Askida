import 'package:flutter/material.dart';
import '../services/product_service.dart';
import '../services/aski_service.dart';
import '../models/product_model.dart';
import 'package:askida/models/aski_model.dart'; // PostType için eklendi

class CorporateProductsListScreen extends StatefulWidget {
  const CorporateProductsListScreen({super.key});

  @override
  State<CorporateProductsListScreen> createState() =>
      _CorporateProductsListScreenState();
}

class _CorporateProductsListScreenState
    extends State<CorporateProductsListScreen> {
  final ProductService _productService = ProductService();
  final AskiService _askiService = AskiService();
  String? _selectedCorporateId;
  String _selectedCategory = 'Tümü';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurumsal Ürünler'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtreler
          _buildFilters(),

          // Ürün listesi
          Expanded(child: _buildProductsList()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Kurum seçimi
          StreamBuilder<List<Map<String, String>>>(
            stream: _productService.getCorporateList(),
            builder: (context, snapshot) {
              final corporates = snapshot.data ?? [];

              return DropdownButtonFormField<String>(
                value: _selectedCorporateId,
                decoration: const InputDecoration(
                  labelText: 'Kurum Seçin',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Tüm Kurumlar'),
                  ),
                  ...corporates.map((corporate) {
                    return DropdownMenuItem<String>(
                      value: corporate['id'],
                      child: Text(corporate['name']!),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCorporateId = value;
                  });
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // Kategori seçimi
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: 'Tümü',
                child: Text('Tüm Kategoriler'),
              ),
              ..._productService.getCategories().map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value ?? 'Tümü';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return StreamBuilder<List<ProductModel>>(
      stream:
          _selectedCorporateId != null
              ? _productService.getProductsByCorporate(_selectedCorporateId!)
              : _productService.getAllActiveProducts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Hata: ${snapshot.error}'),
              ],
            ),
          );
        }

        List<ProductModel> products = snapshot.data ?? [];

        // Kategori filtresi uygula
        if (_selectedCategory != 'Tümü') {
          products =
              products
                  .where((product) => product.category == _selectedCategory)
                  .toList();
        }

        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Ürün bulunamadı',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Seçili kriterlere uygun ürün bulunmuyor',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        product.corporateName,
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
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    product.category,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            if (product.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                product.description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ],

            const SizedBox(height: 16),

            // Askıya bırak butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateAskiDialog(product),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Askıya Bırak'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAskiDialog(ProductModel product) {
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${product.name} - Askıya Bırak'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kurum: ${product.corporateName}'),
                Text('Kategori: ${product.category}'),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mesaj (Opsiyonel)',
                    hintText: 'Bu ürünü neden askıya bırakıyorsunuz?',
                    border: OutlineInputBorder(),
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
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Askıya bıraktığınız ürün için size bir QR kod oluşturulacak. Bu QR kodu firmaya göstererek ürünü alabilirsiniz.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
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
                  // BuildContext'i async işlemden önce al
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final askiId = await _askiService.createAski(
                    product,
                    messageController.text.trim().isEmpty
                        ? null
                        : messageController.text.trim(),
                    PostType.firstComeFirstServe, // PostType eklendi
                  );

                  if (!mounted) return;

                  navigator.pop();

                  if (askiId != null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Askı başarıyla oluşturuldu!'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        action: SnackBarAction(
                          label: 'QR Göster',
                          textColor: Colors.white,
                          onPressed: () {
                            _showQRCode(askiId);
                          },
                        ),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Askı oluşturulamadı!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Askıya Bırak'),
              ),
            ],
          ),
    );
  }

  void _showQRCode(String askiId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Kod'),
            content: SizedBox(
              width: 200,
              height: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Askı ID: $askiId',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu QR kodu askıdan almak için kullanın.',
                    style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Kod'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  color: Colors.grey.shade200,
                  child: const Center(child: Text('QR Kod\nBurada olacak')),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bu QR kodu firmaya göstererek ürününüzü alabilirsiniz.',
                  textAlign: TextAlign.center,
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
          ),
    );
  }
}
