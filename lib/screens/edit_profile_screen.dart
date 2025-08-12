import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Resim seçmek için
import 'dart:io'; // File sınıfı için
import '../services/user_service.dart';
import '../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserService _userService = UserService();
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _organizationNameController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _taxNumberController;
  late final TextEditingController
  _profileImageUrlController; // Add controller for profile image URL

  UserModel? _currentUser;
  bool _isLoading = true;
  String? _profileImageUrl; // Mevcut profil resmi URL'si
  File? _selectedImage; // Seçilen yeni resim dosyası

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _organizationNameController = TextEditingController();
    _companyNameController = TextEditingController();
    _taxNumberController = TextEditingController();
    _profileImageUrlController =
        TextEditingController(); // Initialize controller
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _organizationNameController.dispose();
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _profileImageUrlController.dispose(); // Dispose controller
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          if (user != null) {
            _fullNameController.text = user.fullName;
            _phoneController.text = user.phone ?? '';
            _organizationNameController.text = user.organizationName ?? '';
            _companyNameController.text = user.companyName ?? '';
            _taxNumberController.text = user.taxNumber ?? '';
            _profileImageUrl = user.profileImageUrl;
            _profileImageUrlController.text =
                user.profileImageUrl ?? ''; // Set initial value
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcı bilgileri yüklenirken hata: $e'),
            backgroundColor:
                Theme.of(context).colorScheme.error, // Use error color
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _profileImageUrlController.text = ''; // Clear URL if image is picked
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? newProfileImageUrl;
      if (_selectedImage != null) {
        // Resmi Firebase Storage'a yükle
        newProfileImageUrl = await _userService.uploadProfileImage(
          _currentUser!.uid,
          _selectedImage!,
        );
      } else if (_profileImageUrlController.text.isNotEmpty) {
        newProfileImageUrl = _profileImageUrlController.text;
      } else {
        newProfileImageUrl = null;
      }

      final updatedUser = _currentUser!.copyWith(
        fullName: _fullNameController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        organizationName:
            _organizationNameController.text.isEmpty
                ? null
                : _organizationNameController.text,
        companyName:
            _companyNameController.text.isEmpty
                ? null
                : _companyNameController.text,
        taxNumber:
            _taxNumberController.text.isEmpty
                ? null
                : _taxNumberController.text,
        profileImageUrl: newProfileImageUrl, // Güncellenmiş URL'yi ata
      );

      await _userService.updateUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil başarıyla güncellendi!'),
            backgroundColor:
                Theme.of(context).colorScheme.primary, // Use primary color
          ),
        );
        Navigator.of(context).pop(); // Profil ekranına geri dön
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profil güncellenirken hata: $e'),
            backgroundColor:
                Theme.of(context).colorScheme.error, // Use error color
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
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor:
                            Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest, // Use surfaceContainerHighest
                        backgroundImage:
                            _selectedImage != null
                                ? FileImage(
                                  _selectedImage!,
                                ) // Yeni seçilen resim
                                : (_profileImageUrl != null &&
                                        _profileImageUrl!.isNotEmpty
                                    ? NetworkImage(
                                      _profileImageUrl!,
                                    ) // Mevcut resim
                                    : null), // Resim yoksa null
                        child:
                            _selectedImage == null &&
                                    (_profileImageUrl == null ||
                                        _profileImageUrl!.isEmpty)
                                ? Icon(
                                  Icons.camera_alt,
                                  color:
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant, // Use onSurfaceVariant for icon color
                                  size: 40,
                                )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller:
                          _profileImageUrlController, // Add this TextFormField
                      decoration: InputDecoration(
                        labelText: 'Profil Resmi URL\'si',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.7).round()),
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.link,
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.6).round()),
                        ),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Tam Ad',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.7).round()),
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.6).round()),
                        ),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Telefon',
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.7).round()),
                        ),
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: Theme.of(context).colorScheme.onSurface
                              .withAlpha((255 * 0.6).round()),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (_currentUser?.userType == UserType.corporate)
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _organizationNameController,
                            decoration: InputDecoration(
                              labelText: 'Kurum Adı',
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.7).round()),
                              ),
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.business,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.6).round()),
                              ),
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _companyNameController,
                            decoration: InputDecoration(
                              labelText: 'Şirket Adı',
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.7).round()),
                              ),
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.apartment,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.6).round()),
                              ),
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _taxNumberController,
                            decoration: InputDecoration(
                              labelText: 'Vergi Numarası',
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.7).round()),
                              ),
                              border: const OutlineInputBorder(),
                              prefixIcon: Icon(
                                Icons.receipt,
                                color: Theme.of(context).colorScheme.onSurface
                                    .withAlpha((255 * 0.6).round()),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Profili Kaydet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
    );
  }
}
