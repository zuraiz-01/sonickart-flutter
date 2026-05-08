import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final AuthController controller = Get.find<AuthController>();
  late final Worker _otpSentAlertWorker;
  bool _isOtpSentAlertVisible = false;

  @override
  void initState() {
    super.initState();
    _otpSentAlertWorker = ever<int>(controller.otpSentAlertTick, (tick) {
      if (tick <= 0) return;
      _showOtpSentAlert();
    });
  }

  @override
  void dispose() {
    _otpSentAlertWorker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/loginpagebackground.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: ColoredBox(color: AppColors.overlayBlue)),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 100 + bottomInset),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.sizeOf(context).height - (130 + bottomInset),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 352.wpx),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        20.wpx,
                        22.hpx,
                        20.wpx,
                        18.hpx,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18.rpx),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.38),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x2E000000),
                            blurRadius: 18,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: controller.loginFormKey,
                        child: Obx(
                          () => Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  'Log in or Sign up',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.spx,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: controller.isOtpSent.value
                                    ? 14.hpx
                                    : 18.hpx,
                              ),
                              if (!controller.isOtpSent.value)
                                _PhoneField(controller: controller)
                              else
                                _OtpSection(controller: controller),
                              InkWell(
                                onTap: controller.toggleAgreement,
                                borderRadius: BorderRadius.circular(10.rpx),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20.wpx,
                                        height: 20.hpx,
                                        margin: EdgeInsets.only(top: 1),
                                        decoration: BoxDecoration(
                                          color:
                                              controller.agreementChecked.value
                                              ? AppColors.primary
                                              : AppColors.white,
                                          borderRadius: BorderRadius.circular(
                                            3.rpx,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: controller.agreementChecked.value
                                            ? Icon(
                                                Icons.check,
                                                size: 13.spx,
                                                color: AppColors.white,
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: 8.wpx),
                                      Expanded(
                                        child: Text(
                                          'By continuing you agree to SonicKart\'s Terms & Conditions and Privacy Policy.',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 14.spx,
                                            height: 1.35,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.hpx),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed:
                                      controller.isSendingOtp.value ||
                                          controller.isVerifyingOtp.value
                                      ? null
                                      : (controller.isOtpSent.value
                                            ? controller.verifyOtp
                                            : controller.sendOtp),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: controller.isOtpSent.value
                                        ? AppColors.primary
                                        : AppColors.accent,
                                    foregroundColor: AppColors.white,
                                    minimumSize: Size.fromHeight(46.hpx),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        8.rpx,
                                      ),
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: 15.spx,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    disabledBackgroundColor:
                                        controller.isOtpSent.value
                                        ? const Color(0xFF9B9B9B)
                                        : AppColors.accent.withValues(
                                            alpha: 0.55,
                                          ),
                                    disabledForegroundColor: AppColors.white
                                        .withValues(alpha: 0.8),
                                  ),
                                  child:
                                      controller.isSendingOtp.value ||
                                          controller.isVerifyingOtp.value
                                      ? SizedBox(
                                          height: 20.hpx,
                                          width: 20.wpx,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: AppColors.white,
                                          ),
                                        )
                                      : Text(
                                          controller.isOtpSent.value
                                              ? 'Verify OTP'
                                              : 'Send OTP',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomInset),
              decoration: BoxDecoration(
                color: AppColors.primary,
                border: Border(
                  top: BorderSide(color: Color(0xFF234488), width: 0.8),
                ),
              ),
              child: Text(
                'Your city\'s essentials, delivered fast.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.white,
                  letterSpacing: 0.6,
                  fontSize: 14.spx,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOtpSentAlert() async {
    if (!mounted || _isOtpSentAlertVisible) return;

    _isOtpSentAlertVisible = true;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.40),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        final textTheme = Theme.of(context).textTheme;

        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 340.wpx),
                margin: EdgeInsets.symmetric(horizontal: 20.wpx),
                padding: EdgeInsets.all(24.rpx),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20.rpx),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64.rpx,
                      height: 64.rpx,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.10),
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.primary,
                        size: 32.spx,
                      ),
                    ),
                    SizedBox(height: 16.hpx),
                    Text(
                      controller.otpSentAlertTitle.value,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16.spx,
                      ),
                    ),
                    SizedBox(height: 8.hpx),
                    Text(
                      controller.otpSentAlertMessage.value,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary.withValues(alpha: 0.80),
                        fontSize: 15.spx,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 24.hpx),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          minimumSize: Size.fromHeight(48.hpx),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.rpx),
                          ),
                          textStyle: TextStyle(
                            fontSize: 14.spx,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('OK'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

    _isOtpSentAlertVisible = false;
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller.phoneController,
      validator: controller.validatePhone,
      keyboardType: TextInputType.phone,
      maxLength: AuthController.phoneDigitLength,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AuthController.phoneDigitLength),
      ],
      onChanged: (value) {
        final digits = value.replaceAll(RegExp(r'\D'), '');
        if (digits != value) {
          controller.phoneController.value = TextEditingValue(
            text: digits,
            selection: TextSelection.collapsed(offset: digits.length),
          );
        }
      },
      style: TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        fontSize: 14.spx,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Enter 10-Digit Mobile Number',
        hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 15.spx),
        filled: true,
        fillColor: const Color(0xFFFAFBFF),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12.wpx,
          vertical: 13.hpx,
        ),
        prefixIconConstraints: BoxConstraints(minWidth: 0.wpx),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 14.wpx, right: 8.wpx),
          child: Center(
            widthFactor: 1,
            child: Text(
              AuthController.dialCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                fontSize: 15.spx,
              ),
            ),
          ),
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller.phoneController,
          builder: (context, value, _) {
            if (value.text.isEmpty) return SizedBox.shrink();
            return IconButton(
              onPressed: controller.phoneController.clear,
              icon: Icon(
                Icons.close,
                color: AppColors.textSecondary,
                size: 16.spx,
              ),
            );
          },
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.rpx),
          borderSide: BorderSide(color: Color(0x26092774), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.rpx),
          borderSide: BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}

