import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/gradient_button.dart';
import '../../../../widgets/animations.dart';
import '../../../../models/app_models.dart';
import '../../../../services/course_service.dart';
import '../../../../services/bunny_stream_service.dart';
import '../../../../services/bunny_storage_service.dart';

/// Admin upload screen. Files stay in external storage; Firestore stores metadata only.
class AdminVideoUploadScreen extends StatefulWidget {
  final CourseModel? course;

  const AdminVideoUploadScreen({super.key, this.course});

  @override
  State<AdminVideoUploadScreen> createState() => _AdminVideoUploadScreenState();
}

class _AdminVideoUploadScreenState extends State<AdminVideoUploadScreen> {
  final _courseService = CourseService();
  final _titleController = TextEditingController();
  final _storageUrlController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  final _moduleController = TextEditingController();
  final _orderController = TextEditingController();
  List<CourseModel>? _allCourses;
  CourseModel? _selectedCourse;
  bool _isFree = false;
  bool _isPdf = false;
  bool _isPublishing = false;
  File? _selectedVideoFile;
  File? _selectedPdfFile;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedCourse = widget.course;
    if (widget.course == null) {
      _loadCourses();
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _courseService.getAllCoursesForAdmin();
      if (mounted) {
        setState(() => _allCourses = courses);
      }
    } catch (e) {
      // Handle error implicitly
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _storageUrlController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    _moduleController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_selectedCourse == null ? 'Upload Content' : _selectedCourse!.title, style: AppTextStyles.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Admin upload - files stay in external storage',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (widget.course == null) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select Course', style: AppTextStyles.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: _allCourses == null
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<CourseModel>(
                                isExpanded: true,
                                hint: Text('Choose a course', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                                value: _selectedCourse,
                                dropdownColor: AppColors.surface,
                                items: _allCourses!.map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text('${c.title} (${c.trainerName})', style: AppTextStyles.bodyMedium),
                                    )).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedCourse = val);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _buildField(_isPdf ? 'PDF Title' : 'Video Title', 'e.g. Chapter 1: Introduction', controller: _titleController),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isPdf) ...[
                    _buildPdfPicker(),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.center,
                      child: Text('OR', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ] else ...[
                    _buildVideoPicker(),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.center,
                      child: Text('OR', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textHint)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _buildField(_isPdf ? 'External PDF URL' : 'Bunny Video ID / CDN URL', 'From your external storage', controller: _storageUrlController),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: Row(
                children: [
                  Expanded(child: _buildField('Duration (min)', 'e.g. 25', controller: _durationController)),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: _buildField('Price (₹)', 'e.g. 49', controller: _priceController)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: _buildField('Module ID', 'e.g. mod_001', controller: _moduleController),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: _buildField('Order', 'e.g. 1', controller: _orderController),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 425),
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
                      setState(() {
                        _isPdf = false;
                        _selectedPdfFile = null;
                        _selectedVideoFile = null;
                        _titleController.clear();
                        _storageUrlController.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('PDF'),
                    selected: _isPdf,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isPdf = true;
                        _selectedPdfFile = null;
                        _selectedVideoFile = null;
                        _titleController.clear();
                        _storageUrlController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSlideIn(
              delay: const Duration(milliseconds: 450),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.subtle,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Free Preview', style: AppTextStyles.titleMedium),
                          Text('Users can watch without purchase', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isFree,
                      activeThumbColor: AppColors.success,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _isFree = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
            FadeSlideIn(
              delay: const Duration(milliseconds: 500),
              child: GradientButton(
                text: _isPublishing
                    ? (_uploadProgress > 0 && _uploadProgress < 1 && !_isPdf
                        ? 'Uploading video (${(_uploadProgress * 100).toInt()}%)...'
                        : 'Publishing...')
                    : 'Publish Content',
                icon: Icons.cloud_upload_rounded,
                borderRadius: AppRadius.pill,
                isLoading: _isPublishing,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  if (!_isPublishing) _publishContent();
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String hint, {required TextEditingController controller}) {
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

  Widget _buildVideoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video File (Optional)', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            try {
              final result = await FilePicker.pickFiles(
                type: FileType.video,
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                if (file.path != null) {
                  final videoFile = File(file.path!);
                  setState(() {
                    _selectedVideoFile = videoFile;
                    _selectedPdfFile = null;
                    if (_titleController.text.trim().isEmpty) {
                      _titleController.text = file.name.split('.').first;
                    }
                    _storageUrlController.text = file.name;
                  });

                  // Auto-extract duration from video file
                  try {
                    final controller = VideoPlayerController.file(videoFile);
                    await controller.initialize();
                    final durationSecs = controller.value.duration.inSeconds;
                    if (durationSecs > 0) {
                      final durationMins = durationSecs / 60.0;
                      final durationStr = durationMins.toStringAsFixed(2);
                      final cleanStr = durationStr.endsWith('.00')
                          ? durationStr.substring(0, durationStr.length - 3)
                          : durationStr;
                      _durationController.text = cleanStr;
                    }
                    await controller.dispose();
                  } catch (ex) {
                    debugPrint('Error extracting video duration: $ex');
                  }
                }
              }
            } catch (e) {
              _showMessage('Unable to pick video file.', isError: true);
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
                    _selectedVideoFile == null
                        ? 'Tap to select Video file from device'
                        : _selectedVideoFile!.path.split('/').last.split('\\').last,
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

  Widget _buildPdfPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PDF File (Optional)', style: AppTextStyles.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () async {
            HapticFeedback.mediumImpact();
            try {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
              );
              if (result != null && result.files.isNotEmpty) {
                final file = result.files.first;
                setState(() {
                  if (file.path != null) {
                    _selectedPdfFile = File(file.path!);
                    _selectedVideoFile = null;
                    if (_titleController.text.trim().isEmpty) {
                      _titleController.text = file.name.replaceAll('.pdf', '');
                    }
                    _storageUrlController.text = file.name;
                  }
                });
              }
            } catch (e) {
              _showMessage('Unable to pick PDF file.', isError: true);
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
                    _selectedPdfFile == null
                        ? 'Tap to select PDF file from device'
                        : _selectedPdfFile!.path.split('/').last.split('\\').last,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: _selectedPdfFile == null ? AppColors.textHint : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_selectedPdfFile != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.error),
                    onPressed: () {
                      setState(() {
                        _selectedPdfFile = null;
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

  Future<void> _publishContent() async {
    final course = _selectedCourse;
    if (course == null) {
      _showMessage('Please select a course first.', isError: true);
      return;
    }

    final title = _titleController.text.trim();
    final storageUrl = _storageUrlController.text.trim();
    if (title.isEmpty) {
      _showMessage('Please enter a title.', isError: true);
      return;
    }

    if (storageUrl.isEmpty && _selectedVideoFile == null && _selectedPdfFile == null) {
      _showMessage(
        _isPdf ? 'Please select a PDF file or enter external PDF URL.' : 'Please select a Video file or enter Bunny Video ID.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isPublishing = true;
      _uploadProgress = 0.0;
    });

    String finalStorageUrl = storageUrl;
    String bunnyVideoId = _isPdf ? '' : storageUrl;

    try {
      if (_isPdf && _selectedPdfFile != null) {
        final bunnyStorage = BunnyStorageService();
        final url = await bunnyStorage.uploadFile(
          file: _selectedPdfFile!,
          path: 'bharatm_library/pdfs/${DateTime.now().millisecondsSinceEpoch}_${_selectedPdfFile!.path.split('/').last.split('\\').last}',
        );
        if (url == null) throw Exception('Failed to upload PDF');
        finalStorageUrl = url;
      } else if (!_isPdf && _selectedVideoFile != null) {
        final bunnyService = BunnyStreamService();
        final bunnyResult = await bunnyService.uploadVideo(
          file: _selectedVideoFile!,
          title: title,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        if (bunnyResult == null) {
          throw Exception('Failed to upload video to Bunny Stream');
        }
        finalStorageUrl = bunnyResult['storageUrl']!;
        bunnyVideoId = bunnyResult['bunnyVideoId']!;
      }

      await _courseService.uploadCourseContent(
        courseId: course.id,
        title: title,
        contentType: _isPdf ? CourseContentType.pdf : CourseContentType.video,
        storageUrl: finalStorageUrl,
        bunnyVideoId: bunnyVideoId,
        moduleId: _moduleController.text.trim().isEmpty ? null : _moduleController.text.trim(),
        durationMinutes: double.tryParse(_durationController.text.trim()) ?? 0,
        price: double.tryParse(_priceController.text.trim()),
        isFree: _isFree,
        order: int.tryParse(_orderController.text.trim()) ?? 0,
        autoApprove: true,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      _showMessage('Content published successfully!');
    } catch (e) {
      if (mounted) _showMessage('Unable to publish content: ${e.toString()}', isError: true);
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    );
  }
}
