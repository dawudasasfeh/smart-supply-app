import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class StandardAppBar {
  static PreferredSizeWidget build({
    required BuildContext context,
    required bool isDark,
    required String title,
    String leadingEmoji = '',
    IconData? leadingIcon,
    Gradient? leadingGradient,
    String? subtitle,
    List<Widget> rightActions = const [],
    bool showBack = false,
  }) {
    final textColor = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF1E293B);
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return AppBar(
      elevation: 0,
      toolbarHeight: 72,
      backgroundColor: isDark ? Colors.black : Colors.white,
      foregroundColor: textColor,
      automaticallyImplyLeading: showBack,
      titleSpacing: 16,
      title: Row(
        children: [
          if (leadingEmoji.isNotEmpty || leadingIcon != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: leadingGradient ?? const LinearGradient(
                  colors: [Color(0xFFFF8A50), Color(0xFFFF6E40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: leadingGradient == null ? const Color(0xFFFF6E40) : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.20 : 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: leadingIcon != null
                  ? Icon(leadingIcon, size: 20, color: Colors.white)
                  : Text(leadingEmoji, style: const TextStyle(fontSize: 18, color: Colors.white)),
            ),
          if (leadingEmoji.isNotEmpty || leadingIcon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
                if ((subtitle?.isNotEmpty ?? false))
                  Text(
                    subtitle ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: subtextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        ...rightActions,
        const SizedBox(width: 12),
      ],
      systemOverlayStyle: isDark
          ? const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
    );
  }

  static Widget roundedAction({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.20 : 0.10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: isDark ? Colors.black : Colors.white),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}
