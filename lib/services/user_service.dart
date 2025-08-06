import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Kullanıcı koleksiyonu referansı
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Yeni kullanıcı kaydetme
  Future<void> createUser(UserModel userModel) async {
    try {
      await _usersCollection.doc(userModel.uid).set(userModel.toMap());
    } catch (e) {
      throw Exception('Kullanıcı kaydedilirken hata oluştu: $e');
    }
  }

  // Kullanıcı bilgilerini getirme
  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Kullanıcı bilgileri alınırken hata oluştu: $e');
    }
  }

  // Kullanıcı bilgilerini ID ile getirme (alias metod)
  Future<UserModel?> getUserById(String uid) async {
    return await getUser(uid);
  }

  // Mevcut kullanıcı bilgilerini getirme
  Future<UserModel?> getCurrentUser() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      return await getUser(currentUser.uid);
    }
    return null;
  }

  // Kullanıcı bilgilerini güncelleme
  Future<void> updateUser(UserModel userModel) async {
    try {
      await _usersCollection.doc(userModel.uid).update(userModel.toMap());
    } catch (e) {
      throw Exception('Kullanıcı güncellenirken hata oluştu: $e');
    }
  }

  // Kullanıcı onay durumunu güncelleme (admin işlemi)
  Future<void> approveUser(String uid) async {
    try {
      await _usersCollection.doc(uid).update({'isApproved': true});
    } catch (e) {
      throw Exception('Kullanıcı onaylanırken hata oluştu: $e');
    }
  }

  // Email doğrulama durumunu güncelleme
  Future<void> verifyUser(String uid) async {
    try {
      await _usersCollection.doc(uid).update({'isVerified': true});
    } catch (e) {
      throw Exception('Kullanıcı doğrulanırken hata oluştu: $e');
    }
  }

  // Kurumsal kullanıcıları listeleme (onay bekleyenler)
  Future<List<UserModel>> getPendingCorporateUsers() async {
    try {
      QuerySnapshot snapshot =
          await _usersCollection
              .where('userType', isEqualTo: 'corporate')
              .where('isApproved', isEqualTo: false)
              .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Bekleyen kullanıcılar alınırken hata oluştu: $e');
    }
  }

  // Onaylı kurumsal kullanıcıları listeleme
  Future<List<UserModel>> getApprovedCorporateUsers() async {
    try {
      developer.log(
        'Onaylı kurumsal kullanıcılar sorgusu başlatılıyor...',
        name: 'UserService',
      );

      QuerySnapshot snapshot =
          await _usersCollection
              .where('userType', isEqualTo: 'corporate')
              .where('isApproved', isEqualTo: true)
              .get();

      developer.log(
        'Bulunan kurumsal kullanıcı sayısı: ${snapshot.docs.length}',
        name: 'UserService',
      );

      final users =
          snapshot.docs
              .map(
                (doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>),
              )
              .toList();

      for (var user in users) {
        developer.log(
          'Kurumsal Kullanıcı: ${user.organizationName ?? user.fullName} - Onaylı: ${user.isApproved}',
          name: 'UserService',
        );
      }

      return users;
    } catch (e) {
      developer.log('Kurumsal kullanıcı sorgu hatası: $e', name: 'UserService');
      throw Exception('Onaylı kurumsal kullanıcılar alınırken hata oluştu: $e');
    }
  }

  // Kullanıcıyı silme
  Future<void> deleteUser(String uid) async {
    try {
      await _usersCollection.doc(uid).delete();
    } catch (e) {
      throw Exception('Kullanıcı silinirken hata oluştu: $e');
    }
  }

  // Admin metodları

  // Bekleyen tüm kullanıcıları getirme
  Future<List<UserModel>> getPendingUsers() async {
    try {
      QuerySnapshot snapshot =
          await _usersCollection.where('isApproved', isEqualTo: false).get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Bekleyen kullanıcılar alınırken hata oluştu: $e');
    }
  }

  // Kullanıcı onay durumunu güncelleme
  Future<void> updateUserApproval(String uid, bool isApproved) async {
    try {
      await _usersCollection.doc(uid).update({'isApproved': isApproved});
    } catch (e) {
      throw Exception('Kullanıcı onay durumu güncellenirken hata oluştu: $e');
    }
  }

  // Tüm kullanıcıları getirme (admin)
  Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _usersCollection.get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Kullanıcılar alınırken hata oluştu: $e');
    }
  }

  // Kullanıcı sayısını getirme
  Future<int> getUserCount() async {
    try {
      QuerySnapshot snapshot = await _usersCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      throw Exception('Kullanıcı sayısı alınırken hata oluştu: $e');
    }
  }

  // Email ile kullanıcı arama
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      QuerySnapshot snapshot =
          await _usersCollection
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Email ile kullanıcı aranırken hata oluştu: $e');
    }
  }
}



