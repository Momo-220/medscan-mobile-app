import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/scan_response.dart';
import '../../../shared/utils/localization.dart';
import '../../../shared/widgets/card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/navigation_bar.dart';
import '../providers/suggestions_provider.dart';
import '../../../core/di/providers.dart';

class ScanResultPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> scanData;

  const ScanResultPage({
    super.key,
    required this.scanData,
  });

  @override
  ConsumerState<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends ConsumerState<ScanResultPage> {
  String? _resolvedLocalImagePath;
  int _activeCarouselIndex = 0;
  final PageController _carouselController = PageController();
  Map<String, dynamic>? _translatedScanData;
  bool _translating = false;

  @override
  void initState() {
    super.initState();
    _resolveImagePath();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTranslatedDetails();
    });
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _fetchTranslatedDetails() async {
    final scanId = widget.scanData['scan_id'] ?? widget.scanData['id'];
    if (scanId == null) return;

    final lang = ref.read(languageProvider);
    final originalLang = widget.scanData['packaging_language'] ?? 'fr';
    if (lang.toLowerCase() == originalLang.toString().toLowerCase()) return;

    if (mounted) {
      setState(() {
        _translating = true;
      });
    }

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/scan/$scanId', queryParameters: {'language': lang});
      if (mounted && response.statusCode == 200) {
        setState(() {
          _translatedScanData = response.data;
          _translating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _translating = false;
        });
      }
    }
  }

  Future<void> _resolveImagePath() async {
    final rawUrl = widget.scanData['image_url'] as String?;
    if (rawUrl != null && rawUrl.isNotEmpty && !rawUrl.startsWith('http')) {
      try {
        final fileName = rawUrl.split('/').last;
        final appDir = await getApplicationDocumentsDirectory();
        final resolvedFile = File('${appDir.path}/scanned_images/$fileName');
        if (mounted) {
          setState(() {
            _resolvedLocalImagePath = resolvedFile.path;
          });
        }
      } catch (_) {}
    }
  }

  String _getResolvedImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    
    // Replace localhost or 127.0.0.1 with the actual configured IP address of the server
    final serverBase = ApiConstants.baseUrl.replaceAll('/api/v1', '');
    
    if (url.startsWith('http://localhost:8888')) {
      return url.replaceAll('http://localhost:8888', serverBase);
    }
    if (url.startsWith('http://127.0.0.1:8888')) {
      return url.replaceAll('http://127.0.0.1:8888', serverBase);
    }
    return url;
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence.toLowerCase()) {
      case 'high':
      case 'élevée':
        return AppColors.alertLow; // Teal/Green
      case 'medium':
      case 'moyenne':
        return AppColors.alertMedium; // Orange
      case 'low':
      case 'faible':
        return AppColors.alertHigh; // Red
      default:
        return AppColors.textMuted;
    }
  }

  String _getConfidenceText(String confidence, WidgetRef ref) {
    switch (confidence.toLowerCase()) {
      case 'high':
      case 'élevée':
        return ref.t('high');
      case 'medium':
      case 'moyenne':
        return ref.t('medium');
      case 'low':
      case 'faible':
        return ref.t('low');
      default:
        return confidence;
    }
  }

  Widget _buildHeaderIconBadge({
    required IconData icon,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.micro(isDark: isDark).copyWith(
              color: isDark ? Colors.white70 : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Parse result JSON into strongly-typed model
    final Map<String, dynamic> activeData = _translatedScanData ?? widget.scanData;
    final Map<String, dynamic> scanDataMap;
    if (activeData.containsKey('analysis_data') && activeData['analysis_data'] is Map) {
      scanDataMap = {
        ...activeData,
        ...Map<String, dynamic>.from(activeData['analysis_data']),
      };
      if (activeData['image_url'] != null) {
        scanDataMap['image_url'] = activeData['image_url'];
      }
    } else {
      scanDataMap = activeData;
    }
    final scan = ScanResponse.fromJson(scanDataMap);
    
    // Watch suggestions for this category
    final suggestionsAsync = ref.watch(suggestionsProvider(scan.category));

    final confidenceColor = _getConfidenceColor(scan.confidence);
    final confidenceText = _getConfidenceText(scan.confidence, ref);

    // Build the dynamic carousel pages based on available scan details
    final List<Map<String, dynamic>> carouselItems = [];
    
    // 1. Composition Card
    final hasActiveIngredient = scan.activeIngredient != null && scan.activeIngredient!.trim().isNotEmpty;
    final hasExcipients = scan.excipients != null && scan.excipients!.trim().isNotEmpty;
    if (hasActiveIngredient || hasExcipients) {
      String compositionMd = '';
      if (hasActiveIngredient) {
        compositionMd += '**${ref.t('activeIngredient')}:**\n${scan.activeIngredient}\n\n';
      }
      if (hasExcipients) {
        compositionMd += '**${ref.t('excipients')}:**\n${scan.excipients}';
      }
      carouselItems.add({
        'title': ref.t('composition'),
        'icon': Icons.science_outlined,
        'content': compositionMd,
      });
    }

    // 2. Indications Card
    if (scan.indications != null && scan.indications!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('indications') ?? 'Indications',
        'icon': Icons.info_outline,
        'content': scan.indications,
      });
    }

    // 3. Posology / Usage Card
    final posologyContent = scan.posology ?? scan.dosageInstructions;
    if (posologyContent != null && posologyContent.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('posology'),
        'icon': Icons.checklist_rtl_outlined,
        'content': posologyContent,
      });
    }

    // 4. Contraindications Card
    if (scan.contraindications != null && scan.contraindications!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('contraindications'),
        'icon': Icons.block_flipped,
        'content': scan.contraindications,
      });
    }

    // 5. Side Effects Card
    if (scan.sideEffects != null && scan.sideEffects!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('sideEffects'),
        'icon': Icons.sick_outlined,
        'content': scan.sideEffects,
      });
    }

    // 6. Interactions Card
    if (scan.interactions != null && scan.interactions!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('interactions'),
        'icon': Icons.swap_horizontal_circle_outlined,
        'content': scan.interactions,
      });
    }

    // 7. Precautions Card
    if (scan.precautions != null && scan.precautions!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('precautions'),
        'icon': Icons.verified_user_outlined,
        'content': scan.precautions,
      });
    }

    // 8. Storage Card
    if (scan.storage != null && scan.storage!.trim().isNotEmpty) {
      carouselItems.add({
        'title': ref.t('storage'),
        'icon': Icons.severe_cold_outlined,
        'content': scan.storage,
      });
    }

    // 9. Additional Info Card
    if (scan.expiryDate != null || scan.lotNumber != null || (scan.additionalInfo != null && scan.additionalInfo!.trim().isNotEmpty)) {
      String addInfoMd = '';
      if (scan.expiryDate != null && scan.expiryDate!.isNotEmpty) {
        addInfoMd += '**${ref.t('expiryDate')}:** ${scan.expiryDate}\n\n';
      }
      if (scan.lotNumber != null && scan.lotNumber!.isNotEmpty) {
        addInfoMd += '**Numéro de Lot:** ${scan.lotNumber}\n\n';
      }
      if (scan.additionalInfo != null && scan.additionalInfo!.trim().isNotEmpty) {
        addInfoMd += scan.additionalInfo!;
      }
      carouselItems.add({
        'title': ref.t('additionalInfo'),
        'icon': Icons.info_outline,
        'content': addInfoMd,
      });
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0, bottom: 4.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.textPrimary),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
        ),
        title: Text(
          ref.t('scanResult'),
          style: AppTextStyles.h2(isDark: isDark).copyWith(fontSize: 20),
        ),
        centerTitle: false,
      ),
      bottomNavigationBar: const CustomNavigationBar(currentPath: '/pharmacy'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Medication Image Card (matching layout)
              Center(
                child: Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: scan.imageUrl != null && scan.imageUrl!.isNotEmpty
                        ? (scan.imageUrl!.startsWith('http')
                            ? CachedNetworkImage(
                                imageUrl: _getResolvedImageUrl(scan.imageUrl) ?? '',
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Skeleton(width: double.infinity, height: 250),
                                errorWidget: (context, url, error) => _buildNoImagePlaceholder(isDark),
                              )
                            : Image.file(
                                File(_resolvedLocalImagePath ?? scan.imageUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildNoImagePlaceholder(isDark),
                              ))
                        : _buildNoImagePlaceholder(isDark),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Medication Name & Conf Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            scan.medicationName,
                            style: AppTextStyles.h1(isDark: isDark).copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_translating) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: confidenceColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: confidenceColor.withOpacity(0.2), width: 1),
                    ),
                    child: Text(
                      confidenceText.toUpperCase(),
                      style: AppTextStyles.micro(isDark: isDark).copyWith(
                        color: confidenceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              
              if (scan.genericName != null && scan.genericName!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  scan.genericName!,
                  style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // 3. Icons Detail Row (Dosage, Form, Manufacturer)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (scan.dosage != null && scan.dosage!.isNotEmpty)
                      _buildHeaderIconBadge(
                        icon: Icons.vaccines_outlined,
                        text: scan.dosage!,
                        isDark: isDark,
                      ),
                    if (scan.form != null && scan.form!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _buildHeaderIconBadge(
                        icon: Icons.layers_outlined,
                        text: scan.form!,
                        isDark: isDark,
                      ),
                    ],
                    if (scan.manufacturer != null && scan.manufacturer!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      _buildHeaderIconBadge(
                        icon: Icons.business_outlined,
                        text: scan.manufacturer!,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Warnings Box (if any warnings returned)
              if (scan.warnings.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50]!.withOpacity(isDark ? 0.15 : 0.9),
                    border: Border.all(
                      color: Colors.red[200]!.withOpacity(isDark ? 0.2 : 0.9),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red[500], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            ref.t('warnings'),
                            style: AppTextStyles.smallBold(isDark: false).copyWith(
                              color: isDark ? Colors.red[300] : Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...scan.warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            '• $w',
                            style: AppTextStyles.small(isDark: isDark).copyWith(
                              color: isDark ? Colors.red[200] : Colors.red[800],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5. LIST OF ALL INFORMATION CARDS (Horizontal Carousel with Colored Titles & Highlights)
              if (carouselItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 350,
                  child: PageView.builder(
                    controller: _carouselController,
                    scrollDirection: Axis.horizontal,
                    onPageChanged: (index) {
                      setState(() {
                        _activeCarouselIndex = index;
                      });
                    },
                    itemCount: carouselItems.length,
                    itemBuilder: (context, index) {
                      final item = carouselItems[index];
                      final isSelected = index == _activeCarouselIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(top: 8.0, bottom: 14.0, left: 8.0, right: 14.0),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white24 : const Color(0xFF0F172A),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(isDark ? 0.35 : 0.8)
                                  : (isDark ? const Color(0xFF1E1E2F) : const Color(0xFF0F172A).withOpacity(0.15)),
                              blurRadius: 0,
                              offset: const Offset(6, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Title header with Colored Icon and Title text
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    item['icon'] as IconData,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    style: AppTextStyles.bodyBold(isDark: isDark).copyWith(
                                      fontSize: 16,
                                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), // Indigo!
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Card Content Markdown (Scrollable inside the card if content is too long)
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: MarkdownBody(
                                  data: item['content'] as String,
                                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                    p: AppTextStyles.small(isDark: isDark).copyWith(height: 1.5),
                                    listBullet: AppTextStyles.small(isDark: isDark),
                                    strong: AppTextStyles.smallBold(isDark: isDark).copyWith(
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Horizontal dot indicators below the PageView
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(carouselItems.length, (index) {
                    final isSelected = index == _activeCarouselIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      width: isSelected ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
              ],

              // 7. Suggestions List (Bottom BDPM suggestions)
              Text(
                ref.t('suggestions'),
                style: AppTextStyles.h3(isDark: isDark),
              ),
              const SizedBox(height: 12),

              suggestionsAsync.when(
                loading: () => _buildSuggestionsSkeleton(),
                error: (err, stack) => const SizedBox(),
                data: (suggestions) {
                  if (suggestions.isEmpty) {
                    return Text(
                      ref.t('noSuggestions'),
                      style: AppTextStyles.small(isDark: isDark),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: suggestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sug = suggestions[index];
                      return AppCard(
                        padding: const EdgeInsets.all(12),
                        children: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.medication_outlined,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sug.name,
                                    style: AppTextStyles.smallBold(isDark: isDark),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (sug.form != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      sug.form!,
                                      style: AppTextStyles.micro(isDark: isDark),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Disclaimer text at bottom
              const SizedBox(height: 32),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    scan.disclaimer ?? ref.t('disclaimerMedical'),
                    style: AppTextStyles.micro(isDark: isDark),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Generous bottom spacer to scroll above CustomNavigationBar
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoImagePlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 64,
              color: AppColors.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              "Aucune image disponible",
              style: AppTextStyles.small(isDark: isDark).copyWith(
                color: isDark ? AppColors.textMutedDark : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsSkeleton() {
    return Column(
      children: List.generate(3, (index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: AppCard(
            padding: EdgeInsets.all(12),
            children: Row(
              children: [
                Skeleton(width: 44, height: 44, borderRadius: 10),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Skeleton(width: 140, height: 16),
                      SizedBox(height: 6),
                      Skeleton(width: 85, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
