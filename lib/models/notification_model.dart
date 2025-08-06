enum NotificationType {
  applicationReceived,
  applicationAccepted,
  applicationRejected,
  postExpired,
  newMessage,
  adminNotification,
  productClaimed,
  other,
}

extension NotificationTypeExtension on NotificationType {
  String get displayName {
    switch (this) {
      case NotificationType.applicationReceived:
        return 'Yeni Başvuru';
      case NotificationType.applicationAccepted:
        return 'Başvuru Kabul Edildi';
      case NotificationType.applicationRejected:
        return 'Başvuru Reddedildi';
      case NotificationType.postExpired:
        return 'İlan Süresi Doldu';
      case NotificationType.newMessage:
        return 'Yeni Mesaj';
      case NotificationType.adminNotification:
        return 'Yönetici Bildirimi';
      case NotificationType.productClaimed:
        return 'Ürün Teslim Alındı';
      case NotificationType.other:
        return 'Bildirim';
    }
  }

  String get description {
    switch (this) {
      case NotificationType.applicationReceived:
        return 'İlanınıza yeni bir başvuru yapıldı';
      case NotificationType.applicationAccepted:
        return 'Başvurunuz kabul edildi';
      case NotificationType.applicationRejected:
        return 'Başvurunuz reddedildi';
      case NotificationType.postExpired:
        return 'İlanınızın süresi doldu';
      case NotificationType.newMessage:
        return 'Size yeni bir mesaj geldi';
      case NotificationType.adminNotification:
        return 'Yönetici tarafından bir bildirim gönderildi';
      case NotificationType.productClaimed:
        return 'Ürününüz teslim alındı';
      case NotificationType.other:
        return 'Genel bildirim';
    }
  }
}

class NotificationModel {
  final String id;
  final String userId; // Bildirimi alacak kullanıcı
  final String title;
  final String message;
  final NotificationType type;
  final String? relatedPostId; // İlgili post varsa
  final String? relatedUserId; // İlgili kullanıcı varsa
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data; // Ek veriler

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.relatedPostId,
    this.relatedUserId,
    this.isRead = false,
    required this.createdAt,
    this.data,
  });

  // Firestore'dan veri okuma
  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
        orElse: () => NotificationType.adminNotification,
      ),
      relatedPostId: map['relatedPostId'],
      relatedUserId: map['relatedUserId'],
      isRead: map['isRead'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      data: map['data']?.cast<String, dynamic>(),
    );
  }

  // Firestore'a veri yazma
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.toString(),
      'relatedPostId': relatedPostId,
      'relatedUserId': relatedUserId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
    };
  }

  // Kopya oluşturma
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? relatedPostId,
    String? relatedUserId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      relatedPostId: relatedPostId ?? this.relatedPostId,
      relatedUserId: relatedUserId ?? this.relatedUserId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }
}



