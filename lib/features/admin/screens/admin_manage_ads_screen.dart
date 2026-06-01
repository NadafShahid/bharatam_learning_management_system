import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../services/ad_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AdminManageAdsScreen extends StatefulWidget {
  const AdminManageAdsScreen({super.key});

  @override
  State<AdminManageAdsScreen> createState() => _AdminManageAdsScreenState();
}

class _AdminManageAdsScreenState extends State<AdminManageAdsScreen> {
  final AdService _adService = AdService();
  bool _isLoading = true;
  bool _isUploadingAd = false;
  List<Advertisement> _ads = [];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    setState(() => _isLoading = true);
    try {
      final ads = await _adService.getAdvertisements();
      if (mounted) {
        setState(() {
          _ads = ads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Manage Advertisements', style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAds,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: GradientButton(
                        text: 'Add New Advertisement',
                        icon: Icons.add_photo_alternate_rounded,
                        isLoading: _isUploadingAd,
                        onPressed: () => _pickAndUploadAdBanner(),
                      ),
                    ),
                  ),
                  if (_ads.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No active advertisements found.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final ad = _ads[index];
                            return _AdCard(
                              ad: ad,
                              onDelete: () => _deleteAd(ad.id),
                            );
                          },
                          childCount: _ads.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
                ],
              ),
            ),
    );
  }

  Future<void> _pickAndUploadAdBanner() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image != null) {
      HapticFeedback.mediumImpact();
      setState(() => _isUploadingAd = true);
      try {
        final file = File(image.path);
        final fileName = 'ad_banner_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child('advertisements/$fileName');

        await ref.putFile(file);
        final url = await ref.getDownloadURL();

        final ad = Advertisement(
          id: '',
          imageUrl: url,
          title: '',
          subtitle: '',
          badgeText: '',
        );
        await _adService.addAdvertisement(ad);
        
        if (mounted) {
          _loadAds();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Advertisement added successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload advertisement.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingAd = false);
        }
      }
    }
  }

  Future<void> _deleteAd(String id) async {
    await _adService.deleteAdvertisement(id);
    _loadAds();
  }
}

class _AdCard extends StatelessWidget {
  final Advertisement ad;
  final VoidCallback onDelete;

  const _AdCard({required this.ad, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Image.network(
              ad.imageUrl,
              width: 80,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 60,
                color: AppColors.background,
                child: const Icon(Icons.broken_image_rounded),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ad.title.isNotEmpty) Text(ad.title, style: AppTextStyles.titleMedium),
                if (ad.subtitle.isNotEmpty) Text(ad.subtitle, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (ad.title.isEmpty && ad.subtitle.isEmpty) const Text('Advertisement Banner', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
