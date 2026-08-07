import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import 'glass_card.dart';

/// Clean default tap-to-upload zone for soil report files (image or PDF).
class UploadZone extends StatefulWidget {
  const UploadZone({super.key, required this.onFilePicked, this.pickedFile});

  final ValueChanged<File> onFilePicked;
  final File? pickedFile;

  static Future<File?> pickFileFromUser() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'heic'],
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );

    if (result != null && result.files.single.path != null) {
      return File(result.files.single.path!);
    }
    return null;
  }

  @override
  State<UploadZone> createState() => _UploadZoneState();
}


class _UploadZoneState extends State<UploadZone> {
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

    return GestureDetector(
      onTap: _pickFile,
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // Clean default upload icon
              Icon(
                hasFile
                    ? Icons.check_circle_rounded
                    : Icons.cloud_upload_rounded,
                size: 52,
                color: AppColors.leafGreen,
              ),

              const SizedBox(height: 16),

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
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Change File'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.leafGreen,
                  ),
                ),
              ] else ...[
                // Default clean state
                Text(
                  'Upload Soil Report',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'pdf or image',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fileName(String path) {
    return path.split(Platform.isWindows ? '\\' : '/').last;
  }
}
