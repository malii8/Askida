import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/user_service.dart';
import '../services/aski_service.dart';
import '../models/user_model.dart';

class QRValidatorScreen extends StatefulWidget {
  const QRValidatorScreen({super.key});

  @override
  State<QRValidatorScreen> createState() => _QRValidatorScreenState();
}

class _QRValidatorScreenState extends State<QRValidatorScreen> {
  final UserService _userService = UserService();
  final AskiService _askiService = AskiService();
  bool _isScanning = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
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
                  Expanded(
                    child:
                        _isScanning
                            ? _buildScannerView()
                            : const Center(child: Text('QR kod taranıyor...')),
                  ),
                ],
              ),
    );
  }

  Widget _buildScannerView() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'QR Kod Tarayıcısı Buraya Gelecek',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'QR kodunu kamera ile okutun',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Test button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _simulateQRScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Test QR Kodu Tara'),
            ),
          ),
        ],
      ),
    );
  }

  void _simulateQRScan() {
    // Test için örnek QR data - Gerçek QR kodundan gelecek
    final testQRData = {
      'type': 'askida_product',
      'askiId': 'test_aski_123',
      'productId': 'test_product_456',
      'productName': 'Test Ürün',
      'corporateId': 'test_corporate_789',
      'corporateName': 'Test Kurum',
      'donorUserId': 'test_donor_user',
      'donorName': 'Test Kullanıcı',
      'askiDate': DateTime.now().toIso8601String(),
    };

    _processQRCode(jsonEncode(testQRData));
  }

  void _processQRCode(String qrCode) {
    try {
      final qrData = jsonDecode(qrCode) as Map<String, dynamic>;

      // QR kod formatını kontrol et
      if (qrData['type'] != 'askida_product') {
        _showErrorDialog('Geçersiz QR kod formatı');
        return;
      }

      _showQRResult(qrData);
    } catch (e) {
      _showErrorDialog('QR kod okunamadı: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Hata'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restartScanning();
                },
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  void _showQRResult(Map<String, dynamic> qrData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.qr_code, color: Colors.blue),
                SizedBox(width: 8),
                Text('QR Kod Bilgileri'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Ürün', qrData['productName'] ?? 'Bilinmiyor'),
                _buildInfoRow('Kurum', qrData['corporateName'] ?? 'Bilinmiyor'),
                _buildInfoRow(
                  'Bağışlayan',
                  qrData['donorName'] ?? 'Bilinmiyor',
                ),
                _buildInfoRow('Askı Tarihi', _formatDate(qrData['askiDate'])),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ürün teslim edilmeye hazır!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restartScanning();
                },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => _confirmDelivery(qrData),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ürünü Teslim Et'),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _confirmDelivery(Map<String, dynamic> qrData) async {
    Navigator.pop(context); // Dialog'u kapat

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Ürün teslim ediliyor...'),
              ],
            ),
          ),
    );

    try {
      // Askıyı teslim et
      final success = await _askiService.takeAski(
        askiId: qrData['askiId'],
        takenByUserId: 'delivered_to_customer', // Özel işaret
        takenByUserName: 'Kurumsal Teslim',
      );

      if (!mounted) return;
      Navigator.pop(context); // Loading dialog'u kapat

      if (success) {
        _showSuccessDialog(qrData['productName'] ?? 'Ürün');
      } else {
        _showErrorDialog('Ürün teslim edilirken hata oluştu');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Loading dialog'u kapat
      _showErrorDialog('Teslim hatası: $e');
    }
  }

  void _showSuccessDialog(String productName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Teslim Başarılı'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$productName başarıyla teslim edildi!'),
                const SizedBox(height: 16),
                const Text(
                  'Ürün askıdan alınarak müşteriye teslim edilmiştir.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _restartScanning();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }

  void _restartScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Bilinmiyor';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Az önce';
      }
    } catch (e) {
      return 'Bilinmiyor';
    }
  }
}



