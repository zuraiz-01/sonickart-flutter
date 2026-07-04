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
