import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Homesol/services/image_cache_manager.dart';
import 'package:Homesol/services/auth_service.dart';

class CachedImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.color,
    this.colorBlendMode,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends State<CachedImage> {
  String? _localPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _localPath = null;
        });
      }
      return;
    }

    // Try to get from our custom local cache first (for pre-downloaded images)
    final cachedPath = await ImageCacheManager.getCachedImagePath(widget.imageUrl);
    if (mounted) {
      setState(() {
        _localPath = cachedPath;
        _isLoading = false;
      });
    }
  }

  String _buildFullUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${AuthService.baseUrl}$url';
  }

  @override
  Widget build(BuildContext context) {
    Widget image;
    final fullUrl = _buildFullUrl(widget.imageUrl);

    if (_isLoading) {
      image = widget.placeholder ?? _buildDefaultPlaceholder();
    } else if (_localPath != null && File(_localPath!).existsSync()) {
      image = Image.file(
        File(_localPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
      );
    } else if (fullUrl.isNotEmpty) {
      // Use CachedNetworkImage for robust caching and state handling
      image = CachedNetworkImage(
        imageUrl: fullUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        color: widget.color,
        colorBlendMode: widget.colorBlendMode,
        placeholder: (context, url) => widget.placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) => widget.errorWidget ?? _buildDefaultError(),
      );
    } else {
      image = widget.errorWidget ?? _buildDefaultError();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}
