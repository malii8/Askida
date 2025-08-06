import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _codeController = TextEditingController();
  final PostService _postService = PostService();
  final UserService _userService = UserService();
  bool _isLoading = false;
  MobileScannerController? _scannerController;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });

        // Kurumsal kullanıcı kontrolü
        if (user?.userType == UserType.corporate) {
          _showCorporateUserWarning();
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showCorporateUserWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.business, color: Colors.blue),
                SizedBox(width: 8),
                Text('Kurumsal Kullanıcı'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurumsal kullanıcılar ürün talep edemez.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• QR kod tarama özelliği bireysel kullanıcılar içindir'),
                Text('• Kurumsal kullanıcılar sadece ürün bırakabilir'),
                Text('• Ana sayfadan "Askı Oluştur" butonunu kullanın'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Dialog'u kapat
                  Navigator.of(context).pop(); // QR ekranından çık
                },
                child: const Text('Anladım'),
              ),
            ],
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _startCameraScanning() async {
    try {
      // Web platformunda kamera kontrolü
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web tarayıcısında kamera erişimi sağlanıyor...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      _scannerController = MobileScannerController();

      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('QR Kod Tara'),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    // Kamera tarama alanı
                    Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: (BarcodeCapture capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final String code = barcodes.first.rawValue ?? '';
                              if (code.isNotEmpty) {
                                Navigator.of(dialogContext).pop(code);
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      kIsWeb
                          ? 'QR kodunu kameraya gösterin\n(Web kamera erişimi gereklidir)'
                          : 'QR kodunu kameraya gösterin',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('İptal'),
                ),
              ],
            );
          },
        );

        // Eğer QR kod okunduysa
        if (result != null && result.isNotEmpty) {
          _codeController.text = result;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('QR kod okundu: $result'),
                backgroundColor: Colors.green,
              ),
            );
          }
          // Otomatik olarak ürünü talep et
          await _claimByCode();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kamera hatası: $e\nManuel kod girişi kullanabilirsiniz.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _scannerController?.dispose();
      _scannerController = null;
    }
  }

  Future<void> _claimByCode() async {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kod girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Kullanıcı bilgileri bulunamadı');
      }

      // Kurumsal kullanıcıların ürün almasını engelle
      if (currentUser.userType == UserType.corporate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kurumsal hesaplar ürün alamaz, sadece verebilir'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 6 haneli kod kontrolü
      String code = _codeController.text.trim();
      bool success;

      if (code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code)) {
        // 6 haneli sayısal kod - claim code
        success = await _postService.claimProductByCode(code, currentUser.uid);
      } else {
        // QR kod olarak dene
        success = await _postService.claimProductByQR(code, currentUser.uid);
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Ürün başarıyla teslim alındı!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kurumsal kullanıcı kontrolü
    if (_currentUser?.userType == UserType.corporate) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Erişim Engellendi'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business, size: 80, color: Colors.blue),
                SizedBox(height: 24),
                Text(
                  'Kurumsal Kullanıcı',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'QR kod tarama özelliği sadece bireysel kullanıcılar içindir.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Kurumsal kullanıcılar sadece ürün bırakabilir.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Teslim Al'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Ürün Teslim Al',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'QR kod veya 6 haneli kodu girin',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Kod girişi
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'QR Kod veya 6 Haneli Kod',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
                hintText: 'Örn: 123456 veya ASKIDA_...',
              ),
              inputFormatters: [
                // Büyük harf dönüşümü
                TextInputFormatter.withFunction((oldValue, newValue) {
                  return TextEditingValue(
                    text: newValue.text.toUpperCase(),
                    selection: newValue.selection,
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),

            // QR Tarama Butonu
            OutlinedButton.icon(
              onPressed: _startCameraScanning,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                kIsWeb ? 'Kamera ile QR Tara (Web)' : 'Kamera ile QR Tara',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Teslim Al butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _claimByCode,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.shopping_bag),
              label: Text(
                _isLoading ? 'İşlem yapılıyor...' : 'Ürünü Teslim Al',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),

            // Bilgi kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Nasıl Kullanılır?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Askıya ürün bırakan kişiden kodu alın\n'
                      '• 6 haneli sayısal kod veya QR kod stringini girin\n'
                      '• Kamera butonu ile QR tarama deneyin\n'
                      '• "Ürünü Teslim Al" butonuna basın\n'
                      '• Başarılı olduğunda ürün size teslim edilir',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



