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
        SnackBar(
          content: Text('Email ve şifre alanları boş olamaz'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
          SnackBar(
            content: const Text('Giriş başarılı!'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
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
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
        SnackBar(
          content: const Text('Lütfen tüm alanları doldurun'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Şifreler eşleşmiyor'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (_selectedUserType == UserType.corporate &&
        _organizationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kurum adı gereklidir'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
            SnackBar(
              content: const Text('Kayıt başarılı!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
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
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Askıda',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paylaşım ve yardımlaşma platformu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Login/Register Formu
              if (_isLogin) ...[
                // Login Form
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.email,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.lock,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child:
                        _isLoading
                            ? CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onPrimary,
                            )
                            : Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                  ),
                ),
              ] else ...[
                // Register Form
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.person,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.email,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.lock,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Şifre Tekrarı',
                    labelStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                    ),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.lock_outline,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                    ),
                  ),
                  obscureText: true,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // User Type Selection
                Text(
                  'Kullanıcı Türü:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<UserType>(
                        title: Text(
                          'Bireysel',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        value: UserType.individual,
                        groupValue: _selectedUserType,
                        onChanged: (UserType? value) {
                          setState(() {
                            _selectedUserType = value;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<UserType>(
                        title: Text(
                          'Kurumsal',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        value: UserType.corporate,
                        groupValue: _selectedUserType,
                        onChanged: (UserType? value) {
                          setState(() {
                            _selectedUserType = value;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                // Organization name field (only for corporate users)
                if (_selectedUserType == UserType.corporate) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _organizationController,
                    decoration: InputDecoration(
                      labelText: 'Kurum Adı',
                      labelStyle: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                      ),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.business,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha((255 * 0.6).round()),
                      ),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child:
                        _isLoading
                            ? CircularProgressIndicator(
                              color: Theme.of(context).colorScheme.onSecondary,
                            )
                            : Text(
                              'Kayıt Ol',
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                              ),
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
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
