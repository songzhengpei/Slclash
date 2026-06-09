import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/cache.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/database/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';

class CommonTargetIcon extends StatelessWidget {
  final String src;

  const CommonTargetIcon({super.key, required this.src});

  Widget _defaultIcon() {
    return const Icon(IconsExt.target);
  }

  Widget _buildIcon() {
    if (src.isEmpty) {
      return _defaultIcon();
    }

    final base64 = src.getBase64;
    if (base64 != null) {
      return Image.memory(
        base64,
        gaplessPlayback: true,
        errorBuilder: (_, error, _) {
          return _defaultIcon();
        },
      );
    }

    return ImageCacheWidget(src: src, defaultWidget: _defaultIcon());
  }

  @override
  Widget build(BuildContext context) {
    return _buildIcon();
  }
}

final _cacheMange = DefaultCacheManager();

class ImageCacheWidget extends StatefulWidget {
  final String src;
  final Widget defaultWidget;

  const ImageCacheWidget({
    super.key,
    required this.src,
    required this.defaultWidget,
  });

  @override
  State<ImageCacheWidget> createState() => _ImageCacheWidgetState();
}

class _ImageCacheWidgetState extends State<ImageCacheWidget> {
  final ValueNotifier<File?> _imageNotifier = ValueNotifier(null);
  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _getImageFormCache();
  }

  @override
  void didUpdateWidget(covariant ImageCacheWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.src != widget.src) {
      _getImageFormCache();
    }
  }

  void _getImageFormCache() {
    _imageNotifier.value = null;
    final src = widget.src;
    if (src.isEmpty) {
      return;
    }
    _streamSubscription?.cancel();
    _streamSubscription = _cacheMange
        .getFileStreamV2(
          src,
          onRemoteNewLoaded: () {
            commonPrint.log('The icon has been recorded: $src');
            database.iconRecordsDao.putIfAbsent(src);
          },
        )
        .listen((data) {
          if (mounted) {
            _imageNotifier.value = data.file;
          }
        });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _imageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<File?>(
      valueListenable: _imageNotifier,
      builder: (_, data, _) {
        if (data == null) {
          return widget.defaultWidget;
        }
        return CommonImage(
          data: data,
          isSvg: widget.src.isSvg,
          errorBuilder: (_, _, _) {
            return widget.defaultWidget;
          },
        );
      },
    );
  }
}

class CommonImage extends StatelessWidget {
  final File data;
  final bool isSvg;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )?
  errorBuilder;

  const CommonImage({
    super.key,
    required this.data,
    this.errorBuilder,
    this.isSvg = false,
  });

  @override
  Widget build(BuildContext context) {
    return isSvg
        ? SvgPicture.file(data, errorBuilder: errorBuilder)
        : Image.file(data, errorBuilder: errorBuilder);
  }
}
