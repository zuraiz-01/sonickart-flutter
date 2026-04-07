import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF01296F),
              Color(0xFF002870),
              Color(0xFF001F50),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.overlayBlue),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.38),
                              ),
                              boxShadow: const [
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
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          letterSpacing: 0.8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    if (!controller.isOtpSent.value)
                                      _PhoneField(controller: controller)
                                    else
                                      _OtpSection(controller: controller),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: controller.toggleAgreement,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 20,
                                              height: 20,
                                              margin: const EdgeInsets.only(top: 1),
                                              decoration: BoxDecoration(
                                                color: controller.agreementChecked.value
                                                    ? AppColors.primary
                                                    : AppColors.white,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: AppColors.primary,
                                                  width: 2,
                                                ),
                                              ),
                                              child: controller.agreementChecked.value
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: AppColors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'By continuing you agree to SonicKart\'s Terms & Conditions and Privacy Policy.',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: AppColors.primary,
                                                  fontSize: 12,
                                                  height: 1.5,
                                                  letterSpacing: 0.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: controller.isOtpSent.value
                                            ? (controller.isVerifyingOtp.value
                                                ? null
                                                : controller.verifyOtp)
                                            : (controller.isSendingOtp.value
                                                ? null
                                                : controller.sendOtp),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.accent,
                                          foregroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 15),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: controller.isSendingOtp.value ||
                                                controller.isVerifyingOtp.value
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: AppColors.primary,
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
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    color: AppColors.primary,
                    child: Text(
                      'Your city\'s essentials, delivered fast.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 0.6,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      maxLength: 10,
      onChanged: (value) {
        final digits = value.replaceAll(RegExp(r'\D'), '');
        if (digits != value) {
          controller.phoneController.value = TextEditingValue(
            text: digits,
            selection: TextSelection.collapsed(offset: digits.length),
          );
        }
      },
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Enter 10-digit mobile number',
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Center(
            widthFactor: 1,
            child: Text(
              AuthController.dialCode,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        suffixIcon: controller.phoneController.text.isNotEmpty
            ? IconButton(
                onPressed: controller.phoneController.clear,
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }
}

class _OtpSection extends StatelessWidget {
  const _OtpSection({required this.controller});

  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Text(
                'A verification code has been sent to',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                controller.pendingPhone.value,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: controller.otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            counterText: '',
            hintText: 'Enter 6-digit OTP',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Center(
                widthFactor: 1,
                child: Text(
                  'OTP',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 0),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: controller.isSendingOtp.value ||
                      controller.isVerifyingOtp.value ||
                      controller.resendTimer.value > 0
                  ? null
                  : controller.resendOtp,
              child: Text(
                controller.resendTimer.value > 0
                    ? 'Resend OTP in 00:${controller.resendTimer.value.toString().padLeft(2, '0')}'
                    : 'Resend OTP',
                style: const TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            TextButton(
              onPressed: controller.isSendingOtp.value || controller.isVerifyingOtp.value
                  ? null
                  : controller.changeNumber,
              child: const Text(
                'Change Number',
                style: TextStyle(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
