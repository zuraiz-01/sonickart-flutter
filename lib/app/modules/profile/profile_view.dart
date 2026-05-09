import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../core/utils/phone_dialer.dart';
import '../../theme/app_colors.dart';
import '../dashboard/controllers/dashboard_controller.dart' as dashboard;
import 'controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.currentUser;
      final phone = user?.phone ?? '';
      return Stack(
        children: [
          Container(
            color: Color(0xFFF6F8FC),
            child: ListView(
              padding: EdgeInsets.fromLTRB(12.wpx, 12.hpx, 12.wpx, 18.hpx),
              children: [
                SizedBox(
                  height: 28.hpx,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => _handleBack(context),
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        constraints: BoxConstraints.tightFor(
                          width: 28.wpx,
                          height: 28.hpx,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 17.spx,
                              ),
                        ),
                      ),
                      SizedBox(width: 28.wpx),
                    ],
                  ),
                ),
                SizedBox(height: 8.hpx),
                Container(
                  padding: EdgeInsets.fromLTRB(14.wpx, 12.hpx, 14.wpx, 14.hpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x12092774),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.wpx,
                              vertical: 4.hpx,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF3F6FF),
                              borderRadius: BorderRadius.circular(999.rpx),
                            ),
                            child: Text(
                              'MY PROFILE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14.spx,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          Spacer(),
                          OutlinedButton.icon(
                            onPressed: controller.openEditProfile,
                            icon: Icon(Icons.edit_outlined, size: 11),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              backgroundColor: AppColors.white,
                              side: BorderSide(
                                color: AppColors.primary.withValues(
                                  alpha: 0.18,
                                ),
                              ),
                              minimumSize: Size(0, 28.hpx),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.wpx,
                                vertical: 0,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.rpx),
                              ),
                            ),
                            label: Text(
                              'Edit',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.spx,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.hpx),
                      Container(
                        width: 82.wpx,
                        height: 82.hpx,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(41.rpx),
                        ),
                        child: Text(
                          controller.initials,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      SizedBox(height: 12.hpx),
                      Text(
                        'Your Account',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                          fontSize: 15.spx,
                        ),
                      ),
                      SizedBox(height: 4.hpx),
                      Text(
                        user?.name ?? user?.phone ?? 'Guest User',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.spx,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        SizedBox(height: 4.hpx),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => PhoneDialer.open(phone),
                          child: Text(
                            phone,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.spx,
                                ),
                          ),
                        ),
                      ],
                      if ((user?.email ?? '').isNotEmpty) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          user!.email,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 15.spx,
                              ),
                        ),
                      ],
                      SizedBox(height: 14.hpx),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.receipt_long_outlined,
                              label: 'Orders',
                              onTap: controller.openOrders,
                            ),
                          ),
                          SizedBox(width: 10.wpx),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.help_outline_rounded,
                              label: 'Help',
                              onTap: controller.openHelp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.hpx),
                Container(
                  padding: EdgeInsets.all(12.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8.rpx),
                    border: Border.all(
                      color: AppColors.primaryDark.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1F092774),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32.wpx,
                            height: 32.hpx,
                            decoration: BoxDecoration(
                              color: AppColors.primaryDark,
                              borderRadius: BorderRadius.circular(5.rpx),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.accent,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 9.wpx),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SonicKart Wallet & Gift Card',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.spx,
                                      ),
                                ),
                                SizedBox(height: 3.hpx),
                                Text(
                                  'Manage payments and offers at one place',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14.spx,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.hpx),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Available Balance',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.78,
                                        ),
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0,
                                        fontSize: 15.spx,
                                      ),
                                ),
                                SizedBox(height: 3.hpx),
                                Text(
                                  '₹${controller.walletBalance.value.toStringAsFixed(0)}',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14.spx,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => controller.openInfoModal('wallet'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.wpx,
                                vertical: 8.hpx,
                              ),
                              minimumSize: Size(0, 30.hpx),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.rpx),
                              ),
                            ),
                            child: Text(
                              'Add Balance',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15.spx,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.hpx),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MenuAction(
                        icon: Icons.keyboard_return_rounded,
                        label: 'Refunds',
                        onTap: () => controller.handleMenuAction('refunds'),
                      ),
                      _MenuAction(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Gift Cards',
                        onTap: () => controller.handleMenuAction('giftcards'),
                      ),
                      _MenuAction(
                        icon: Icons.location_on_outlined,
                        label: 'Addresses',
                        onTap: () => controller.handleMenuAction('addresses'),
                      ),
                      _MenuAction(
                        icon: Icons.star_outline_rounded,
                        label: 'Rewards',
                        onTap: () => controller.handleMenuAction('rewards'),
                      ),
                      _MenuAction(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Suggest Products',
                        onTap: () => controller.handleMenuAction('suggest'),
                      ),
                      _MenuAction(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        onTap: () => controller.handleMenuAction('about'),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.hpx),
                OutlinedButton.icon(
                  onPressed: controller.logout,
                  icon: Icon(Icons.logout_rounded, color: AppColors.accent),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.white,
                    side: BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6.rpx),
                    ),
                  ),
                  label: Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.spx,
                    ),
                  ),
                ),
                if ((controller.statusMessage.value ?? '').isNotEmpty) ...[
                  SizedBox(height: 14.hpx),
                  Container(
                    padding: EdgeInsets.all(12.rpx),
                    decoration: BoxDecoration(
                      color: Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(12.rpx),
                    ),
                    child: Text(
                      controller.statusMessage.value!,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _EditProfileDialog(controller: controller),
          _InfoDialog(controller: controller),
        ],
      );
    });
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Get.back<void>();
      return;
    }

    dashboard.openDashboardTab(0);
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.hpx, horizontal: 8.wpx),
        decoration: BoxDecoration(
          color: Color(0xFFF7F9FF),
          borderRadius: BorderRadius.circular(6.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 17),
            SizedBox(height: 6.hpx),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14.spx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.wpx, vertical: 15.hpx),
            child: Row(
              children: [
                Icon(icon, color: AppColors.accent, size: 20.rpx),
                SizedBox(width: 15.wpx),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.spx,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20.rpx,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: EdgeInsets.only(left: 15.wpx),
            color: AppColors.black.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}

class _EditProfileDialog extends StatelessWidget {
  const _EditProfileDialog({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isEditModalVisible.value) {
        return SizedBox.shrink();
      }
      return _OverlayCard(
        onDismiss: controller.closeEditProfile,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit Profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16.hpx),
            TextField(
              controller: controller.nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            SizedBox(height: 12.hpx),
            TextField(
              controller: controller.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.call_outlined),
              ),
            ),
            SizedBox(height: 16.hpx),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.closeEditProfile,
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 12.wpx),
                Expanded(
                  child: FilledButton(
                    onPressed: controller.saveProfile,
                    child: controller.isSavingProfile.value
                        ? SizedBox(
                            width: 16.wpx,
                            height: 16.hpx,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final key = controller.activeInfoModal.value;
      if (key == null) {
        return SizedBox.shrink();
      }
      final content = controller.infoModalContent(key);
      return _OverlayCard(
        onDismiss: controller.closeInfoModal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.rpx,
              height: 80.rpx,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                _modalIcon(key),
                color: AppColors.accent,
                size: 48.rpx,
              ),
            ),
            SizedBox(height: 20.hpx),
            Text(
              content.$1,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 16.hpx),
            Text(
              content.$2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16.hpx),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controller.closeInfoModal,
                child: Text('OK'),
              ),
            ),
          ],
        ),
      );
    });
  }

  IconData _modalIcon(String key) {
    return switch (key) {
      'refunds' => Icons.keyboard_return_rounded,
      'giftcards' => Icons.card_giftcard_outlined,
      'rewards' => Icons.star_outline_rounded,
      'suggest' => Icons.lightbulb_outline_rounded,
      'notifications' => Icons.notifications_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      _ => Icons.info_outline_rounded,
    };
  }
}

class _OverlayCard extends StatelessWidget {
  const _OverlayCard({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: EdgeInsets.all(20.rpx),
                padding: EdgeInsets.all(20.rpx),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16.rpx),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x26092774),
                      blurRadius: 18,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
