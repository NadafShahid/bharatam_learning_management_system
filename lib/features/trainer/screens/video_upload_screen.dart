import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../widgets/status_badge.dart';
import '../../../../widgets/purchase_sheets.dart';
import '../../../../widgets/commerce_widgets.dart';
import '../../../../models/app_models.dart';
import '../../../../services/course_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';

class VideoUploadScreen extends StatefulWidget {
  final CourseModel? course;
  final bool initialIsPdf;

  const VideoUploadScreen({super.key, this.course, this.initialIsPdf = false});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  final int _usedUploads = DummyData.trainerVideoCount;
  final int _freeLimit = 5;
  final _courseService = CourseService();
  final _titleController = TextEditingController();
  final _storageUrlController = TextEditingController();
  bool _isFree = false;
  late bool _isPdf;
  bool _isUploading = false;
  File? _selectedPdfFile;
  File? _selectedVideoFile;
  File? _selectedThumbnailFile;

  // ── Reorder state ──────────────────────────────────────────────────
  List<VideoModel> _reorderVideos = [];
  bool _isLoadingVideos = false;
  bool _isSavingOrder = false;
  bool _orderChanged = false;
  // ───────────────────────────────────────────────────────────────────

  bool get _isLimitReached => _usedUploads >= _freeLimit;

  @override
  void initState() {
    super.initState();
    _isPdf = widget.initialIsPdf;
    if (widget.course != null) {
      _loadExistingVideos();
    }
  }

