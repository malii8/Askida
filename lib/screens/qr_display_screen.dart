import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:askida/models/aski_model.dart'; // AskiModel eklendi
import 'package:askida/services/notification_service.dart'; // NotificationService eklendi
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth eklendi
import 'package:askida/models/notification_model.dart'; // NotificationModel eklendi
import 'package:askida/services/aski_service.dart'; // AskiService eklendi
import 'dart:developer' as developer; // Geliştirici araçları için

class QRDisplayScreen extends StatefulWidget {
  final String askiId;
  final String productName;
  final String corporateName;
  final String corporateId;
  final String? applicantUserId; // Yeni eklendi
  final PostType postType; // Yeni eklendi

  const QRDisplayScreen({
    super.key,
    required this.askiId,
    required this.productName,
    required this.corporateName,
    required this.corporateId,
    this.applicantUserId, // Constructor'a eklendi
    required this.postType, // Constructor'a eklendi
  });

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  StreamSubscription<AskiModel?>? _askiSubscription;
  StreamSubscription<List<NotificationModel>>?
  _notificationSubscription; // Yeni eklendi
  final NotificationService _notificationService =
      NotificationService(); // Yeni eklendi
  final AskiService _askiService = AskiService(); // AskiService eklendi

  @override
  void initState() {
    super.initState();
    developer.log(
      'QRDisplayScreen: Initialized with askiId: ${widget.askiId}',
      name: 'QRDisplayScreen',
    );
    _listenForProductDeliveredNotification();
  }

  void _listenForProductDeliveredNotification() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    _notificationSubscription = _notificationService
        .getUserNotificationsStream(userId: currentUserUid, includeRead: true)
        .listen((notifications) {
          developer.log(
            'QRDisplayScreen: Received ${notifications.length} notifications.',
            name: 'QRDisplayScreen',
          );
          for (var notification in notifications) {
            developer.log(
              'QRDisplayScreen: Processing notification - Type: ${notification.type}, RelatedPostId: ${notification.relatedPostId}, IsRead: ${notification.isRead}',
              name: 'QRDisplayScreen',
            );
            if (notification.type == NotificationType.productDelivered &&
                notification.relatedPostId == widget.askiId) {
              developer.log(
                'QRDisplayScreen: Product delivered notification matched for askiId: ${widget.askiId}',
                name: 'QRDisplayScreen',
              );
              // Ürün teslim edildi bildirimi alındı
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(notification.message),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
                _notificationService.markAsRead(notification.id);
                // Geri sayfaya at
                Future.delayed(const Duration(seconds: 3), () {
                  developer.log(
                    'QRDisplayScreen: Attempting to pop. mounted: $mounted, canPop: ${Navigator.canPop(context)}',
                    name: 'QRDisplayScreen',
                  );
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                    developer.log(
                      'QRDisplayScreen: Screen popped successfully.',
                      name: 'QRDisplayScreen',
                    );
                  } else {
                    developer.log(
                      'QRDisplayScreen: Cannot pop screen. mounted: $mounted, canPop: ${Navigator.canPop(context)}',
                      name: 'QRDisplayScreen',
                    );
                  }
                });
              }
              break; // Sadece ilgili bildirimi işle
            }
          }
        });
  }

  @override
  void dispose() {
    _askiSubscription?.cancel(); // Aboneliği iptal et
    _notificationSubscription?.cancel(); // Aboneliği iptal et
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // QR kod verisi oluştur
    final qrData = {
      'type': 'askida_product',
      'askiId': widget.askiId,
      'productName': widget.productName,
      'corporateName': widget.corporateName,
      'corporateId': widget.corporateId,
      'applicantUserId': widget.applicantUserId, // Yeni eklendi
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final qrString = jsonEncode(qrData);

    return PopScope(
      canPop: false, // Prevent popping by default
      onPopInvoked: (didPop) async {
        if (didPop) return; // If system already popped, do nothing

        if (widget.postType == PostType.firstComeFirstServe) {
          // Corrected comparison
          developer.log(
            'QRDisplayScreen: Back button pressed for FirstComeFirstServe. Reverting aski status.',
            name: 'QRDisplayScreen',
          );
          final success = await _askiService.revertAskiStatus(widget.askiId);
          if (success) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Askı durumu geri alındı.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Askı durumu geri alınamadı.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          developer.log(
            'QRDisplayScreen: Back button pressed for RandomSelection. Not reverting aski status.',
            name: 'QRDisplayScreen',
          );
        }
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('QR Kod'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bilgi kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Askıdan alınacak ürünün QR kodunu okutun.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'QR kodunu kamera ile okutun',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // QR Kod
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromRGBO(128, 128, 128, 0.3),
                          spreadRadius: 2,
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: qrString,
                          version: QrVersions.auto,
                          size: 250.0,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'QR Kod Tarayıcısı Buraya Gelecek',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Ürün bilgileri
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ürün Bilgileri:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.shopping_bag,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('Ürün: ${widget.productName}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.business,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text('Firma: ${widget.corporateName}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
