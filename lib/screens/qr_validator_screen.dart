import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/user_service.dart';
import '../services/aski_service.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../models/aski_model.dart';
import 'dart:developer' as developer;
import 'package:askida/models/notification_model.dart'; // NotificationModel eklendi

class QRValidatorScreen extends StatefulWidget {
  const QRValidatorScreen({super.key});

  @override
  State<QRValidatorScreen> createState() => _QRValidatorScreenState();
}

class _QRValidatorScreenState extends State<QRValidatorScreen> {
  final UserService _userService = UserService();
  final AskiService _askiService = AskiService();
  // final NotificationService _notificationService = NotificationService(); // NotificationService örneği
  MobileScannerController cameraController = MobileScannerController();
  UserModel? _currentUser;
  bool _isProcessing = false;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _onQRCodeDetected(BarcodeCapture barcodeCapture) async {
    if (_isProcessing) return;

    if (_currentUser == null) {
      setState(() {
        _validationMessage =
            'Kullanıcı bilgileri yükleniyor, lütfen bekleyin veya tekrar deneyin.';
        _isProcessing = false;
      });
      return;
    }

    final String? qrData = barcodeCapture.barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) {
      setState(() {
        _validationMessage = 'QR kodu okunamadı.';
        _isProcessing = false;
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _validationMessage = null;
    });

    developer.log('Raw QR Data: $qrData', name: 'QRValidatorScreen');

    try {
      final Map<String, dynamic> qrContent = jsonDecode(qrData);
      developer.log('Parsed QR Content: $qrContent', name: 'QRValidatorScreen');

      final String askiId = qrContent['askiId'];
      final String? applicantUserIdFromQR =
          qrContent['applicantUserId']; // QR'dan gelen applicantUserId

      final aski = await _askiService.getAski(askiId);

      if (aski == null) {
        setState(() {
          _validationMessage = 'Geçersiz QR kod - Askı bulunamadı';
          _isProcessing = false;
        });
        cameraController.stop();
        return;
      }

      if (_currentUser!.userType == UserType.corporate) {
        developer.log(
          'Corporate user scanning. Aski Status: ${aski.status}, Aski TakenByUserId: ${aski.takenByUserId}, QR ApplicantUserId: $applicantUserIdFromQR',
          name: 'QRValidatorScreen',
        );
        if (aski.status == AskiStatus.taken &&
            aski.takenByUserId == applicantUserIdFromQR) {
          // Corporate user is scanning a winner's QR code to finalize delivery
          setState(() {
            _validationMessage = 'Ürün teslimatı için QR kodu doğrulandı.';
          });
          _showCompletionDialog(aski);
        } else if (aski.status == AskiStatus.completed) {
          setState(() {
            _validationMessage = 'Bu askı zaten tamamlanmış.';
            _isProcessing = false;
          });
          cameraController.stop();
        } else if (aski.status == AskiStatus.active) {
          // Specific message for active askis scanned by corporate
          setState(() {
            _validationMessage =
                'Bu QR kodu aktif bir askıya ait. Kurumsal kullanıcılar sadece kazanılmış askıların teslimatını onaylayabilir.';
            _isProcessing = false;
          });
          cameraController.stop();
        } else {
          setState(() {
            _validationMessage =
                'Bu QR kodu bir kazanan tarafından sunulmadı veya askı durumu uygun değil.';
            _isProcessing = false;
          });
          cameraController.stop();
        }
      } else {
        // Individual user is scanning
        if (aski.corporateId.isNotEmpty) {
          setState(() {
            _validationMessage =
                'Bu askı sadece kurumsal kullanıcılar tarafından teslim edilebilir.';
            _isProcessing = false;
          });
          cameraController.stop();
          return;
        }

        if (aski.donorUserId == _currentUser!.uid) {
          setState(() {
            _validationMessage = 'Kendi askınızı teslim alamazsınız.';
            _isProcessing = false;
          });
          cameraController.stop();
          return;
        }

        if (aski.status == AskiStatus.active) {
          // Individual user trying to take an active aski via QR scan (not allowed on this screen)
          setState(() {
            _validationMessage =
                'Bu ekran sadece kurumsal kullanıcılar içindir. Askı almak için ana sayfayı kullanın.';
            _isProcessing = false;
          });
          cameraController.stop();
        } else if (aski.status == AskiStatus.taken &&
            aski.takenByUserId == _currentUser!.uid) {
          // Individual user trying to scan their own won aski (should use QRDisplayScreen)
          setState(() {
            _validationMessage =
                'Bu askıyı zaten kazandınız. QR kodunuzu göstermek için ana sayfadaki askı detaylarına gidin.';
            _isProcessing = false;
          });
          cameraController.stop();
        } else {
          setState(() {
            _validationMessage = 'Askı durumu uygun değil veya yetkiniz yok.';
            _isProcessing = false;
          });
          cameraController.stop();
        }
      }
    } catch (e) {
      developer.log('QR kod işleme hatası: $e', name: 'QRValidatorScreen');
      setState(() {
        _validationMessage = 'QR kodu işlenirken bir hata oluştu: $e';
        _isProcessing = false;
      });
      cameraController.stop();
    } finally {
      // No need to restart camera here, it's handled in dialogs or error states
    }
  }

