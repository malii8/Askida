import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'firebase_options.dart';
import 'screens/create_post_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/notifications_screen.dart';

import 'screens/corporate_menu_screen.dart';
import 'screens/corporate_products_screen.dart';
import 'screens/corporate_products_list_screen.dart';
import 'screens/qr_validator_screen.dart';
import 'screens/qr_display_screen.dart';
import 'services/user_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;

  try {
    // Firebase'i başlat
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Firebase Auth'u test et
    FirebaseAuth.instance.authStateChanges().listen((user) {
      developer.log(
        'Auth state changed: ${user?.uid ?? 'no user'}',
        name: 'main',
      );
    });

    developer.log('Firebase initialized successfully', name: 'main');
    firebaseInitialized = true;
  } catch (e, stackTrace) {
    developer.log('Firebase initialization failed: $e', name: 'main');
    developer.log('Stack trace: $stackTrace', name: 'main');
    firebaseInitialized = false;
  }

  runApp(MainApp(firebaseEnabled: firebaseInitialized));
}

class MainApp extends StatelessWidget {
  final bool firebaseEnabled;

  const MainApp({super.key, this.firebaseEnabled = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Askıda App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child!,
        );
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/createPost') {
          return MaterialPageRoute(
            builder: (context) => const CreatePostScreen(),
          );
        }

        if (settings.name == '/settings') {
          return MaterialPageRoute(
            builder: (context) => const SettingsScreen(),
          );
        }
        if (settings.name == '/Gösterge Paneli') {
          return MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          );
        }

        if (settings.name == '/corporateMenu') {
          return MaterialPageRoute(
            builder: (context) => const CorporateMenuScreen(),
          );
        }
        if (settings.name == '/corporateProducts') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder:
                (context) => CorporateProductsScreen(
                  corporateId: args?['corporateId'] as String?,
                ),
          );
        }
        if (settings.name == '/qrValidator') {
          return MaterialPageRoute(
            builder: (context) => const QRValidatorScreen(),
          );
        }
        if (settings.name == '/corporateProductsList') {
          return MaterialPageRoute(
            builder: (context) => const CorporateProductsListScreen(),
          );
        }
        if (settings.name == '/qrDisplay') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return MaterialPageRoute(
              builder:
                  (context) => QRDisplayScreen(
                    askiId: args['askiId'] as String,
                    productName: args['productName'] as String,
                    corporateName: args['corporateName'] as String,
                    corporateId: args['corporateId'] as String,
                    applicantUserId:
                        args['applicantUserId'] as String?, // Yeni eklendi
                  ),
            );
          }
        }
        if (settings.name == '/feed') {
          return MaterialPageRoute(builder: (context) => const FeedScreen());
        }
        if (settings.name == '/notifications') {
          return MaterialPageRoute(
            builder: (context) => const NotificationsScreen(),
          );
        }
        if (settings.name == '/profile') {
          return MaterialPageRoute(builder: (context) => const ProfileScreen());
        }
        return null;
      },
      home: firebaseEnabled ? const AuthWrapper() : const FirebaseErrorScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Kullanıcı varsa MainAppScreen, yoksa AuthScreen - loading yok
        if (snapshot.hasData && snapshot.data != null) {
          return const MainAppScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Askıda\'ya Hoş Geldiniz',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Yükleniyor...',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Bir hata oluştu'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class FirebaseErrorScreen extends StatelessWidget {
  const FirebaseErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Firebase Bağlantı Hatası'),
            const SizedBox(height: 8),
            const Text('Uygulama Firebase olmadan çalışamıyor.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Uygulamayı yeniden başlat
                main();
              },
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _currentIndex = 0;
  final UserService _userService = UserService();
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    // Cleanup when widget is disposed
    _userModel = null;
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      // Önce current user'ı kontrol et
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        // Kullanıcı yoksa auth screen'e yönlendir
        if (mounted) {
          await FirebaseAuth.instance.signOut();
        }
        return;
      }

      final userModel = await _userService.getCurrentUser();

      // Eğer kullanıcı authenticated ama Firestore'da kayıt yoksa
      if (userModel == null) {
        // Temel kullanıcı profili oluştur
        final newUserModel = UserModel(
          uid: currentUser.uid,
          email: currentUser.email ?? '',
          fullName: currentUser.displayName ?? 'Kullanıcı',
          userType: UserType.individual,
          isApproved: true, // İlk kullanıcılar için otomatik onay
          createdAt: DateTime.now(),
        );

        await _userService.createUser(newUserModel);

        if (mounted) {
          setState(() {
            _userModel = newUserModel;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _userModel = userModel;
        });
      }
    } catch (e) {
      developer.log('Error loading user data: $e', name: 'MainAppScreen');
      // Sadece kritik hatalar için çıkış yap
      if (e.toString().contains('permission-denied') ||
          e.toString().contains('unauthenticated')) {
        if (mounted) {
          await FirebaseAuth.instance.signOut();
        }
      } else {
        // Diğer hatalarda kullanıcıyı çıkış yapmaya zorlamayalım
        developer.log(
          'Non-critical error in _loadUserData, continuing...',
          name: 'MainAppScreen',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens =
        _userModel?.userType == UserType.corporate
            ? [
              const FeedScreen(),
              const DashboardScreen(),
              CorporateProductsScreen(corporateId: _userModel?.uid),
              const ProfileScreen(),
            ]
            : [
              const FeedScreen(),
              const DashboardScreen(),
              const ProfileScreen(),
            ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Kurumsal kullanıcı için index ayarlaması
          if (_userModel?.userType == UserType.corporate) {
            setState(() {
              _currentIndex = index;
            });
          } else {
            // Bireysel kullanıcılar için - Ürün Yönetimi sekmesi yok
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey.shade600,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Gösterge Paneli',
          ),
          if (_userModel?.userType == UserType.corporate)
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_outlined),
              activeIcon: Icon(Icons.inventory),
              label: 'Ürün Yönetimi',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton:
          _userModel?.isApproved == true ? _buildFloatingActionButtons() : null,
    );
  }

  Widget? _buildFloatingActionButtons() {
    // Kullanıcı onaylanmamışsa hiçbir buton gösterme
    if (_userModel?.isApproved != true) return null;

    if (_userModel?.userType == UserType.corporate) {
      // Kurumsal kullanıcılar için - sadece Ana Sayfa'da butonları göster
      if (_currentIndex != 0) return null;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: "qr_scanner",
            onPressed: () {
              Navigator.pushNamed(context, '/qrValidator');
            },
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: "create_post",
            onPressed: () async {
              final navigator = Navigator.of(context);

              await navigator.push(
                MaterialPageRoute(
                  builder: (context) => const CreatePostScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Askı Oluştur'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        ],
      );
    } else {
      // Bireysel kullanıcılar için - sadece Askı Oluştur
      if (_currentIndex != 0) return null;

      return FloatingActionButton.extended(
        heroTag: "create_post",
        onPressed: () async {
          final navigator = Navigator.of(context);

          await navigator.push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Askı Oluştur'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      );
    }
  }
}
