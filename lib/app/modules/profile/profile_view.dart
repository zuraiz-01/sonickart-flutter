import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import 'controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.currentUser;
      return Stack(
        children: [
          Container(
            color: Color(0xFFF5F8FF),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16.wpx, 14.hpx, 16.wpx, 24.hpx),
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(18.wpx, 16.hpx, 18.wpx, 18.hpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(22.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(999.rpx),
                            ),
                            child: Text(
                              'MY PROFILE',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.spx,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Spacer(),
                          OutlinedButton.icon(
                            onPressed: controller.openEditProfile,
                            icon: Icon(Icons.edit_outlined, size: 16),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              backgroundColor: Color(0xFFF7F9FF),
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999.rpx),
                              ),
                            ),
                            label: Text(
                              'Edit',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.hpx),
                      Container(
                        width: 100.wpx,
                        height: 100.hpx,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(50.rpx),
                        ),
                        child: Text(
                          controller.initials,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      SizedBox(height: 14.hpx),
                      Text(
                        'Your Account',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 6.hpx),
                      Text(
                        user?.name ?? user?.phone ?? 'Guest User',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      SizedBox(height: 6.hpx),
                      Text(
                        user?.phone ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((user?.email ?? '').isNotEmpty) ...[
                        SizedBox(height: 4.hpx),
                        Text(
                          user!.email,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      SizedBox(height: 18.hpx),
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
                SizedBox(height: 20.hpx),
                Container(
                  padding: EdgeInsets.all(20.rpx),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44.wpx,
                        height: 44.hpx,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.rpx),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.accent,
                        ),
                      ),
                      SizedBox(width: 12.wpx),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SonicKart Wallet & Gift Card',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            SizedBox(height: 4.hpx),
                            Text(
                              'Manage payments and offers at one place',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.hpx),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Balance',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            SizedBox(height: 4.hpx),
                            Text(
                              'Rs 0',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => controller.openInfoModal('wallet'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.rpx),
                          ),
                        ),
                        child: Text(
                          'Add Balance',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.hpx),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18.rpx),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MenuAction(
                        icon: Icons.currency_exchange_outlined,
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
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        onTap: () =>
                            controller.handleMenuAction('notifications'),
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
                SizedBox(height: 20.hpx),
                OutlinedButton.icon(
                  onPressed: controller.logout,
                  icon: Icon(Icons.logout_rounded, color: AppColors.accent),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.white,
                    side: BorderSide(color: AppColors.primary),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.rpx),
                    ),
                  ),
                  label: Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.w800),
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
}

class _QuickActionCard extends StatelessWidget {
  _QuickActionCard({
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
      borderRadius: BorderRadius.circular(16.rpx),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.hpx, horizontal: 10.wpx),
        decoration: BoxDecoration(
          color: Color(0xFFF3F7FF),
          borderRadius: BorderRadius.circular(16.rpx),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            SizedBox(height: 8.hpx),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  _MenuAction({
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
                Icon(icon, color: AppColors.accent, size: 20),
                SizedBox(width: 15.wpx),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(
            height: 1,
            margin: EdgeInsets.only(left: 15),
            color: AppColors.primary.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

class _EditProfileDialog extends StatelessWidget {
  _EditProfileDialog({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    if (!controller.isEditModalVisible.value) {
      return SizedBox.shrink();
    }
    return _OverlayCard(
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
          SizedBox(height: 12.hpx),
          TextField(
            controller: controller.emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
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
  }
}

class _InfoDialog extends StatelessWidget {
  _InfoDialog({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final key = controller.activeInfoModal.value;
    if (key == null) {
      return SizedBox.shrink();
    }
    final content = _modalCopy[key] ?? _modalCopy['default']!;
    return _OverlayCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
  }
}

class _OverlayCard extends StatelessWidget {
  _OverlayCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
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
    );
  }
}

Map<String, (String, String)> _modalCopy = {
  'notifications': (
    'Notifications',
    'Notification preferences will be available shortly.',
  ),
  'rewards': ('Rewards', 'Earn points on every order. Feature coming soon!'),
  'giftcards': (
    'Gift Cards',
    'Purchase and send gift cards to your loved ones. Feature coming soon!',
  ),
  'suggest': (
    'Suggest Products',
    'Have a product suggestion? We would love to hear from you. Feature coming soon!',
  ),
  'refunds': (
    'Refunds',
    'View and manage your refund requests. Feature coming soon!',
  ),
  'about': (
    'About',
    'SonicKart profile flow Flutter mein same journey ke sath ready hai.',
  ),
  'wallet': (
    'Wallet',
    'Wallet top-up flow aglay step ke liye placeholder ke sath ready hai.',
  ),
  'default': ('Coming Soon', 'This section will be available shortly.'),
};