class _OtpSection extends StatelessWidget {
  const _OtpSection({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              Text(
                'A verification code has been sent to',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary.withValues(alpha: 0.78),
                  fontSize: 14.spx,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                controller.pendingPhone.value,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.spx,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 9.hpx),
        TextFormField(
          controller: controller.otpController,
          validator: controller.validateOtp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            fontSize: 15.spx,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 6-Digit OTP',
            hintStyle: TextStyle(
              color: Color(0xFF999999),
              fontSize: 14.spx,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: const Color(0xFFFAFBFF),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.wpx,
              vertical: 11.hpx,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14.wpx, right: 8.wpx),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'OTP',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    fontSize: 14.spx,
                  ),
                ),
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0.wpx),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.rpx),
              borderSide: BorderSide(color: Color(0x26092774), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.rpx),
              borderSide: BorderSide(color: AppColors.primary, width: 1.2),
            ),
          ),
        ),
        SizedBox(height: 5.hpx),
        Obx(() {
          final seconds = controller.resendTimer.value;
          final isBusy =
              controller.isSendingOtp.value || controller.isVerifyingOtp.value;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: isBusy || seconds > 0 ? null : controller.resendOtp,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  seconds > 0
                      ? 'Resend OTP in 00:${seconds.toString().padLeft(2, '0')}'
                      : 'Resend OTP',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 15.spx,
                    fontWeight: FontWeight.w800,
                    color: isBusy || seconds > 0
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: isBusy ? null : controller.changeNumber,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: Text(
                  'Change Number',
                  style: TextStyle(
                    color: AppColors.primary,
                    decoration: TextDecoration.underline,
                    fontSize: 15.spx,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        }),
        SizedBox(height: 4.hpx),
      ],
    );
  }
}
