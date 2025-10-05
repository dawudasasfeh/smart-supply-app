import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default placeholder
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: (width != null && width! < 60) ? 24 : 48,
        ),
      ),
    );

    // Default error widget
    final defaultError = Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: (width != null && width! < 60) ? 24 : 48,
        ),
      ),
    );

    // Check if image URL is valid
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? defaultError;
    }

    Widget imageWidget;

    // Use CachedNetworkImage for better performance
    imageWidget = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultError,
    );

    // Apply border radius if provided
    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}
