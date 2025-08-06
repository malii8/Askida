import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  UserType? _selectedUserType;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _organizationController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _userService = UserService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Controller'ları temizle (çıkış sonrası için)
    // initState'de setState yapmak yerine direkt değerleri set et
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _nameController.clear();
    _organizationController.clear();
    _isLogin = true;
    _isLoading = false;
    _selectedUserType = null;
  }

  void _clearForm() {
    if (!mounted) return; // Widget mounted değilse işlem yapma

    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _nameController.clear();
    _organizationController.clear();

    if (mounted) {
      // setState'den önce bir kez daha kontrol et
      setState(() {
        _isLogin = true;
        _isLoading = false;
        _selectedUserType = null;
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email ve şifre alanları boş olamaz'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Giriş başarılı, formu temizle
      if (mounted) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Giriş başarılı!'),
            backgroundColor: Colors.green,
          ),
        );
        // Firebase auth state değişikliği otomatik olarak ana sayfaya yönlendirecek
        // Manuel navigation kaldırıldı
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu';
      switch (e.code) {
        case 'user-not-found':
          message = 'Bu email ile kayıtlı kullanıcı bulunamadı';
          break;
        case 'wrong-password':
          message = 'Hatalı şifre';
          break;
        case 'invalid-email':
          message = 'Geçersiz email formatı';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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

  Future<void> _register() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _confirmPasswordController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _selectedUserType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm alanları doldurun'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Şifreler eşleşmiyor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedUserType == UserType.corporate &&
        _organizationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kurum adı gereklidir'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: _emailController.text.trim(),
          fullName: _nameController.text.trim(),
          userType: _selectedUserType!,
          organizationName:
              _selectedUserType == UserType.corporate
                  ? _organizationController.text.trim()
                  : null,
          createdAt: DateTime.now(),
        );

        await _userService.createUser(userModel);

        if (mounted) {
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu';
      switch (e.code) {
        case 'weak-password':
          message = 'Şifre çok zayıf';
          break;
        case 'email-already-in-use':
          message = 'Bu email zaten kullanımda';
          break;
        case 'invalid-email':
          message = 'Geçersiz email formatı';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo veya Başlık
              Icon(
                Icons.shopping_basket,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Askıda',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paylaşım ve yardımlaşma platformu',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Login/Register Formu
              if (_isLogin) ...[
                // Login Form
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Giriş Yap',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ),
              ] else ...[
                // Register Form
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifre Tekrarı',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),

                // User Type Selection
                const Text(
                  'Kullanıcı Türü:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<UserType>(
                        title: const Text('Bireysel'),
                        value: UserType.individual,
                        groupValue: _selectedUserType,
                        onChanged: (UserType? value) {
                          setState(() {
                            _selectedUserType = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<UserType>(
                        title: const Text('Kurumsal'),
                        value: UserType.corporate,
                        groupValue: _selectedUserType,
                        onChanged: (UserType? value) {
                          setState(() {
                            _selectedUserType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                // Organization name field (only for corporate users)
                if (_selectedUserType == UserType.corporate) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _organizationController,
                    decoration: const InputDecoration(
                      labelText: 'Kurum Adı',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Kayıt Ol',
                              style: TextStyle(fontSize: 16),
                            ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Geçiş Butonu
              TextButton(
                onPressed: () {
                  if (mounted) {
                    // Sadece form alanlarını temizle, giriş durumunu değiştir
                    _emailController.clear();
                    _passwordController.clear();
                    _confirmPasswordController.clear();
                    _nameController.clear();
                    _organizationController.clear();

                    setState(() {
                      _isLogin = !_isLogin;
                      _selectedUserType = null;
                      _isLoading = false;
                    });
                  }
                },
                child: Text(
                  _isLogin
                      ? 'Hesabınız yok mu? Kayıt olun'
                      : 'Zaten hesabınız var mı? Giriş yapın',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Controller'ları güvenli şekilde dispose et
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _organizationController.dispose();
    super.dispose();
  }
}



