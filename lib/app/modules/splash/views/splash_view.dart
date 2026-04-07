import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF01296F),
              Color(0xFF002870),
              AppColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Icon(
                      Icons.shopping_basket_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'SonicKart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Your city\'s essentials, delivered fast.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xE6FFFFFF),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: 140,
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                    color: Colors.white,
                    backgroundColor: Color(0x33FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
