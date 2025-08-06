import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../models/post_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Bildirim koleksiyonu referansı
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  // Yeni bildirim oluşturma
  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? relatedPostId,
    String? relatedUserId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        id: '', // Firestore otomatik ID verecek
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedPostId: relatedPostId,
        relatedUserId: relatedUserId,
        createdAt: DateTime.now(),
        data: data,
      );

      DocumentReference docRef = await _notificationsCollection.add(
        notification.toMap(),
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Bildirim oluşturulurken hata oluştu: $e');
    }
  }

  // Kullanıcının bildirimlerini getirme
  Future<List<NotificationModel>> getUserNotifications({
    String? userId,
    int limit = 50,
    bool? isRead,
  }) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      Query query = _notificationsCollection
          .where('userId', isEqualTo: targetUserId)
          .limit(limit);

      if (isRead != null) {
        query = query.where('isRead', isEqualTo: isRead);
      }

      QuerySnapshot snapshot = await query.get();
      List<NotificationModel> notifications =
          snapshot.docs
              .map(
                (doc) => NotificationModel.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

      // Client-side'da sıralama yap
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    } catch (e) {
      throw Exception('Bildirimler alınırken hata oluştu: $e');
    }
  }

  // Bildirimi okundu olarak işaretleme
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      throw Exception('Bildirim güncellenirken hata oluştu: $e');
    }
  }

  // Tüm bildirimleri okundu olarak işaretleme
  Future<void> markAllAsRead({String? userId}) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) {
        throw Exception('Kullanıcı oturumu bulunamadı');
      }

      QuerySnapshot snapshot =
          await _notificationsCollection
              .where('userId', isEqualTo: targetUserId)
              .where('isRead', isEqualTo: false)
              .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Bildirimler güncellenirken hata oluştu: $e');
    }
  }

  // Okunmamış bildirim sayısı
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) return 0;

      QuerySnapshot snapshot =
          await _notificationsCollection
              .where('userId', isEqualTo: targetUserId)
              .where('isRead', isEqualTo: false)
              .get();

      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  // Okunmamış bildirim sayısı stream
  Stream<int> getUnreadCountStream({String? userId}) {
    try {
      final targetUserId = userId ?? _auth.currentUser?.uid;
      if (targetUserId == null) return Stream.value(0);

      return _notificationsCollection
          .where('userId', isEqualTo: targetUserId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.size);
    } catch (e) {
      return Stream.value(0);
    }
  }

  // Bildirim silme
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      throw Exception('Bildirim silinirken hata oluştu: $e');
    }
  }

  // Gerçek zamanlı bildirim dinleme
  Stream<List<NotificationModel>> getUserNotificationsStream({
    String? userId,
    int limit = 50,
  }) {
    final targetUserId = userId ?? _auth.currentUser?.uid;
    if (targetUserId == null) {
      return Stream.value([]);
    }

    return _notificationsCollection
        .where('userId', isEqualTo: targetUserId)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          List<NotificationModel> notifications =
              snapshot.docs
                  .map(
                    (doc) => NotificationModel.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .toList();

          // Client-side'da sıralama yap
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return notifications;
        });
  }

  // Post ile ilgili bildirimler oluşturma
  Future<void> createPostNotifications({
    required PostModel post,
    required NotificationType type,
    required String message,
    List<String>? targetUserIds,
  }) async {
    try {
      List<String> userIds = targetUserIds ?? [];

      // Eğer hedef kullanıcı listesi yoksa, post sahibine bildirim gönder
      if (userIds.isEmpty && type != NotificationType.applicationReceived) {
        userIds = [post.creatorUid];
      }

      for (String userId in userIds) {
        await createNotification(
          userId: userId,
          title: type.displayName,
          message: message,
          type: type,
          relatedPostId: post.id,
          relatedUserId: _auth.currentUser?.uid,
        );
      }
    } catch (e) {
      throw Exception('Post bildirimleri oluşturulurken hata oluştu: $e');
    }
  }

  // Başvuru bildirimi oluşturma
  Future<void> createApplicationNotification({
    required PostModel post,
    required String applicantId,
    required NotificationType type,
  }) async {
    try {
      String message = '';
      String targetUserId = '';

      switch (type) {
        case NotificationType.applicationReceived:
          message = 'İlanınıza yeni bir başvuru yapıldı: ${post.title}';
          targetUserId = post.creatorUid;
          break;
        case NotificationType.applicationAccepted:
          message = 'Başvurunuz kabul edildi: ${post.title}';
          targetUserId = applicantId;
          break;
        case NotificationType.applicationRejected:
          message = 'Başvurunuz reddedildi: ${post.title}';
          targetUserId = applicantId;
          break;
        default:
          throw Exception('Geçersiz başvuru bildirim tipi');
      }

      await createNotification(
        userId: targetUserId,
        title: type.displayName,
        message: message,
        type: type,
        relatedPostId: post.id,
        relatedUserId:
            type == NotificationType.applicationReceived
                ? applicantId
                : post.creatorUid,
      );
    } catch (e) {
      throw Exception('Başvuru bildirimi oluşturulurken hata oluştu: $e');
    }
  }

  // Genel bildirim gönderme metodu
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    NotificationType type = NotificationType.other,
    String? relatedPostId,
    String? relatedUserId,
  }) async {
    try {
      await createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        relatedPostId: relatedPostId,
        relatedUserId: relatedUserId,
      );
    } catch (e) {
      throw Exception('Bildirim gönderilirken hata oluştu: $e');
    }
  }

  // Askı sahibine ilgi bildirimi gönderme
  Future<void> sendAskiInterestNotification({
    required String askiOwnerId,
    required String interestedUserId,
    required String interestedUserName,
    required String productName,
    required String askiId,
  }) async {
    try {
      await sendNotification(
        userId: askiOwnerId,
        title: 'Askıya İlgi',
        message:
            '$interestedUserName kullanıcısı "$productName" askınızla ilgileniyor',
        type: NotificationType.other,
        relatedPostId: askiId,
        relatedUserId: interestedUserId,
      );
    } catch (e) {
      throw Exception('Askı ilgi bildirimi gönderilirken hata oluştu: $e');
    }
  }
}



