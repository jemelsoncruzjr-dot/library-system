import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/school.dart';
import '../theme/app_theme.dart';

class LibraryCard extends StatelessWidget {
  const LibraryCard({
    super.key,
    required this.name,
    required this.lrn,
    required this.gradeSection,
    required this.validated,
  });

  final String name;
  final String lrn;
  final String gradeSection;
  final bool validated;

  @override
  Widget build(BuildContext context) {
    final stampColor = validated ? AppColors.success : AppColors.muted;

    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBF7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brass, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.5),
          child: CustomPaint(
            painter: _RulePainter(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          School.logoAsset,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              School.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.newsreader(
                                fontSize: 12.5,
                                height: 1.15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Library card',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.newsreader(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LRN  $lrn',
                    style: GoogleFonts.publicSans(
                      fontSize: 13,
                      letterSpacing: 1.1,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          gradeSection,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.publicSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: -0.1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: stampColor, width: 2),
                          ),
                          child: Text(
                            validated ? 'Validated' : 'Not validated',
                            style: GoogleFonts.publicSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: stampColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x160D58BB)
      ..strokeWidth = 1;
    for (double y = size.height * 0.36; y < size.height - 10; y += 22) {
      canvas.drawLine(Offset(16, y), Offset(size.width - 16, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}