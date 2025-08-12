import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ürün ekleme
  Future<bool> addProduct(ProductModel product) async {
    try {
      await _firestore
          .collection('products')
          .doc(product.id)
          .set(product.toJson());
      return true;
    } catch (e) {
      developer.log('Ürün ekleme hatası: $e', name: 'ProductService');
      return false;
    }
  }

  // Ürün güncelleme
  Future<bool> updateProduct(ProductModel product) async {
    try {
      final updatedProduct = product.copyWith(updatedAt: DateTime.now());
      await _firestore
          .collection('products')
          .doc(product.id)
          .update(updatedProduct.toJson());
      return true;
    } catch (e) {
      developer.log('Ürün güncelleme hatası: $e', name: 'ProductService');
      return false;
    }
  }

  // Ürün silme (soft delete)
  Future<bool> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      developer.log('Ürün silme hatası: $e', name: 'ProductService');
      return false;
    }
  }

  // Kurumsal kullanıcının ürünlerini getirme
  Stream<List<ProductModel>> getCorporateProducts(String corporateId) {
    return _firestore
        .collection('products')
        .where('corporateId', isEqualTo: corporateId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Tüm aktif ürünleri getirme (bireysel kullanıcılar için)
  Stream<List<ProductModel>> getAllActiveProducts() {
    return _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Kategoriye göre ürünleri getirme
  Stream<List<ProductModel>> getProductsByCategory(String category) {
    return _firestore
        .collection('products')
        .where('category', isEqualTo: category)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Kuruma göre ürünleri getirme
  Stream<List<ProductModel>> getProductsByCorporate(String corporateId) {
    return _firestore
        .collection('products')
        .where('corporateId', isEqualTo: corporateId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ProductModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Ürün arama
  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final results =
          await _firestore
              .collection('products')
              .where('isActive', isEqualTo: true)
              .get();

      return results.docs.map((doc) => ProductModel.fromJson(doc.data())).where(
        (product) {
          return product.name.toLowerCase().contains(query.toLowerCase()) ||
              product.category.toLowerCase().contains(query.toLowerCase()) ||
              product.corporateName.toLowerCase().contains(query.toLowerCase());
        },
      ).toList();
    } catch (e) {
      developer.log('Ürün arama hatası: $e', name: 'ProductService');
      return [];
    }
  }

  // Tek ürün getirme
  Future<ProductModel?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (doc.exists) {
        return ProductModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      developer.log('Ürün getirme hatası: $e', name: 'ProductService');
      return null;
    }
  }

  // Kategorileri getirme (statik liste)
  List<String> getCategories() {
    return [
      'Gıda',
      'İçecek',
      'Kırtasiye',
      'Kozmetik',
      'Tekstil',
      'Elektronik',
      'Kitap',
      'Oyuncak',
      'Ev Eşyası',
      'Spor',
      'Sağlık',
      'Diğer',
    ];
  }

  // Kurumların listesi (dropkdown için)
  Stream<List<Map<String, String>>> getCorporateList() {
    return _firestore
        .collection('users')
        .where('userType', isEqualTo: 'corporate')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, String>{
              'id': data['uid']?.toString() ?? '',
              'name':
                  data['organizationName']?.toString() ??
                  data['fullName']?.toString() ??
                  '',
            };
          }).toList();
        });
  }

  // Tüm benzersiz ürün kategorilerini getirme
  Future<List<String>> getAllCategories() async {
    try {
      final querySnapshot = await _firestore.collection('products').get();
      final categories = <String>{};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('category') && data['category'] is String) {
          categories.add(data['category'] as String);
        }
      }
      return [
        'Tümü',
        ...categories.toList()..sort(),
      ]; // 'Tümü' seçeneğini ekle ve sırala
    } catch (e) {
      throw Exception('Kategoriler alınırken hata oluştu: $e');
    }
  }
}
