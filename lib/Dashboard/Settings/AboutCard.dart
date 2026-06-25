import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:womensafteyhackfair/constants.dart';

class AboutCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String desc;
  final String asset;
  final double sizeFactor;
  final IconData? icon;
  final Widget? child;
  final Color? glowColor;
  final VoidCallback? onTap;

  const AboutCard({
    Key? key,
    required this.asset,
    required this.desc,
    required this.subtitle,
    required this.title,
    required this.sizeFactor,
    this.icon,
    this.child,
    this.glowColor,
    this.onTap,
  }) : super(key: key);

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final double scale = _isPressed ? 0.98 : (_isHovered ? 1.02 : 1.0);
    final double offset = _isHovered ? -4.0 : 0.0;
    final double shadowBlur = _isHovered ? 20.0 : 12.0;
    final double shadowOpacity = _isHovered ? 0.15 : 0.05;

    // Responsive design layout support
    final double? cardHeight = (widget.sizeFactor > 0 && widget.sizeFactor < 10)
        ? (MediaQuery.of(context).size.height / widget.sizeFactor)
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          width: MediaQuery.of(context).size.width,
          height: cardHeight,
          transform: Matrix4.translationValues(0.0, offset, 0.0) *
              Matrix4.diagonal3Values(scale, scale, 1.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.glowColor ?? AppColors.primaryPurple).withOpacity(shadowOpacity),
                blurRadius: shadowBlur,
                spreadRadius: _isHovered ? 3 : 1,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Stack(
                children: [
                  // Subtle internal gradient wash
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.12),
                            (widget.glowColor ?? AppColors.primaryPurple).withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // Content padding and distribution
                  Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: widget.child ?? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (widget.asset.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    widget.asset.startsWith("assets")
                                        ? widget.asset
                                        : "assets/${widget.asset}.png",
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        widget.icon ?? Icons.shield_outlined,
                                        color: AppColors.primaryPurple,
                                        size: 32,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                            ] else if (widget.icon != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: AppColors.primaryPurple,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.subtitle,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (widget.desc.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          if (cardHeight != null)
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Text(
                                  widget.desc,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.mutedText,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                          else
                            Text(
                              widget.desc,
                              style: GoogleFonts.poppins(
                                color: AppColors.mutedText,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                        ],
                      ],
                    ),
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
