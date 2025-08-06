import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:developer' as developer;
import '../models/post_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Post koleksiyonu referansı
  CollectionReference get _postsCollection => _firestore.collection('posts');

  // Yeni post oluşturma
  Future<String> createPost(PostModel post) async {
    try {
      DocumentReference docRef = await _postsCollection.add(post.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Post oluşturulurken hata oluştu: $e');
    }
  }

  // Tüm aktif postları getirme (feed için)
  Future<List<PostModel>> getActivePosts({
    PostCategory? category,
    PostType? postType,
    int limit = 20,
  }) async {
    try {
      // En basit query - sadece status filtresi
      Query query = _postsCollection
          .where('status', isEqualTo: 'active')
          .limit(limit);

      QuerySnapshot snapshot = await query.get();
      List<PostModel> posts =
          snapshot.docs
              .map(
                (doc) => PostModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

      // Client-side sıralama ve filtreleme
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (category != null) {
        posts = posts.where((post) => post.category == category).toList();
      }

      if (postType != null) {
        posts = posts.where((post) => post.postType == postType).toList();
      }

      return posts;
    } catch (e) {
      throw Exception('Postlar alınırken hata oluştu: $e');
    }
  }

  // Kullanıcının postlarını getirme
  Future<List<PostModel>> getUserPosts(String uid) async {
    try {
      QuerySnapshot snapshot =
          await _postsCollection
              .where('creatorUid', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Kullanıcı postları alınırken hata oluştu: $e');
    }
  }

  // Mevcut kullanıcının postları
  Future<List<PostModel>> getCurrentUserPosts() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      return await getUserPosts(currentUser.uid);
    }
    return [];
  }

  // Post detayını getirme
  Future<PostModel?> getPost(String postId) async {
    try {
      DocumentSnapshot doc = await _postsCollection.doc(postId).get();
      if (doc.exists) {
        return PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Post detayı alınırken hata oluştu: $e');
    }
  }

  // Post'a başvuru yapma
  Future<void> applyToPost(String postId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Giriş yapmanız gerekiyor');
    }

    try {
      DocumentReference postRef = _postsCollection.doc(postId);
      DocumentSnapshot postDoc = await postRef.get();

      if (!postDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      PostModel post = PostModel.fromMap(
        postDoc.id,
        postDoc.data() as Map<String, dynamic>,
      );

      // Kontroller
      if (!post.canApply) {
        throw Exception('Bu post\'a başvuru yapılamaz');
      }

      if (post.applicantUids.contains(currentUser.uid)) {
        throw Exception('Bu post\'a zaten başvuru yaptınız');
      }

      if (post.creatorUid == currentUser.uid) {
        throw Exception('Kendi postunuza başvuru yapamazsınız');
      }

      if (!post.hasAvailableSlots) {
        throw Exception('Başvuru kotası doldu');
      }

      // Başvuru ekle
      List<String> updatedApplicants = [...post.applicantUids, currentUser.uid];

      await postRef.update({'applicantUids': updatedApplicants});

      // İlk gelen alır türündeyse ve ilk başvuran buysa otomatik seç
      if (post.postType == PostType.firstCome &&
          updatedApplicants.length == 1) {
        await _selectWinner(postId, currentUser.uid);
      }
    } catch (e) {
      throw Exception('Başvuru yapılırken hata oluştu: $e');
    }
  }

  // Rastgele seçim yapma (admin/creator işlemi)
  Future<void> selectRandomWinner(String postId) async {
    try {
      DocumentSnapshot postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      PostModel post = PostModel.fromMap(
        postDoc.id,
        postDoc.data() as Map<String, dynamic>,
      );

      if (post.applicantUids.isEmpty) {
        throw Exception('Henüz başvuru yapılmamış');
      }

      // Rastgele seçim
      post.applicantUids.shuffle();
      String selectedUid = post.applicantUids.first;

      await _selectWinner(postId, selectedUid);
    } catch (e) {
      throw Exception('Rastgele seçim yapılırken hata oluştu: $e');
    }
  }

  // Kazanan seçme (private method)
  Future<void> _selectWinner(String postId, String winnerUid) async {
    await _postsCollection.doc(postId).update({
      'selectedUserUid': winnerUid,
      'status': 'completed',
    });
  }

  // Post güncelleme
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _postsCollection.doc(postId).update(updates);
    } catch (e) {
      throw Exception('Post güncellenirken hata oluştu: $e');
    }
  }

  // Post silme
  Future<void> deletePost(String postId) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Giriş yapmanız gerekiyor');
    }

    try {
      DocumentSnapshot postDoc = await _postsCollection.doc(postId).get();
      if (!postDoc.exists) {
        throw Exception('Post bulunamadı');
      }

      PostModel post = PostModel.fromMap(
        postDoc.id,
        postDoc.data() as Map<String, dynamic>,
      );

      if (post.creatorUid != currentUser.uid) {
        throw Exception('Bu postu silme yetkiniz yok');
      }

      await _postsCollection.doc(postId).delete();
    } catch (e) {
      throw Exception('Post silinirken hata oluştu: $e');
    }
  }

  // Post durumunu güncelleme
  Future<void> updatePostStatus(String postId, PostStatus status) async {
    try {
      await _postsCollection.doc(postId).update({
        'status': status.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Post durumu güncellenirken hata oluştu: $e');
    }
  }

  // Kategoriye göre postları getirme
  Future<List<PostModel>> getPostsByCategory(PostCategory category) async {
    try {
      QuerySnapshot snapshot =
          await _postsCollection
              .where('category', isEqualTo: category.toString().split('.').last)
              .where('status', isEqualTo: 'active')
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Kategori postları alınırken hata oluştu: $e');
    }
  }

  // Kullanıcının başvurduğu postları getirme
  Future<List<PostModel>> getUserApplications(String uid) async {
    try {
      QuerySnapshot snapshot =
          await _postsCollection
              .where('applicantUids', arrayContains: uid)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Başvurular alınırken hata oluştu: $e');
    }
  }

  // Post istatistikleri
  Future<Map<String, int>> getPostStats(String uid) async {
    try {
      QuerySnapshot userPosts =
          await _postsCollection.where('creatorUid', isEqualTo: uid).get();

      QuerySnapshot completedPosts =
          await _postsCollection
              .where('creatorUid', isEqualTo: uid)
              .where('status', isEqualTo: 'completed')
              .get();

      QuerySnapshot activePosts =
          await _postsCollection
              .where('creatorUid', isEqualTo: uid)
              .where('status', isEqualTo: 'active')
              .get();

      return {
        'total': userPosts.docs.length,
        'completed': completedPosts.docs.length,
        'active': activePosts.docs.length,
      };
    } catch (e) {
      throw Exception('İstatistikler alınırken hata oluştu: $e');
    }
  }

  // Ürün sistemi metodları

  // 6 haneli claim kodu oluşturma
  String _generateClaimCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // QR kod için benzersiz ID oluşturma
  String _generateQRCode(String postId) {
    return 'ASKIDA_${postId}_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Post oluştururken kod eklemeli versiyon
  Future<String> createPostWithCodes(PostModel post) async {
    try {
      // Post ID'sini almak için önce oluşturalım
      DocumentReference docRef = _postsCollection.doc();
      String postId = docRef.id;

      // Kodları oluştur
      String claimCode = _generateClaimCode();
      String qrCode = _generateQRCode(postId);

      // Post'u kodlarla güncelle
      PostModel updatedPost = post.copyWith(
        id: postId,
        claimCode: claimCode,
        qrCode: qrCode,
        remainingQuantity:
            post.quantity, // Başlangıçta kalan adet = toplam adet
      );

      await docRef.set(updatedPost.toMap());
      return postId;
    } catch (e) {
      throw Exception('Post oluşturulurken hata oluştu: $e');
    }
  }

  // Ürün teslim alma (claim) - kod ile
  Future<bool> claimProductByCode(String claimCode, String userUid) async {
    try {
      // Claim code ile post bul
      QuerySnapshot snapshot =
          await _postsCollection
              .where('claimCode', isEqualTo: claimCode)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Geçersiz veya kullanılmış kod');
      }

      DocumentSnapshot doc = snapshot.docs.first;
      PostModel post = PostModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );

      // Post sahibinin kendi ürününü almasını engelle
      if (post.creatorUid == userUid) {
        throw Exception('Kendi paylaştığınız ürünü alamazsınız');
      }

      // Kalan ürün kontrolü
      if (post.remainingQuantity <= 0) {
        throw Exception('Bu üründen kalmadı');
      }

      // Kullanıcı daha önce almış mı kontrolü
      if (post.claimedByUids.contains(userUid)) {
        throw Exception('Bu üründen zaten almışsınız');
      }

      // Ürün teslim alma işlemi
      List<String> updatedClaimedByUids = List.from(post.claimedByUids)
        ..add(userUid);
      int newRemainingQuantity = post.remainingQuantity - 1;

      // Post durumunu güncelle
      PostStatus newStatus =
          newRemainingQuantity <= 0 ? PostStatus.completed : PostStatus.active;

      await doc.reference.update({
        'claimedByUids': updatedClaimedByUids,
        'remainingQuantity': newRemainingQuantity,
        'status': newStatus.toString().split('.').last,
      });

      // Ürün sahibine bildirim gönder
      try {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          userId: post.creatorUid,
          title: 'Ürününüz Teslim Alındı!',
          message:
              '${post.title} ürününüz teslim alındı. Kalan: $newRemainingQuantity',
          type: NotificationType.productClaimed,
          relatedPostId: doc.id,
        );
      } catch (e) {
        // Bildirim hatası ürün alma işlemini etkilemesin
        developer.log('Bildirim gönderme hatası: $e', name: 'PostService');
      }

      return true;
    } catch (e) {
      throw Exception('Ürün teslim alınırken hata oluştu: $e');
    }
  }

  // QR kod ile ürün teslim alma
  Future<bool> claimProductByQR(String qrCode, String userUid) async {
    try {
      QuerySnapshot snapshot =
          await _postsCollection
              .where('qrCode', isEqualTo: qrCode)
              .where('status', isEqualTo: 'active')
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('Geçersiz QR kod');
      }

      DocumentSnapshot doc = snapshot.docs.first;
      PostModel post = PostModel.fromMap(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );

      // Post sahibinin kendi ürününü almasını engelle
      if (post.creatorUid == userUid) {
        throw Exception('Kendi paylaştığınız ürünü alamazsınız');
      }

      // Kalan ürün kontrolü
      if (post.remainingQuantity <= 0) {
        throw Exception('Bu üründen kalmadı');
      }

      // Kullanıcı daha önce almış mı kontrolü
      if (post.claimedByUids.contains(userUid)) {
        throw Exception('Bu üründen zaten almışsınız');
      }

      // Ürün teslim alma işlemi
      List<String> updatedClaimedByUids = List.from(post.claimedByUids)
        ..add(userUid);
      int newRemainingQuantity = post.remainingQuantity - 1;

      // Post durumunu güncelle
      PostStatus newStatus =
          newRemainingQuantity <= 0 ? PostStatus.completed : PostStatus.active;

      await doc.reference.update({
        'claimedByUids': updatedClaimedByUids,
        'remainingQuantity': newRemainingQuantity,
        'status': newStatus.toString().split('.').last,
      });

      // Ürün sahibine bildirim gönder
      try {
        final notificationService = NotificationService();
        await notificationService.createNotification(
          userId: post.creatorUid,
          title: 'Ürününüz Teslim Alındı!',
          message:
              '${post.title} ürününüz QR kod ile teslim alındı. Kalan: $newRemainingQuantity',
          type: NotificationType.productClaimed,
          relatedPostId: doc.id,
        );
      } catch (e) {
        // Bildirim hatası ürün alma işlemini etkilemesin
        developer.log('Bildirim gönderme hatası: $e', name: 'PostService');
      }

      return true;
    } catch (e) {
      throw Exception('QR kod ile ürün teslim alınırken hata oluştu: $e');
    }
  }

  // Kullanıcının aldığı ürünler
  Future<List<PostModel>> getUserClaimedProducts(String userUid) async {
    try {
      QuerySnapshot snapshot =
          await _postsCollection
              .where('claimedByUids', arrayContains: userUid)
              .orderBy('createdAt', descending: true)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Alınan ürünler getirilirken hata oluştu: $e');
    }
  }

  // Gelişmiş arama fonksiyonu
  Future<List<PostModel>> searchPosts({
    String? query,
    PostCategory? category,
    PostType? postType,
    PostStatus? status,
    String? city,
    int? minQuantity,
    int? maxQuantity,
  }) async {
    try {
      Query searchQuery = _postsCollection;

      // Durum filtresi (varsayılan olarak aktif)
      if (status != null) {
        searchQuery = searchQuery.where(
          'status',
          isEqualTo: status.toString().split('.').last,
        );
      } else {
        searchQuery = searchQuery.where('status', isEqualTo: 'active');
      }

      // Kategori filtresi
      if (category != null) {
        searchQuery = searchQuery.where(
          'category',
          isEqualTo: category.toString().split('.').last,
        );
      }

      // Post türü filtresi
      if (postType != null) {
        searchQuery = searchQuery.where(
          'postType',
          isEqualTo: postType.toString().split('.').last,
        );
      }

      QuerySnapshot snapshot = await searchQuery.get();
      List<PostModel> posts =
          snapshot.docs
              .map(
                (doc) => PostModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

      // Client-side filtreleme (Firestore'da desteklenmeyen özellikler için)
      if (query != null && query.isNotEmpty) {
        posts =
            posts.where((post) {
              return post.title.toLowerCase().contains(query.toLowerCase()) ||
                  post.description.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  post.productType.toLowerCase().contains(query.toLowerCase());
            }).toList();
      }

      // Miktar filtresi
      if (minQuantity != null) {
        posts =
            posts
                .where((post) => post.remainingQuantity >= minQuantity)
                .toList();
      }
      if (maxQuantity != null) {
        posts =
            posts
                .where((post) => post.remainingQuantity <= maxQuantity)
                .toList();
      }

      // Şehir filtresi
      if (city != null && city.isNotEmpty) {
        posts =
            posts
                .where(
                  (post) =>
                      post.location != null &&
                      post.location!.toLowerCase().contains(city.toLowerCase()),
                )
                .toList();
      }

      return posts;
    } catch (e) {
      throw Exception('Arama sırasında hata oluştu: $e');
    }
  }

  // Popüler aramalar
  Future<List<String>> getPopularSearchTerms() async {
    // Bu gelecekte search analytics ile implement edilebilir
    return ['gıda', 'kıyafet', 'kitap', 'elektronik', 'mobilya'];
  }

  // Önerilen postlar (kategori bazlı)
  Future<List<PostModel>> getRecommendedPosts(String userUid) async {
    try {
      // Kullanıcının geçmiş aktivitelerine göre öneriler sunulabilir
      // Şimdilik random aktif postlar döndürelim
      QuerySnapshot snapshot =
          await _postsCollection
              .where('status', isEqualTo: 'active')
              .where('creatorUid', isNotEqualTo: userUid)
              .limit(10)
              .get();

      return snapshot.docs
          .map(
            (doc) =>
                PostModel.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception('Önerilen postlar alınırken hata oluştu: $e');
    }
  }
}



