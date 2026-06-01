import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../screens/auth/login_screen.dart';
import '../../../../services/user_service.dart';
import '../../../../models/app_models.dart';

class TrainerProfileScreen extends StatefulWidget {
  const TrainerProfileScreen({super.key});

  @override
  State<TrainerProfileScreen> createState() => _TrainerProfileScreenState();
}

class _TrainerProfileScreenState extends State<TrainerProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _bankAccountController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
      const storage = FlutterSecureStorage();
      final phone = await storage.read(key: 'userPhone');
      if (phone != null) {
        final userService = UserService();
        final user = await userService.getUserByPhone(phone);
        if (mounted) {
          setState(() {
            _currentUser = user;
            if (user != null) {
              _nameController.text = user.name;
              _bankNameController.text = user.bankName;
              _bankAccountController.text = user.bankAccount;
              _ifscController.text = user.ifscCode;
              _upiController.text = user.upiId;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_currentUser == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final updatedUser = UserModel(
        id: _currentUser!.id,
        name: _nameController.text.trim(),
        phoneNumber: _currentUser!.phoneNumber,
        role: _currentUser!.role,
        profileImageUrl: _currentUser!.profileImageUrl,
        isBlocked: _currentUser!.isBlocked,
        preferredLanguage: _currentUser!.preferredLanguage,
        bankName: _bankNameController.text.trim(),
        bankAccount: _bankAccountController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        upiId: _upiController.text.trim(),
      );

      await UserService().updateUserProfile(updatedUser);

      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account details updated successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  Future<void> _pickAndCropImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      
      if (pickedFile == null) return;

      debugPrint('Picking image from: ${pickedFile.path}');

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
          ),
        ],
      );

      if (croppedFile != null) {
        debugPrint('Image cropped: ${croppedFile.path}');
        _uploadProfileImage(File(croppedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _uploadProfileImage(File file) async {
    if (_currentUser == null) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${_currentUser!.id}.jpg');
          
      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      
      final updatedUser = UserModel(
        id: _currentUser!.id,
        name: _nameController.text.trim(),
        phoneNumber: _currentUser!.phoneNumber,
        role: _currentUser!.role,
        profileImageUrl: downloadUrl,
        isBlocked: _currentUser!.isBlocked,
        preferredLanguage: _currentUser!.preferredLanguage,
        bankName: _bankNameController.text.trim(),
        bankAccount: _bankAccountController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        upiId: _upiController.text.trim(),
      );
      
      await UserService().updateUserProfile(updatedUser);
      
      if (mounted) {
        setState(() {
          _currentUser = updatedUser;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text('Profile', style: AppTextStyles.headlineLarge),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // Avatar
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Stack(
                    children: [
                      Container(
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppGradients.primary,
                          boxShadow: AppShadows.elevated,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                            child: ClipOval(
                              child: _currentUser?.profileImageUrl != null && _currentUser!.profileImageUrl.isNotEmpty
                                  ? Image.network(
                                      _currentUser!.profileImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(child: Text('👨‍🏫', style: TextStyle(fontSize: 44))),
                                    )
                                  : Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndCropImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: AppShadows.elevated,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Text(_currentUser?.name ?? (_isLoading ? 'Loading...' : 'Trainer'), style: AppTextStyles.headlineMedium),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_currentUser?.role == 'trainer' ? 'Certified Trainer' : 'Instructor', style: AppTextStyles.bodyMedium),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Form
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: _buildTextField('Full Name', _nameController),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: _buildTextField('Phone Number', TextEditingController(text: _currentUser?.phoneNumber != null ? '+91 ${_currentUser!.phoneNumber}' : ''), readOnly: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 425),
                child: _buildTextField('Bank Name', _bankNameController, hint: 'e.g. SBI, HDFC, ICICI'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: _buildTextField('Bank Account Number', _bankAccountController, hint: 'Enter account number'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                child: _buildTextField('IFSC Code', _ifscController, hint: 'Enter IFSC code'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 525),
                child: _buildTextField('UPI ID (Optional)', _upiController, hint: 'e.g. username@upi'),
              ),

              const SizedBox(height: AppSpacing.huge),
              FadeSlideIn(
                delay: const Duration(milliseconds: 550),
                child: _isSaving 
                  ? const CircularProgressIndicator()
                  : GradientButton(
                      text: 'Save Changes',
                      onPressed: _saveChanges,
                      borderRadius: AppRadius.pill,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: TextButton(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    
                    // Clear login state
                    const storage = FlutterSecureStorage();
                    await storage.delete(key: 'isLoggedIn');
                    await storage.delete(key: 'role');
                    await storage.delete(key: 'userPhone');
                    await storage.delete(key: 'userId');
                    UserService.setCachedUserId(null);

                    if (!context.mounted) return;

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  child: Text('Logout', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
