import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../farm_location/models/farm_location_model.dart';
import '../../farm_location/widgets/farm_location_picker_modal.dart';
import '../services/agricultural_monitoring_service.dart';

/// Reusable, high-performance Farm Location Selector Bar with dropdown switching
/// and map-based custom location naming.
class FarmLocationSelectorBar extends StatelessWidget {
  final VoidCallback? onLocationChanged;

  const FarmLocationSelectorBar({
    super.key,
    this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final service = AgriculturalMonitoringService.instance;

    return ValueListenableBuilder<SavedFarmLocation?>(
      valueListenable: service.activeLocationNotifier,
      builder: (context, activeLoc, _) {
        return ValueListenableBuilder<List<SavedFarmLocation>>(
          valueListenable: service.savedLocationsNotifier,
          builder: (context, savedList, _) {
            if (activeLoc == null || savedList.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.leafGreen.withValues(alpha: 0.25),
                  ),
                  boxShadow: AppColors.glassShadows,
                ),
                child: InkWell(
                  onTap: () => _openMapPicker(
                    context,
                    service,
                    null,
                    isNewLocation: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.leafGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_location_alt_rounded,
                            size: 18,
                            color: AppColors.leafGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tap to Add Farm Location',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.leafGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.leafGreen.withValues(alpha: 0.25),
                ),
                boxShadow: AppColors.glassShadows,
              ),
              child: Row(
                children: [
                  // 1. Dropdown Selector Button (Tap to Switch Saved Farms)
                  Expanded(
                    child: InkWell(
                      onTap: () => _showLocationSwitcherSheet(
                        context,
                        service,
                        activeLoc,
                        savedList,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.leafGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.agriculture_rounded,
                                size: 18,
                                color: AppColors.leafGreen,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          activeLoc.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: AppColors.leafGreen,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${activeLoc.latitude.toStringAsFixed(3)}° N, ${activeLoc.longitude.toStringAsFixed(3)}° E',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. Add / Pick Map Button
                  InkWell(
                    onTap: () => _openMapPicker(
                      context,
                      service,
                      activeLoc,
                      isNewLocation: true,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.leafGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.leafGreen.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_location_alt_rounded,
                            size: 14.5,
                            color: AppColors.leafGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+ Add',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLocationSwitcherSheet(
    BuildContext context,
    AgriculturalMonitoringService service,
    SavedFarmLocation activeLoc,
    List<SavedFarmLocation> savedList,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppColors.glassShadows,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Farm Locations',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Select a farm to instantly load its telemetry',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Saved Farms List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: savedList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final item = savedList[index];
                    final isActive = item.id == activeLoc.id;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          await service.selectLocation(item);
                          onLocationChanged?.call();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.leafGreen.withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.leafGreen
                                  : Colors.black.withValues(alpha: 0.08),
                              width: isActive ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.leafGreen
                                      : Colors.grey.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.check_rounded
                                      : Icons.agriculture_rounded,
                                  size: 16,
                                  color: isActive ? Colors.white : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.latitude.toStringAsFixed(4)}° N, ${item.longitude.toStringAsFixed(4)}° E',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (savedList.length > 1)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 19,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () async {
                                    final confirm = await _showDeleteConfirmDialog(ctx, item.name);
                                    if (confirm == true) {
                                      await service.deleteLocation(item.id);
                                      if (ctx.mounted) {
                                        Navigator.of(ctx).pop();
                                      }
                                      onLocationChanged?.call();
                                    }
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Add New Farm Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openMapPicker(
                      context,
                      service,
                      activeLoc,
                      isNewLocation: true,
                    );
                  },
                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                  label: Text(
                    'Add New Farm Location',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.leafGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Farm Location?',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? Telemetry caches for this farm will also be removed.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openMapPicker(
    BuildContext context,
    AgriculturalMonitoringService service,
    SavedFarmLocation? currentLoc, {
    bool isNewLocation = true,
  }) async {
    const fallbackLat = 12.9716;
    const fallbackLon = 77.5946;

    final result = await FarmLocationPickerModal.show(
      context,
      currentLoc: FarmLocationModel(
        latitude: currentLoc?.latitude ?? fallbackLat,
        longitude: currentLoc?.longitude ?? fallbackLon,
        locationName: isNewLocation ? '' : (currentLoc?.name ?? ''),
      ),
    );

    if (result != null && context.mounted) {
      final lat = result['lat'] as double;
      final lon = result['lon'] as double;
      final returnedName = result['name'] as String?;

      // Dedicated Name Input Dialog with clean text field
      final finalName = await _showNameInputDialog(
        context,
        initialName: (returnedName != null && returnedName.isNotEmpty)
            ? returnedName
            : 'Farm Plot ${service.savedLocationsNotifier.value.length + 1}',
        latitude: lat,
        longitude: lon,
        title: isNewLocation ? 'Name New Farm Location' : 'Save Farm Location',
      );

      if (finalName != null && finalName.trim().isNotEmpty) {
        await service.saveLocation(
          name: finalName.trim(),
          latitude: lat,
          longitude: lon,
          id: isNewLocation ? null : currentLoc?.id,
        );

        onLocationChanged?.call();
      }
    }
  }

  Future<String?> _showNameInputDialog(
    BuildContext context, {
    required String initialName,
    required double latitude,
    required double longitude,
    String title = 'Name Farm Location',
  }) async {
    final controller = TextEditingController(text: initialName);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.leafGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_location_alt_rounded,
                  color: AppColors.leafGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coordinates: ${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Farm Location Name',
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.leafGreen,
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'e.g. North Orchard Plot',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.leafGreen),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.leafGreen,
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(ctx).pop(text.isNotEmpty ? text : initialName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.leafGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Save Location',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
