import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/user_service.dart';
import '../services/aski_service.dart';
import '../models/user_model.dart';
import '../models/aski_model.dart';
import 'dart:developer' as developer;

class QRValidatorScreen extends StatefulWidget {
  const QRValidatorScreen({super.key});

  @override
  State<QRValidatorScreen> createState() => _QRValidatorScreenState();
}

class _QRValidatorScreenState extends State<QRValidatorScreen> {
  final UserService _userService = UserService();
  final AskiService _askiService = AskiService();
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
          title: const Text('Askı Tamamlama'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  '${aski.productName} adlı askıyı ${aski.takenByUserId == _currentUser!.uid ? 'siz' : aski.takenByUserName} teslim alacak.',
                ),
                const Text('Bu işlemi onaylıyor musunuz?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
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
              child: const Text('Onayla'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _askiService.completeAski(aski.id);
                  setState(() {
                    _validationMessage = 'Askı başarıyla tamamlandı!';
                  });
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
        foregroundColor: Colors.white,
      ),
      body:
          _currentUser?.userType != UserType.corporate
              ? const Center(
                child: Text('Bu sayfa sadece kurumsal kullanıcılar içindir.'),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Askıdan alınacak ürünün QR kodunu okutun.',
                            style: TextStyle(fontSize: 16),
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
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _validationMessage!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        _isProcessing
                            ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('QR kod işleniyor...'),
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
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    'Kamera başlatılamadı: ${error.toString()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Lütfen uygulama izinlerini kontrol edin veya cihazınızı yeniden başlatın.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
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
