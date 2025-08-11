import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import '../models/aski_model.dart';
import '../models/product_model.dart';
import '../models/application_model.dart'; // ApplicationModel eklendi
import '../models/notification_model.dart'; // NotificationModel ve NotificationType eklendi
import '../services/user_service.dart';
import '../services/notification_service.dart'; // NotificationService eklendi
import 'dart:math'; // Random sınıfı için eklendi

class AskiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  final NotificationService _notificationService =
      NotificationService(); // NotificationService örneği

  // Askı oluşturma
  Future<String?> createAski(
    ProductModel product,
    String? message,
    PostType postType,
  ) async {
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
        category: product.category, // Kategori eklendi
        postType: postType, // PostType eklendi
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
    // Query for askis where the user is the donor
    final donorAskisStream =
        _firestore
            .collection('askis')
            .where('donorUserId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots();

    // Query for askis where the user has taken the aski
    final takenAskisStream =
        _firestore
            .collection('askis')
            .where('takenByUserId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots();

    // Combine the two streams
    return Rx.combineLatest2(donorAskisStream, takenAskisStream, (
      QuerySnapshot donorSnapshot,
      QuerySnapshot takenSnapshot,
    ) {
      final Set<AskiModel> combinedAskis = {};

      for (var doc in donorSnapshot.docs) {
        combinedAskis.add(
          AskiModel.fromJson(doc.data() as Map<String, dynamic>),
        );
      }
      for (var doc in takenSnapshot.docs) {
        combinedAskis.add(
          AskiModel.fromJson(doc.data() as Map<String, dynamic>),
        );
      }

      final askis = combinedAskis.toList();
      askis.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      ); // Sort by createdAt descending

      developer.log(
        'getUserAskis sonuç: ${askis.length} askı bulundu',
        name: 'AskiService',
      );
      return askis;
    });
  }

  // Aktif askıları getirme
  Stream<List<AskiModel>> getFilteredAskis({
    String? category,
    AskiStatus? status,
    String? takenByUserId,
    String? corporateId, // Yeni eklendi
  }) {
    Query query = _firestore
        .collection('askis')
        .orderBy('createdAt', descending: true);

    if (corporateId != null) {
      query = query.where('corporateId', isEqualTo: corporateId);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    } else {
      // Varsayılan olarak aktif askıları göster
      query = query.where('status', isEqualTo: AskiStatus.active.name);
    }

    if (category != null && category != 'Tümü') {
      query = query.where('category', isEqualTo: category);
    }

    if (takenByUserId != null && status == AskiStatus.taken) {
      query = query.where('takenByUserId', isEqualTo: takenByUserId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AskiModel.fromJson(doc.data() as Map<String, dynamic>);
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

  // Belirli bir askıyı stream olarak dinleme
  Stream<AskiModel?> getAskiStream(String askiId) {
    return _firestore.collection('askis').doc(askiId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists && snapshot.data() != null) {
        return AskiModel.fromJson(snapshot.data()!);
      }
      return null;
    });
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

  // Rastgele seçim askısına başvuru yapma
  Future<bool> applyToAski(String askiId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userModel = await _userService.getCurrentUser();
      if (userModel == null) return false;

      // Zaten başvurmuş mu kontrol et
      final existingApplication =
          await _firestore
              .collection('askis')
              .doc(askiId)
              .collection('applications')
              .where('applicantUserId', isEqualTo: currentUser.uid)
              .get();

      if (existingApplication.docs.isNotEmpty) {
        developer.log(
          'Kullanıcı zaten bu askıya başvurmuş.',
          name: 'AskiService',
        );
        return false; // Zaten başvurmuş
      }

      final application = ApplicationModel(
        id: '',
        askiId: askiId,
        applicantUserId: currentUser.uid,
        applicantUserName: userModel.fullName,
        appliedAt: DateTime.now(),
        status: ApplicationStatus.pending,
      );

      await _firestore
          .collection('askis')
          .doc(askiId)
          .collection('applications')
          .add(application.toJson());

      developer.log(
        'Askıya başarıyla başvuruldu: $askiId',
        name: 'AskiService',
      );
      return true;
    } catch (e) {
      developer.log('Askıya başvuru hatası: $e', name: 'AskiService');
      return false;
    }
  }

  // Bir askıya yapılan başvuruları getirme
  Stream<List<ApplicationModel>> getApplicationsForAski(String askiId) {
    return _firestore
        .collection('askis')
        .doc(askiId)
        .collection('applications')
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ApplicationModel.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Rastgele seçim askısı için kazananı seçme
  Future<ApplicationModel?> selectRandomApplicant(String askiId) async {
    try {
      final applicationsSnapshot =
          await _firestore
              .collection('askis')
              .doc(askiId)
              .collection('applications')
              .where('status', isEqualTo: ApplicationStatus.pending.name)
              .get();

      if (applicationsSnapshot.docs.isEmpty) {
        developer.log(
          'Bu askı için bekleyen başvuru yok.',
          name: 'AskiService',
        );
        return null;
      }

      final applications =
          applicationsSnapshot.docs.map((doc) {
            return ApplicationModel.fromMap(doc.id, doc.data());
          }).toList();

      // Rastgele bir başvuru seç
      final random = Random();
      final selectedApplication =
          applications[random.nextInt(applications.length)];

      // Seçilen başvuruyu kabul et ve diğerlerini reddet
      await _firestore.runTransaction((transaction) async {
        // Seçilen başvuruyu güncelle
        transaction.update(
          _firestore
              .collection('askis')
              .doc(askiId)
              .collection('applications')
              .doc(selectedApplication.id),
          {'status': ApplicationStatus.accepted.name},
        );

        // Diğer başvuruları reddet
        for (var app in applications) {
          if (app.id != selectedApplication.id) {
            transaction.update(
              _firestore
                  .collection('askis')
                  .doc(askiId)
                  .collection('applications')
                  .doc(app.id),
              {'status': ApplicationStatus.rejected.name},
            );
          }
        }

        // Askının durumunu güncelle
        transaction.update(_firestore.collection('askis').doc(askiId), {
          'status': AskiStatus.taken.name, // Status set to taken (won)
          'takenByUserId': selectedApplication.applicantUserId,
          'takenByUserName': selectedApplication.applicantUserName,
          'takenAt': DateTime.now().millisecondsSinceEpoch,
        });
      });

      // Kazanan bireysel kullanıcıya bildirim gönder
      final aski = await getAski(askiId); // Askı detaylarını al
      if (aski != null) {
        await _notificationService.createNotification(
          userId: selectedApplication.applicantUserId,
          title: NotificationType.askiWon.displayName,
          message:
              'Tebrikler! ${aski.productName} adlı askıyı kazandınız. Ürünü almak için QR kodu oluşturun.',
          type: NotificationType.askiWon,
          relatedPostId: aski.id,
          data: {
            'askiId': aski.id,
            'productName': aski.productName,
            'corporateName': aski.corporateName,
            'corporateId': aski.corporateId,
            'applicantUserId': selectedApplication.applicantUserId,
          },
        );
        developer.log(
          'Kazanan bildirim gönderildi: ${selectedApplication.applicantUserName}',
          name: 'AskiService',
        );
      }

      developer.log(
        'Rastgele başvuru seçildi: ${selectedApplication.applicantUserName}',
        name: 'AskiService',
      );
      return selectedApplication;
    } catch (e) {
      developer.log('Rastgele başvuru seçme hatası: $e', name: 'AskiService');
      return null;
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
      int completed = 0; // Yeni eklendi

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
          case 'completed': // Yeni eklendi
            completed++;
            break;
        }
      }

      return {
        'total': total,
        'active': active,
        'taken': taken,
        'cancelled': cancelled,
        'completed': completed, // Yeni eklendi
      };
    } catch (e) {
      developer.log('İstatistik alma hatası: $e', name: 'AskiService');
      return {
        'total': 0,
        'active': 0,
        'taken': 0,
        'cancelled': 0,
        'completed': 0,
      };
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
        'status':
            AskiStatus.completed.name, // Status set to completed (delivered)
      });

      developer.log('Askı tamamlandı: $askiId', name: 'AskiService');
    } catch (e) {
      developer.log('Askı tamamlama hatası: $e', name: 'AskiService');
      rethrow;
    }
  }

  // Askıyı geri alma (kazanan vazgeçerse veya teslimat gerçekleşmezse)
  Future<bool> revertAskiStatus(String askiId) async {
    try {
      await _firestore.collection('askis').doc(askiId).update({
        'status': AskiStatus.active.name,
        'takenByUserId': FieldValue.delete(),
        'takenByUserName': FieldValue.delete(),
        'takenAt': FieldValue.delete(),
      });
      developer.log(
        'Askı durumu aktif olarak geri alındı: $askiId',
        name: 'AskiService',
      );
      return true;
    } catch (e) {
      developer.log('Askı durumu geri alınırken hata: $e', name: 'AskiService');
      return false;
    }
  }
}
