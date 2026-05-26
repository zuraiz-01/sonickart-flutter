import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../modules/order_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';

class DeliveryRatingDialog extends StatefulWidget {
  const DeliveryRatingDialog({
    super.key,
    required this.orderId,
    required this.deliveryPartnerName,
    this.orderRatingId,
    this.onSubmitRating,
    this.onRatingFlowComplete,
  });

  final String orderId;
  final String deliveryPartnerName;
  final String? orderRatingId;
  final Future<void> Function({
    required String orderId,
    required int rating,
    required String feedback,
  })?
  onSubmitRating;

  /// Called after the entire rating flow (including thank-you dialog) completes.
  final VoidCallback? onRatingFlowComplete;

  @override
  State<DeliveryRatingDialog> createState() => _DeliveryRatingDialogState();
}

class _DeliveryRatingDialogState extends State<DeliveryRatingDialog> {
  int _rating = 0;
  int _hoverRating = 0;
  final _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20.rpx),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPartnerInfo(),
                    SizedBox(height: 16.hpx),
                    _buildStars(),
                    SizedBox(height: 16.hpx),
                    _buildFeedbackField(),
                    if (_submitError != null) ...[
                      SizedBox(height: 10.hpx),
                      _buildSubmitError(),
                    ],
                    SizedBox(height: 14.hpx),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.rpx)),
      ),
      child: Column(
        children: [
          Container(
            width: 56.rpx,
            height: 56.rpx,
            decoration: BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accent,
              size: 28.spx,
            ),
          ),
          SizedBox(height: 14.hpx),
          Text(
            'Order Delivered!',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20.spx,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6.hpx),
          Text(
            'How was your delivery experience?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.84),
              fontSize: 13.spx,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerInfo() {
    final name = widget.deliveryPartnerName.trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.wpx, vertical: 12.hpx),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.rpx),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.pedal_bike_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Partner',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  name.isNotEmpty ? name : 'SonicKart Delivery',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${widget.orderId.length > 8 ? widget.orderId.substring(0, 7) : widget.orderId}',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final starSize = (constraints.maxWidth - 8.wpx * 4) / 5;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isFilled =
                    starIndex <= (_hoverRating > 0 ? _hoverRating : _rating);
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoverRating = starIndex),
                    onExit: (_) => setState(() => _hoverRating = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.symmetric(horizontal: 4.wpx),
                      child: Icon(
                        isFilled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: starSize.clamp(24, 44),
                        color: isFilled ? AppColors.accent : AppColors.border,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        SizedBox(height: 10.hpx),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _ratingLabel,
            key: ValueKey(_rating),
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13.spx,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  String get _ratingLabel {
    return switch (_rating) {
      1 => 'Poor',
      2 => 'Fair',
      3 => 'Good',
      4 => 'Very Good',
      5 => 'Excellent!',
      _ => 'Tap a star to rate',
    };
  }

  Widget _buildFeedbackField() {
    return TextField(
      controller: _feedbackController,
      maxLines: 3,
      maxLength: 200,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: 'Share your experience (optional)',
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.7),
          fontSize: 13.spx,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        counterStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.5),
          fontSize: 10.spx,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: AppColors.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.wpx,
          vertical: 12.hpx,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _rating == 0 || _isSubmitting ? null : _submitRating,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          foregroundColor: AppColors.white,
          minimumSize: Size.fromHeight(48.hpx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.rpx),
          ),
          textStyle: TextStyle(fontSize: 15.spx, fontWeight: FontWeight.w800),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 20.wpx,
                height: 20.hpx,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.white,
                ),
              )
            : Text(_rating < 4 ? 'Submit Feedback' : 'Submit Rating'),
      ),
    );
  }

  Widget _buildSubmitError() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.wpx, vertical: 9.hpx),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.rpx),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Text(
        _submitError!,
        style: TextStyle(
          color: AppColors.error,
          fontSize: 12.spx,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      if (widget.onSubmitRating != null) {
        await widget.onSubmitRating!(
          orderId: widget.orderId,
          rating: _rating,
          feedback: _feedbackController.text.trim(),
        );
      } else if (Get.isRegistered<OrderController>()) {
        await Get.find<OrderController>().submitDeliveryRating(
          orderId: widget.orderId,
          rating: _rating,
          feedback: _feedbackController.text.trim(),
        );
      }
      if (mounted) {
        _showThankYou();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _submitError = _ratingErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _ratingErrorMessage(Object error) {
    final message = error.toString().replaceFirst(RegExp(r'^Exception: '), '');
    if (message.contains('already') && message.contains('rated')) {
      return 'This order has already been rated.';
    }
    if (message.contains('delivered')) {
      return 'Rating will be available once the order is marked delivered.';
    }
    return 'Unable to submit rating. Please try again.';
  }

  void _showThankYou() {
    if (!mounted) return;
    Navigator.of(context).pop();
    Get.dialog(
      const _ThankYouDialog(),
      barrierColor: Colors.black.withValues(alpha: 0.45),
    ).whenComplete(() {
      widget.onRatingFlowComplete?.call();
    });
  }
}

class _ThankYouDialog extends StatelessWidget {
  const _ThankYouDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20.rpx),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.rpx,
              height: 64.rpx,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_rounded,
                color: AppColors.success,
                size: 32.spx,
              ),
            ),
            SizedBox(height: 16.hpx),
            Text(
              'Thank You!',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18.spx,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8.hpx),
            Text(
              'Your feedback helps us serve you better.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.spx,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.hpx),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Get.offAllNamed(AppRoutes.dashboard);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  minimumSize: Size.fromHeight(44.hpx),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.rpx),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
