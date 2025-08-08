import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/user_service.dart';
import '../services/aski_service.dart';
import '../models/user_model.dart';
import '../models/aski_model.dart';

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

    final String? qrData = barcodeCapture.barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _validationMessage = null;
    });

    try {
      // QR kodunu parse et
      final Map<String, dynamic> qrContent = jsonDecode(qrData);
      final String askiId = qrContent['askiId'];
      final String productName = qrContent['productName'];
      final String corporateName = qrContent['corporateName'];

      // Askıyı veritabanından kontrol et
      final aski = await _askiService.getAski(askiId);

      if (aski == null) {
        setState(() {
          _validationMessage = 'Geçersiz QR kod - Askı bulunamadı';
          _isProcessing = false;
        });
        return;
      }

      if (aski.status == AskiStatus.taken) {
        setState(() {
          _validationMessage = 'Bu askı zaten tamamlanmış';
          _isProcessing = false;
        });
        return;
      }

      // Kurumsal kullanıcının bu ürünü verme yetkisi var mı kontrol et
      if (_currentUser?.companyName != corporateName) {
        setState(() {
          _validationMessage = 'Bu ürün sizin firmanıza ait değil';
          _isProcessing = false;
        });
        return;
      }

      // Başarılı doğrulama
      await _showValidationSuccessDialog(aski, productName, corporateName);
    } catch (e) {
      setState(() {
        _validationMessage = 'QR kod okunamadı veya geçersiz format';
        _isProcessing = false;
      });
    }
  }

  Future<void> _showValidationSuccessDialog(
    AskiModel aski,
    String productName,
    String corporateName,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('QR Kod Doğrulandı'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ürün: $productName'),
                Text('Firma: $corporateName'),
                Text('Askı Sahibi: ${aski.donorUserName}'),
                const SizedBox(height: 16),
                const Text(
                  'Ürünü teslim etmek istediğinizi onaylıyor musunuz?',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ürünü Teslim Et'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _completeDelivery(aski);
    } else {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _completeDelivery(AskiModel aski) async {
    try {
      // Askıyı tamamla
      await _askiService.completeAski(aski.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürün başarıyla teslim edildi!'),
            backgroundColor: Colors.green,
          ),
        );

        // Ana sayfaya dön
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
        ),
      ),
    );
  }
}