  // ── Load existing videos / PDFs for the reorder list ───────────────
  Future<void> _loadExistingVideos() async {
    if (widget.course == null) return;
    setState(() => _isLoadingVideos = true);
    try {
      final videos = await _courseService.getCourseVideos(
        widget.course!.id,
        isPdf: _isPdf,
      );
      if (mounted) {
        setState(() {
          _reorderVideos = videos;
          _isLoadingVideos = false;
          _orderChanged = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVideos = false);
    }
  }

  // Called when tab (Video / PDF) changes so we reload the correct list
  void _onContentTypeChanged(bool newIsPdf) {
    setState(() {
      _isPdf = newIsPdf;
      _orderChanged = false;
      _titleController.clear();
      _storageUrlController.clear();
      _selectedPdfFile = null;
      _selectedVideoFile = null;
      _selectedThumbnailFile = null;
    });
    if (widget.course != null) _loadExistingVideos();
  }

  // ── Save re-ordered sequence to Firestore ───────────────────────────
  Future<void> _saveOrder() async {
    if (widget.course == null || _reorderVideos.isEmpty) return;
    setState(() => _isSavingOrder = true);
    try {
      await _courseService.updateVideoOrder(
        courseId: widget.course!.id,
        orderedVideoIds: _reorderVideos.map((v) => v.id).toList(),
        contentType: _isPdf ? CourseContentType.pdf : CourseContentType.video,
      );
      if (mounted) {
        setState(() {
          _orderChanged = false;
          _isSavingOrder = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video order saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save order: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
  // ───────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _titleController.dispose();
    _storageUrlController.dispose();
    super.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(widget.course == null ? 'Upload Video' : widget.course!.title, style: AppTextStyles.headlineLarge),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              // Upload quota tracker
              FadeSlideIn(
                delay: const Duration(milliseconds: 130),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _isLimitReached 
                        ? AppColors.warning.withValues(alpha: 0.08) 
                        : AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: _isLimitReached 
                          ? AppColors.warning.withValues(alpha: 0.3) 
                          : AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: (_isLimitReached ? AppColors.warning : AppColors.success).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(
                          _isLimitReached ? Icons.warning_rounded : Icons.cloud_done_rounded,
                          color: _isLimitReached ? AppColors.warning : AppColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Uploads: $_usedUploads / $_freeLimit',
                              style: AppTextStyles.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _usedUploads / _freeLimit,
                                backgroundColor: AppColors.divider,
                                color: _isLimitReached ? AppColors.warning : AppColors.success,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              // If limit reached, show upgrade card
              if (_isLimitReached) ...[
                FadeSlideIn(
                  delay: const Duration(milliseconds: 170),
                  child: UpgradePlanCard(
                    title: 'Upload Limit Reached',
                    description: 'You\'ve used all $_freeLimit free uploads. Choose a plan to continue uploading new content.',
                    ctaText: 'View Upload Plans',
                    icon: Icons.rocket_launch_rounded,
                    gradient: AppGradients.orangeSunset,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const TrainerUploadPlanSheet(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              

              
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _buildTextField(_isPdf ? 'PDF Title' : 'Video Title', 'e.g. Chapter 1: Introduction', controller: _titleController),
              ),
              const SizedBox(height: AppSpacing.lg),

              FadeSlideIn(
                delay: const Duration(milliseconds: 275),
                child: Column(
                  children: [
                    if (_isPdf)
                      _buildFilePicker()
                    else ...[
                      _buildVideoPicker(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildThumbnailPicker(),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Row(
                  children: [
                    Text('Content Type:', style: AppTextStyles.titleMedium),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Video'),
                      selected: !_isPdf,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        _onContentTypeChanged(false);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('PDF'),
                      selected: _isPdf,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        _onContentTypeChanged(true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              FadeSlideIn(
                delay: const Duration(milliseconds: 330),
                child: Row(
                  children: [
                    Text('Access Type:', style: AppTextStyles.titleMedium),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Free Preview'),
                      selected: _isFree,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _isFree = true);
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Paid Only'),
                      selected: !_isFree,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _isFree = false);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 400),
                child: GradientButton(
                  text: _isUploading ? 'Uploading...' : 'Upload',
                  icon: Icons.cloud_upload_rounded,
                  isLoading: _isUploading,
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    if (!_isUploading) _uploadContent();
                  },
                ),
              ),

              // ── Reorder Section ──────────────────────────────────────────
              if (widget.course != null) ...[
                const SizedBox(height: AppSpacing.huge),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isPdf ? 'Reorder PDFs' : 'Reorder Videos',
                          style: AppTextStyles.titleLarge,
                        ),
                      ),
                      if (_orderChanged)
                        GestureDetector(
                          onTap: _isSavingOrder ? null : _saveOrder,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              boxShadow: AppShadows.elevated,
                            ),
                            child: _isSavingOrder
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.save_rounded, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Save Order',
                                        style: AppTextStyles.labelMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 530),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary.withValues(alpha: 0.75)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Long-press and drag ☰ to reorder. Tap "Save Order" to apply.',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary.withValues(alpha: 0.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildReorderList(),
              ],
              // ────────────────────────────────────────────────────────────

              const SizedBox(height: AppSpacing.huge),
              FadeSlideIn(
                delay: const Duration(milliseconds: 550),
                child: Text('Recent Uploads', style: AppTextStyles.titleLarge),
              ),
              const SizedBox(height: AppSpacing.md),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Basics of Sanskrit.mp4', style: AppTextStyles.bodyMedium),
                            Text('Uploaded 2 hours ago', style: AppTextStyles.labelSmall),
                          ],
                        ),
                      ),
                      const StatusBadge(status: BadgeStatus.pending),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reorder list widget ────────────────────────────────────────────
  Widget _buildReorderList() {
    if (_isLoadingVideos) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reorderVideos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Text(
            _isPdf ? 'No PDFs uploaded yet.' : 'No videos uploaded yet.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
          ),
        ),
      );
    }

    // ReorderableListView needs a fixed height; we make it shrink-wrap by
    // setting shrinkWrap + NeverScrollableScrollPhysics inside a Column.
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reorderVideos.length,
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.mediumImpact();
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _reorderVideos.removeAt(oldIndex);
          _reorderVideos.insert(newIndex, item);
          _orderChanged = true;
        });
      },
      itemBuilder: (context, index) {
        final video = _reorderVideos[index];
        return _buildReorderItem(video, index, key: ValueKey(video.id));
      },
    );
  }

  Widget _buildReorderItem(VideoModel video, int index, {required Key key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          // Order number badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content icon
          Icon(
            _isPdf ? Icons.picture_as_pdf_rounded : Icons.play_circle_fill_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.md),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (video.approvalStatus == ApprovalStatus.pending)
                  Text(
                    'Pending approval',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.warning),
                  )
                else if (video.approvalStatus == ApprovalStatus.approved)
                  Text(
                    'Approved',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.drag_handle_rounded,
              color: AppColors.textHint,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
  // ──────────────────────────────────────────────────────────────────

  Widget _buildTextField(String label, String hint, {required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
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

  Widget _buildFilePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PDF File', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final result = await FilePicker.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf'],
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              setState(() {
                if (file.path != null) _selectedPdfFile = File(file.path!);
                _storageUrlController.text = file.path ?? file.name;
                if (_titleController.text.trim().isEmpty) {
                  _titleController.text = file.name.replaceAll('.pdf', '');
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _storageUrlController.text.isEmpty ? 'Tap to select PDF file' : _storageUrlController.text.split('/').last.split('\\').last,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _storageUrlController.text.isEmpty ? AppColors.textHint : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video File', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final result = await FilePicker.pickFiles(
              type: FileType.video,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              setState(() {
                if (file.path != null) _selectedVideoFile = File(file.path!);
                _storageUrlController.text = file.path ?? file.name;
                if (_titleController.text.trim().isEmpty) {
                  _titleController.text = file.name.split('.').first;
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _selectedVideoFile == null ? 'Tap to select Video file' : _selectedVideoFile!.path.split('/').last.split('\\').last,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedVideoFile == null ? AppColors.textHint : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedVideoFile != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedVideoFile = null;
                        _storageUrlController.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video Thumbnail (Optional)', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            final result = await FilePicker.pickFiles(
              type: FileType.image,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              setState(() {
                if (file.path != null) _selectedThumbnailFile = File(file.path!);
              });
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.image_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _selectedThumbnailFile == null ? 'Tap to select Thumbnail image' : _selectedThumbnailFile!.path.split('/').last.split('\\').last,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedThumbnailFile == null ? AppColors.textHint : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedThumbnailFile != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedThumbnailFile = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadContent() async {
    final course = widget.course;
    if (course == null) {
      _showUploadProgressDialog(context);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('Please enter a title.', isError: true);
      return;
    }

    if (_isPdf) {
      if (_selectedPdfFile == null) {
        _showMessage('Please select a PDF file.', isError: true);
        return;
      }
    } else {
      if (_selectedVideoFile == null) {
        _showMessage('Please select a video file.', isError: true);
        return;
      }
    }

    setState(() => _isUploading = true);
    
    String finalStorageUrl = '';
    String finalThumbnailUrl = '';
    double durationMinutes = 0;

    try {
      if (_isPdf && _selectedPdfFile != null) {
        final ref = FirebaseStorage.instance.ref().child('courses/${course.id}/pdfs/${DateTime.now().millisecondsSinceEpoch}_${_selectedPdfFile!.path.split('/').last.split('\\').last}');
        await ref.putFile(_selectedPdfFile!);
        finalStorageUrl = await ref.getDownloadURL();
      } else if (!_isPdf && _selectedVideoFile != null) {
        // Upload video file
        final ref = FirebaseStorage.instance.ref().child('courses/${course.id}/videos/${DateTime.now().millisecondsSinceEpoch}_${_selectedVideoFile!.path.split('/').last.split('\\').last}');
        await ref.putFile(_selectedVideoFile!);
        finalStorageUrl = await ref.getDownloadURL();

        // Upload thumbnail if selected
        if (_selectedThumbnailFile != null) {
          final thumbRef = FirebaseStorage.instance.ref().child('courses/${course.id}/thumbnails/${DateTime.now().millisecondsSinceEpoch}_${_selectedThumbnailFile!.path.split('/').last.split('\\').last}');
          await thumbRef.putFile(_selectedThumbnailFile!);
          finalThumbnailUrl = await thumbRef.getDownloadURL();
        }

        // Auto-extract video duration
        try {
          final controller = VideoPlayerController.file(_selectedVideoFile!);
          await controller.initialize();
          final durationSecs = controller.value.duration.inSeconds;
          if (durationSecs > 0) {
            durationMinutes = durationSecs / 60.0;
          }
          await controller.dispose();
        } catch (ex) {
          debugPrint('Error extracting video duration: $ex');
        }
      }

      await _courseService.uploadCourseContent(
        courseId: course.id,
        title: title,
        contentType: _isPdf ? CourseContentType.pdf : CourseContentType.video,
        storageUrl: finalStorageUrl,
        bunnyVideoId: _isPdf ? '' : finalStorageUrl,
        isFree: _isFree,
        thumbnailUrl: finalThumbnailUrl,
        durationMinutes: durationMinutes,
      );
      if (!mounted) return;
      _showMessage('Content uploaded for admin approval.');
      // Reload the reorder list to include the newly uploaded item
      _titleController.clear();
      _storageUrlController.clear();
      _selectedPdfFile = null;
      _selectedVideoFile = null;
      _selectedThumbnailFile = null;
      await _loadExistingVideos();
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showMessage('Unable to upload: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  void _showUploadProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _UploadProgressDialog(),
    );
  }
}

class _UploadProgressDialog extends StatefulWidget {
  const _UploadProgressDialog();

  @override
  State<_UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<_UploadProgressDialog> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeInOut));
    
    _progressController.forward().then((_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload Complete!')));
        HapticFeedback.heavyImpact();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_upload_rounded, color: AppColors.primary, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Uploading Video...', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.xl),
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80, height: 80,
                          child: CircularProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                            color: AppColors.primary,
                            strokeWidth: 6,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text('${(_progressAnimation.value * 100).toInt()}%', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            TextButton(
              onPressed: () {
                _progressController.stop();
                Navigator.pop(context);
              },
              child: const Text('Cancel Upload', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
