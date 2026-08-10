import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../soil_analysis/widgets/glass_card.dart';

class MandiDropdownSelector extends StatelessWidget {
  const MandiDropdownSelector({
    super.key,
    required this.label,
    required this.icon,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
    this.placeholder = 'Select',
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final String selectedValue;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String placeholder;
  final bool enabled;

  void _showSearchablePickerBottomSheet(BuildContext context) {
    if (!enabled) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SearchablePickerModal(
        label: label,
        icon: icon,
        selectedValue: selectedValue,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedValue.isNotEmpty;

    return GestureDetector(
      onTap: enabled ? () => _showSearchablePickerBottomSheet(context) : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 14,
          borderOpacity: 0.25,
          child: Row(
            children: [
              Icon(icon, color: AppColors.leafGreen, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: AppColors.leafGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue ? selectedValue : placeholder,
                      style: GoogleFonts.poppins(
                        color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                        fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchablePickerModal extends StatefulWidget {
  const _SearchablePickerModal({
    required this.label,
    required this.icon,
    required this.selectedValue,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String selectedValue;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchablePickerModal> createState() => _SearchablePickerModalState();
}

class _SearchablePickerModalState extends State<_SearchablePickerModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((it) => it.toLowerCase().contains(query)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.bgMid,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.leafGreen, width: 1.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Modal Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(widget.icon, color: AppColors.leafGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Select ${widget.label}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: TextField(
              controller: _searchCtrl,
              style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search ${widget.label}...',
                hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.leafGreen),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.8),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.leafGreen.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.leafGreen.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.leafGreen, width: 1.5),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(color: Colors.white12, height: 1),

          // Filtered List
          Flexible(
            child: _filteredItems.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No matching ${widget.label.toLowerCase()} found',
                      style: GoogleFonts.poppins(color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = item == widget.selectedValue;

                      return RepaintBoundary(
                        child: InkWell(
                          onTap: () {
                            widget.onChanged(item);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            color: isSelected ? AppColors.leafGreen.withValues(alpha: 0.15) : Colors.transparent,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? AppColors.leafGreen : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.leafGreen,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }
}
