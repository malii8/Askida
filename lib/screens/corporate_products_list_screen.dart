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
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
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
                decoration: InputDecoration(
                  labelText: 'Kurum Seçin',
                  labelStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'Tüm Kurumlar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  ...corporates.map((corporate) {
                    return DropdownMenuItem<String>(
                      value: corporate['id'],
                      child: Text(
                        corporate['name']!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCorporateId = value;
                  });
                },
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Kategori seçimi
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Kategori',
              labelStyle: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: [
              DropdownMenuItem<String>(
                value: 'Tümü',
                child: Text(
                  'Tüm Kategoriler',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ..._productService.getCategories().map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(
                    category,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategory = value ?? 'Tümü';
              });
            },
            dropdownColor: Theme.of(context).colorScheme.surface,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                Icon(
                  Icons.error,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Hata: ${snapshot.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.3).round()),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ürün bulunamadı',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Seçili kriterlere uygun ürün bulunmuyor',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                  ),
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
      color: Theme.of(context).colorScheme.surface,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        product.corporateName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.6).round()),
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
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  fontSize: 14,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Askıya bırak butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateAskiDialog(product),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                label: Text(
                  'Askıya Bırak',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            title: Text(
              '${product.name} - Askıya Bırak',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurum: ${product.corporateName}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Kategori: ${product.category}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Mesaj (Opsiyonel)',
                    hintText: 'Bu ürünü neden askıya bırakıyorsunuz?',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.5).round()),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha((255 * 0.3).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Askıya bıraktığınız ürün için size bir QR kod oluşturulacak. Bu QR kodu firmaya göstererek ürünü alabilirsiniz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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

                  // Capture ColorScheme before async operation
                  final colorScheme = Theme.of(currentContext).colorScheme;

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
                        content: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Askı başarıyla oluşturuldu!',
                              style: TextStyle(color: colorScheme.onPrimary),
                            ),
                          ],
                        ),
                        backgroundColor: colorScheme.tertiary,
                        action: SnackBarAction(
                          label: 'QR Göster',
                          textColor: colorScheme.onPrimary,
                          onPressed: () {
                            _showQRCode(askiId);
                          },
                        ),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Askı oluşturulamadı!',
                          style: TextStyle(color: colorScheme.onError),
                        ),
                        backgroundColor: colorScheme.error,
                      ),
                    );
                  }
                },
                child: Text(
                  'Askıya Bırak',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
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
            title: Text(
              'QR Kod',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: SizedBox(
              width: 200,
              height: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.qr_code,
                      size: 100,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Askı ID: $askiId',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu QR kodu askıdan almak için kullanın.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Kapat',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'QR Kod',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 200,
                  height: 200,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Center(
                    child: Text(
                      'QR Kod\nBurada olacak',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bu QR kodu firmaya göstererek ürününüzü alabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Tamam',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
