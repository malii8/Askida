import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/aski_model.dart';
import '../models/product_model.dart';
import '../services/user_service.dart';

class AskiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Askı oluşturma
  Future<String?> createAski(ProductModel product, String? message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final userModel = await _userService.getCurrentUser();
      if (userModel == null) return null;

      // Unique askı ID'si oluştur
      final askiId = _firestore.collection('askis').doc().id;

      // QR kod verisi oluştur
      final qrData = {
        'type': 'askida_product',
        'askiId': askiId,
        'productId': product.id,
        'productName': product.name,
        'corporateId': product.corporateId,
        'corporateName': product.corporateName,
        'donorUserId': userModel.uid,
        'donorName': userModel.fullName,
        'askiDate': DateTime.now().toIso8601String(),
      };

      final askiModel = AskiModel(
        id: askiId,
        productId: product.id,
        productName: product.name,
        corporateId: product.corporateId,
        corporateName: product.corporateName,
        donorUserId: userModel.uid,
        donorUserName: userModel.fullName,
        message: message,
        createdAt: DateTime.now(),
        status: AskiStatus.active,
        qrCode: jsonEncode(qrData),
      );

      await _firestore.collection('askis').doc(askiId).set(askiModel.toJson());
      developer.log('Askı başarıyla oluşturuldu: $askiId', name: 'AskiService');
      return askiId;
    } catch (e) {
      developer.log('Askı oluşturma hatası: $e', name: 'AskiService');
      return null;
    }
  }

  // Askıyı alma (Bireysel kullanıcılar için)
  Future<bool> takeAski({
    required String askiId,
    required String takenByUserId,
    required String takenByUserName,
  }) async {
    try {
      // Askıyı al ve kontrol et
      final askiDoc = await _firestore.collection('askis').doc(askiId).get();
      if (!askiDoc.exists) return false;

      final askiModel = AskiModel.fromJson(askiDoc.data()!);

      // Zaten alınmış mı kontrol et
      if (askiModel.status != AskiStatus.active) return false;

      // Kendi askısını alamaz
      if (askiModel.donorUserId == takenByUserId) return false;

      // Askıyı güncelle
      final updatedAski = askiModel.copyWith(
        status: AskiStatus.taken,
        takenByUserId: takenByUserId,
        takenByUserName: takenByUserName,
        takenAt: DateTime.now(),
      );

      await _firestore
          .collection('askis')
          .doc(askiId)
          .update(updatedAski.toJson());
      return true;
    } catch (e) {
      developer.log('Askı alma hatası: $e', name: 'AskiService');
      return false;
    }
  }

  // Kullanıcının askılarını getirme
  Stream<List<AskiModel>> getUserAskis(String userId) {
    developer.log(
      'getUserAskis çağrıldı, userId: $userId',
      name: 'AskiService',
    );
    return _firestore
        .collection('askis')
        .where('donorUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final askis =
              snapshot.docs.map((doc) {
                return AskiModel.fromJson(doc.data());
              }).toList();
          developer.log(
            'getUserAskis sonuç: ${askis.length} askı bulundu',
            name: 'AskiService',
          );
          return askis;
        });
  }

  // Aktif askıları getirme
  Stream<List<AskiModel>> getActiveAskis() {
    return _firestore
        .collection('askis')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AskiModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Kurumsal kullanıcının askılarını getirme
  Stream<List<AskiModel>> getCorporateAskis(String corporateId) {
    return _firestore
        .collection('askis')
        .where('corporateId', isEqualTo: corporateId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AskiModel.fromJson(doc.data());
          }).toList();
        });
  }

  // Askı detayını getirme
  Future<AskiModel?> getAski(String askiId) async {
    try {
      final doc = await _firestore.collection('askis').doc(askiId).get();
      if (doc.exists) {
        return AskiModel.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      developer.log('Askı getirme hatası: $e', name: 'AskiService');
      return null;
    }
  }

  // QR kodundan askı bilgisi alma
  Future<AskiModel?> getAskiFromQR(String qrData) async {
    try {
      final data = jsonDecode(qrData);
      if (data['type'] == 'askida_product' && data['askiId'] != null) {
        return await getAski(data['askiId']);
      }
      return null;
    } catch (e) {
      developer.log('QR kod çözümleme hatası: $e', name: 'AskiService');
      return null;
    }
  }

  // Askıyı iptal etme
  Future<bool> cancelAski(String askiId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Askıyı al ve kontrol et
      final askiDoc = await _firestore.collection('askis').doc(askiId).get();
      if (!askiDoc.exists) return false;

      final askiModel = AskiModel.fromJson(askiDoc.data()!);

      // Sadece askı sahibi iptal edebilir
      if (askiModel.donorUserId != currentUser.uid) return false;

      // Sadece aktif askılar iptal edilebilir
      if (askiModel.status != AskiStatus.active) return false;

      await _firestore.collection('askis').doc(askiId).update({
        'status': AskiStatus.cancelled.name,
      });

      return true;
    } catch (e) {
      developer.log('Askı iptal etme hatası: $e', name: 'AskiService');
      return false;
    }
  }

  // Kategoriye göre askıları getirme
  Stream<List<AskiModel>> getAskisByCategory(String category) {
    return _firestore
        .collection('askis')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<AskiModel> filteredAskis = [];

          for (var doc in snapshot.docs) {
            final aski = AskiModel.fromJson(doc.data());

            // Ürün bilgisini al ve kategorisini kontrol et
            final productDoc =
                await _firestore
                    .collection('products')
                    .doc(aski.productId)
                    .get();
            if (productDoc.exists) {
              final productData = productDoc.data()!;
              if (productData['category'] == category) {
                filteredAskis.add(aski);
              }
            }
          }

          return filteredAskis;
        });
  }

  // Askı istatistikleri
  Future<Map<String, int>> getAskiStats(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('askis')
              .where('donorUserId', isEqualTo: userId)
              .get();

      int total = querySnapshot.docs.length;
      int active = 0;
      int taken = 0;
      int cancelled = 0;

      for (var doc in querySnapshot.docs) {
        final status = doc.data()['status'];
        switch (status) {
          case 'active':
            active++;
            break;
          case 'taken':
            taken++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      return {
        'total': total,
        'active': active,
        'taken': taken,
        'cancelled': cancelled,
      };
    } catch (e) {
      developer.log('İstatistik alma hatası: $e', name: 'AskiService');
      return {'total': 0, 'active': 0, 'taken': 0, 'cancelled': 0};
    }
  }

  // Askıyı tamamla (ürün teslim edildi)
  Future<void> completeAski(String askiId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Kullanıcı girişi yapılmamış');

      final userModel = await _userService.getCurrentUser();
      if (userModel == null) throw Exception('Kullanıcı bilgisi bulunamadı');

      await _firestore.collection('askis').doc(askiId).update({
        'status': AskiStatus.taken.name,
        'takenByUserId': userModel.uid,
        'takenByUserName': userModel.fullName,
        'takenAt': DateTime.now().millisecondsSinceEpoch,
      });

      developer.log('Askı tamamlandı: $askiId', name: 'AskiService');
    } catch (e) {
      developer.log('Askı tamamlama hatası: $e', name: 'AskiService');
      rethrow;
    }
  }
}
