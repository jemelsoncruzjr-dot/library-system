import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/school.dart';
import '../theme/app_theme.dart';
import 'library_card.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({super.key, required this.child, this.maxWidth = 440});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;

          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!wide) ...[
                      const BrandMark(light: false),
                      const SizedBox(height: 28),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          );

          if (!wide) return form;

          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: form),
            ],
          );
        },
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.light, this.logoSize = 44});

  final bool light;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppColors.green;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            School.logoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              School.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.newsreader(
                fontSize: 17,
                height: 1.15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.green,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandMark(light: true),
                      const Spacer(),
                      Center(
                        child: Transform.rotate(
                          angle: -0.05,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 380),
                            child: LibraryCard(
                              name: 'Maria Santos',
                              lrn: '123456789012',
                              gradeSection: 'Grade 11 - Section A',
                              validated: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'Validate your library card online.',
                        style: GoogleFonts.newsreader(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Upload your Certificate of Registration once. The librarian reviews it, and your status updates right here.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Color(0xCCFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14B3261E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66B3261E)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldRow extends StatelessWidget {
  const FieldRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 18),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          children[i],
        ],
      ],
    );
  }
}