  Future<void> _showCompletionDialog(AskiModel aski) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Askı Tamamlama',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '${aski.productName} adlı askıyı ${aski.takenByUserId == _currentUser!.uid ? 'siz' : aski.takenByUserName} teslim alacak.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Bu işlemi onaylıyor musunuz?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'İptal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _isProcessing = false;
                  _validationMessage = null;
                });
                cameraController.start(); // Restart camera
              },
            ),
            TextButton(
              child: Text(
                'Onayla',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              onPressed: () async {
                developer.log(
                  'QRValidatorScreen: Onayla button pressed. Calling completeAski.',
                  name: 'QRValidatorScreen',
                );
                Navigator.of(context).pop();
                try {
                  await _askiService.completeAski(aski.id);
                  setState(() {
                    _validationMessage = 'Askı başarıyla tamamlandı!';
                  });
                  // Send notification to the winner (takenByUserId)
                  if (aski.takenByUserId != null) {
                    final NotificationService notificationService =
                        NotificationService();
                    await notificationService.createNotification(
                      userId: aski.takenByUserId!,
                      title: NotificationType.productDelivered.displayName,
                      message: NotificationType.productDelivered.description,
                      type: NotificationType.productDelivered,
                      relatedPostId: aski.id,
                      data: {
                        'askiId': aski.id,
                        'productName': aski.productName,
                        'corporateName': aski.corporateName,
                      },
                    );
                    developer.log(
                      'Product delivered notification sent for askiId: ${aski.id} to userId: ${aski.takenByUserId}',
                      name: 'QRValidatorScreen',
                    );
                  }
                  // Optionally navigate to a success screen or home
                } catch (e) {
                  setState(() {
                    _validationMessage = 'Askı tamamlama hatası: $e';
                  });
                } finally {
                  setState(() {
                    _isProcessing = false;
                  });
                  cameraController.start(); // Restart camera
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kod Doğrulama'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body:
          _currentUser?.userType != UserType.corporate
              ? Center(
                child: Text(
                  'Bu sayfa sadece kurumsal kullanıcılar içindir.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha((255 * 0.3).round()),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Askıdan alınacak ürünün QR kodunu okutun.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_validationMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withAlpha((255 * 0.1).round()),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withAlpha((255 * 0.3).round()),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        _isProcessing
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'QR kod işleniyor...',
                                    style: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : _buildScannerView(),
                  ),
                ],
              ),
    );
  }

  Widget _buildScannerView() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MobileScanner(
          controller: cameraController,
          onDetect: _onQRCodeDetected,
          errorBuilder: (context, error) {
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
                    'Kamera başlatılamadı: ${error.toString()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lütfen uygulama izinlerini kontrol edin veya cihazınızı yeniden başlatın.',
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
            );
          },
        ),
      ),
    );
  }
}
