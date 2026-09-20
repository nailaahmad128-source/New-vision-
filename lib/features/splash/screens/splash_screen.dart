
import 'package:flutter/material.dart';

class ScanFlowSplashScreen extends StatefulWidget {
  final double progress;
  final String status;

  const ScanFlowSplashScreen({
    super.key,
    required this.progress,
    required this.status,
  });

  @override
  State<ScanFlowSplashScreen> createState() => _ScanFlowSplashScreenState();
}

class _ScanFlowSplashScreenState extends State<ScanFlowSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 42),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Documents.\nSimplified.',
                    style: TextStyle(
                      color: Color(0xFF173047),
                      fontSize: 18,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'SIMPLE\nFAST\nRELIABLE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Color(0xFF71818A),
                      fontSize: 9,
                      height: 1.65,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  final scale = 1.0 + (_logoController.value * 0.018);
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: Container(
                  width: 142,
                  height: 142,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C9A7).withValues(alpha: .14),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(31),
                    child: Image.asset(
                      'assets/images/scanflow_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2.2,
                  ),
                  children: [
                    TextSpan(
                      text: 'Scan',
                      style: TextStyle(color: Color(0xFF10263A)),
                    ),
                    TextSpan(
                      text: 'Flow',
                      style: TextStyle(color: Color(0xFF00BFA5)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 9),

              const Text(
                'Scan  •  Convert  •  Edit  •  Sign',
                style: TextStyle(
                  color: Color(0xFF657782),
                  fontSize: 15,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(flex: 2),

              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: progress,
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Column(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6ECEA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C9A7),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C9A7)
                                      .withValues(alpha: .25),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          widget.status,
                          key: ValueKey(widget.status),
                          style: const TextStyle(
                            color: Color(0xFF536873),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 42),

              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Feature(
                    icon: Icons.verified_user_outlined,
                    title: 'Secure',
                  ),
                  _Divider(),
                  _Feature(
                    icon: Icons.bolt_rounded,
                    title: 'Fast',
                  ),
                  _Divider(),
                  _Feature(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Simple',
                  ),
                ],
              ),

              const Spacer(),

              Container(
                height: 54,
                width: double.infinity,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(80),
                  ),
                  color: Color(0xFFE5F7F3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Feature({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF00B89C),
          size: 21,
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF71818A),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0xFFD7E5E1),
    );
  }
}
