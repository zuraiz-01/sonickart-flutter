import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

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
                    constraints: BoxConstraints(maxWidth: 400.wpx),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.rpx),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(24.rpx),
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
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 26.spx,
                                  ),
                                ),
                              ),
                              SizedBox(height: 20.hpx),
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
                                            4,
                                          ),
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        child: controller.agreementChecked.value
                                            ? Icon(
                                                Icons.check,
                                                size: 14,
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
                                            fontSize: 12.spx.spx,
                                            height: 1.5,
                                            letterSpacing: 0.4,
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
                                  onPressed: controller.isOtpSent.value
                                      ? (controller.canSubmitOtp
                                            ? controller.verifyOtp
                                            : null)
                                      : (controller.canSubmitPhone
                                            ? controller.sendOtp
                                            : null),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: AppColors.white,
                                    minimumSize: Size.fromHeight(50),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        10.rpx,
                                      ),
                                    ),
                                    textStyle: TextStyle(
                                      fontSize: 16.spx.spx,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    disabledBackgroundColor: AppColors.accent
                                        .withValues(alpha: 0.55),
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
                  fontSize: 10.spx.spx,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
        letterSpacing: 0.5,
        fontSize: 15.spx.spx,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Enter 10-digit mobile number',
        hintStyle: TextStyle(color: Color(0xFF999999)),
        filled: true,
        fillColor: AppColors.white.withValues(alpha: 0.82),
        prefixIconConstraints: BoxConstraints(minWidth: 0.wpx),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: 16, right: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              AuthController.dialCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 15.spx.spx,
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
              icon: Icon(Icons.close, color: AppColors.textSecondary),
            );
          },
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: Color(0x2E092774), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.rpx),
          borderSide: BorderSide(color: Color(0x2E092774), width: 1.5),
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
                  color: AppColors.primary,
                  fontSize: 12.spx.spx,
                ),
              ),
              SizedBox(height: 2),
              Text(
                controller.pendingPhone.value,
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.spx.spx,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.hpx),
        TextFormField(
          controller: controller.otpController,
          validator: controller.validateOtp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            fontSize: 15.spx.spx,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 6-digit OTP',
            hintStyle: TextStyle(color: Color(0xFF999999)),
            filled: true,
            fillColor: AppColors.white.withValues(alpha: 0.82),
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'OTP',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    fontSize: 15.spx.spx,
                  ),
                ),
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0.wpx),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.rpx),
              borderSide: BorderSide(color: Color(0x2E092774), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.rpx),
              borderSide: BorderSide(color: Color(0x2E092774), width: 1.5),
            ),
          ),
        ),
        SizedBox(height: 6.hpx),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed:
                  controller.isSendingOtp.value ||
                      controller.isVerifyingOtp.value ||
                      controller.resendTimer.value > 0
                  ? null
                  : controller.resendOtp,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                controller.resendTimer.value > 0
                    ? 'Resend OTP in 00:${controller.resendTimer.value.toString().padLeft(2, '0')}'
                    : 'Resend OTP',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 12.spx.spx,
                  fontWeight: FontWeight.w600,
                  color:
                      controller.isSendingOtp.value ||
                          controller.isVerifyingOtp.value ||
                          controller.resendTimer.value > 0
                      ? AppColors.primary.withValues(alpha: 0.55)
                      : AppColors.primary,
                ),
              ),
            ),
            TextButton(
              onPressed:
                  controller.isSendingOtp.value ||
                      controller.isVerifyingOtp.value
                  ? null
                  : controller.changeNumber,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Change Number',
                style: TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  fontSize: 12.spx.spx,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.hpx),
      ],
    );
  }
}
