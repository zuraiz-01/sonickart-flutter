import 'package:flutter/material.dart';
import 'package:sonic_cart/app/core/utils/responsive.dart';

import '../../../../theme/app_colors.dart';

class AuthScaffold extends StatelessWidget {
  AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFDDF6EE), Color(0xFFF9F3D9), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.rpx),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 460.wpx),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.rpx),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(14.rpx),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(18.rpx),
                          ),
                          child: Icon(
                            Icons.shopping_basket_rounded,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                        SizedBox(height: 20.hpx),
                        Text(title, style: theme.textTheme.headlineSmall),
                        SizedBox(height: 8.hpx),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                        SizedBox(height: 24.hpx),
                        child,
                        if (footer != null) ...[
                          SizedBox(height: 18.hpx),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
