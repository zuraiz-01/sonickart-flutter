import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/app_ad_model.dart';
import '../../../theme/app_colors.dart';
import '../controllers/ads_controller.dart';

class AdPlacement extends StatefulWidget {
  const AdPlacement({
    super.key,
    required this.placement,
    this.padding,
    this.height,
  });

  final String placement;
  final EdgeInsetsGeometry? padding;
  final double? height;

  @override
  State<AdPlacement> createState() => _AdPlacementState();
}

class _AdPlacementState extends State<AdPlacement> {
  final _currentPage = 0.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<AdsController>()) return;
      unawaited(Get.find<AdsController>().ensureLoaded(widget.placement));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdsController>()) return const SizedBox.shrink();

    final controller = Get.find<AdsController>();
    return Obx(() {
      final ads = controller.adsFor(widget.placement);
      if (ads.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding:
            widget.padding ??
            EdgeInsets.symmetric(horizontal: 8.wpx, vertical: 8.hpx),
        child: SizedBox(
          height: widget.height ?? 116.hpx,
          child: ads.length == 1
              ? _AdCard(ad: ads.first)
              : Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      itemCount: ads.length,
                      padEnds: false,
                      onPageChanged: (index) => _currentPage.value = index,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.wpx),
                          child: _AdCard(ad: ads[index]),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 8.hpx,
                      child: Obx(
                        () => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(ads.length, (index) {
                            final active = index == _currentPage.value;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: active ? 16.wpx : 6.wpx,
                              height: 6.hpx,
                              margin: EdgeInsets.symmetric(horizontal: 3.wpx),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.accent
                                    : Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(999.rpx),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }
}

class _AdCard extends StatelessWidget {
  const _AdCard({required this.ad});

  final AppAdModel ad;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDarkMode;
    final borderColor = isDark
        ? AppColors.accent.withValues(alpha: 0.62)
        : AppColors.primary.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: ad.hasLink ? () => _openLink(ad.linkUrl) : null,
        borderRadius: BorderRadius.circular(14.rpx),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF06225B) : AppColors.card,
            borderRadius: BorderRadius.circular(14.rpx),
            border: Border.all(color: borderColor, width: isDark ? 1.1.rpx : 1),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.34)
                    : AppColors.cardShadow,
                blurRadius: isDark ? 9.rpx : 8.rpx,
                offset: Offset(0, isDark ? 5.hpx : 3.hpx),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13.rpx),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ad.isVideo
                    ? _AdVideo(url: ad.mediaUrl)
                    : _AdImage(url: ad.mediaUrl),
                Positioned(
                  top: 7.hpx,
                  right: 7.wpx,
                  child: _AdReportButton(ad: ad),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _AdReportButton extends StatelessWidget {
  const _AdReportButton({required this.ad});

  final AppAdModel ad;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.34),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showAdReportSheet(context, ad),
        child: SizedBox(
          width: 30.rpx,
          height: 30.rpx,
          child: Icon(Icons.flag_outlined, color: Colors.white, size: 16.spx),
        ),
      ),
    );
  }
}

void _showAdReportSheet(BuildContext context, AppAdModel ad) {
  final reasons = const [
    'Inappropriate ad',
    'Misleading ad',
    'Age-inappropriate ad',
    'Broken or low-quality ad',
  ];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18.rpx)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.wpx, 18.hpx, 18.wpx, 12.hpx),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Ad',
                style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16.spx,
                ),
              ),
              SizedBox(height: 6.hpx),
              Text(
                'Tell us what is wrong with this ad.',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.spx,
                ),
              ),
              SizedBox(height: 12.hpx),
              ...reasons.map(
                (reason) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.report_gmailerrorred_outlined,
                    color: AppColors.accent,
                    size: 21.spx,
                  ),
                  title: Text(
                    reason,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.spx,
                    ),
                  ),
                  onTap: () => _submitAdReport(sheetContext, ad, reason),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _submitAdReport(
  BuildContext context,
  AppAdModel ad,
  String reason,
) async {
  Navigator.of(context).pop();
  final subject = ad.id.trim().isEmpty
      ? 'SonicKart ad report'
      : 'SonicKart ad report ${ad.id.trim()}';
  final details = [
    'Reason: $reason',
    if (ad.id.trim().isNotEmpty) 'Ad ID: ${ad.id.trim()}',
    if (ad.title.trim().isNotEmpty) 'Ad title: ${ad.title.trim()}',
    'Media type: ${ad.mediaType}',
    'Media URL: ${ad.mediaUrl}',
    if (ad.linkUrl.trim().isNotEmpty) 'Link URL: ${ad.linkUrl}',
  ].join('\n');
  final uri = Uri(
    scheme: 'mailto',
    path: 'support@sonickartnow.com',
    queryParameters: {'subject': subject, 'body': details},
  );

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    Get.snackbar(
      'Ad Report',
      opened
          ? 'Please send the prepared email so our team can review this ad.'
          : 'Could not open email. Please contact support@sonickartnow.com.',
      snackPosition: SnackPosition.BOTTOM,
    );
  } catch (error) {
    debugPrint('Ad report failed: $error');
    Get.snackbar(
      'Ad Report',
      'Could not open email. Please contact support@sonickartnow.com.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class _AdImage extends StatelessWidget {
  const _AdImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _adMediaFillColor(),
      child: Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _AdFallback(isVideo: false),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 18.rpx,
              height: 18.rpx,
              child: CircularProgressIndicator(
                strokeWidth: 2.rpx,
                color: AppColors.activeNav,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdVideo extends StatefulWidget {
  const _AdVideo({required this.url});

  final String url;

  @override
  State<_AdVideo> createState() => _AdVideoState();
}

class _AdVideoState extends State<_AdVideo> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final uri = Uri.tryParse(widget.url);
    if (uri == null || !uri.hasScheme) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _controller = controller;
    try {
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.initialize();
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_hasError || controller == null) {
      return _AdFallback(isVideo: true);
    }
    if (!controller.value.isInitialized) {
      return ColoredBox(
        color: _adMediaFillColor(),
        child: Center(
          child: SizedBox(
            width: 20.rpx,
            height: 20.rpx,
            child: CircularProgressIndicator(
              strokeWidth: 2.rpx,
              color: AppColors.activeNav,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: _adMediaFillColor(),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

class _AdFallback extends StatelessWidget {
  const _AdFallback({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _adMediaFillColor(),
      child: Center(
        child: Icon(
          isVideo ? Icons.play_circle_fill_rounded : Icons.image_outlined,
          color: AppColors.activeNav,
          size: 32.spx,
        ),
      ),
    );
  }
}

Color _adMediaFillColor() =>
    AppColors.isDarkMode ? const Color(0xFF06225B) : AppColors.productImageFill;
