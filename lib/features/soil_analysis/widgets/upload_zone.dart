import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// A tap-to-upload zone for soil report files (image or PDF).
class UploadZone extends StatefulWidget {
  const UploadZone({
    super.key,
    required this.onFilePicked,
    this.pickedFile,
  });

  final ValueChanged<File> onFilePicked;
  final File? pickedFile;

  @override
  State<UploadZone> createState() => _UploadZoneState();
}

class _UploadZoneState extends State<UploadZone> {
  bool _isHovered = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );

    if (result != null && result.files.single.path != null) {
      widget.onFilePicked(File(result.files.single.path!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasFile = widget.pickedFile != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _pickFile,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: GlassCard(
            padding: const EdgeInsets.all(32),
            borderOpacity: _isHovered ? 0.5 : 0.2,
            gradient: LinearGradient(
              colors: hasFile
                  ? [
                      AppColors.leafGreen.withValues(alpha: 0.2),
                      AppColors.forestGreen.withValues(alpha: 0.08),
                    ]
                  : [
                      Colors.white.withValues(alpha: _isHovered ? 0.12 : 0.06),
                      Colors.white.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon area
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: (hasFile ? AppColors.leafGreen : AppColors.accentGold)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (hasFile
                              ? AppColors.leafGreen
                              : AppColors.accentGold)
                          .withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    hasFile
                        ? Icons.check_circle_outline_rounded
                        : Icons.cloud_upload_outlined,
                    size: 36,
                    color: hasFile
                        ? AppColors.leafGreen
                        : AppColors.accentGoldLight,
                  ),
                )
                    .animate(target: _isHovered ? 1 : 0)
                    .scaleXY(end: 1.08, curve: Curves.easeOut),
                const SizedBox(height: 20),

                if (hasFile) ...[
                  // File selected state
                  Text(
                    'File Selected ✓',
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.leafGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _fileName(widget.pickedFile!.path),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Change File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(
                          color: AppColors.textMuted.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      textStyle: textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ] else ...[
                  // Empty state
                  Text(
                    'Upload Soil Report',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to select an image or PDF\nof your soil lab report',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  // Supported formats
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: ['JPG', 'PNG', 'PDF', 'WEBP'].map((fmt) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                AppColors.accentGold.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          fmt,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.accentGoldLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fileName(String path) {
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }
}
