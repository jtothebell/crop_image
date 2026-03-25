import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'crop_controller.dart';
import 'crop_grid.dart';
import 'crop_rect.dart';
import 'crop_rotation.dart';

/// How the user adjusts the crop region in [CropImage].
enum CropInteractionMode {
  /// Drag corner handles and the interior to resize and move the crop rect.
  handles,

  /// Pinch to zoom and pan. Only the crop viewport shows the sharp image; the
  /// surround is [CropImage.scrimColor], or a dimmed full-image preview while
  /// the user is gesturing ([CropImage.panZoomSurroundOpacity]).
  panZoom,
}

/// Widget to crop images.
///
/// Use [interactionMode] to choose either draggable corner handles ([CropInteractionMode.handles],
/// default) or a fixed viewport with pinch-zoom and pan ([CropInteractionMode.panZoom]).
///
/// See also:
///
///  * [CropController] to control the functioning of this widget.
class CropImage extends StatefulWidget {
  /// Controls the crop values being applied.
  ///
  /// If null, this widget will create its own [CropController]. If you want to specify initial values of
  /// [aspectRatio] or [defaultCrop], you need to use your own [CropController].
  /// Otherwise, [aspectRatio] will not be enforced and the [defaultCrop] will be the full image.
  final CropController? controller;

  /// The image to be cropped.
  final Image image;

  /// The crop grid color of the outer lines.
  ///
  /// Defaults to 70% white.
  final Color gridColor;

  /// The crop grid color of the inner lines.
  ///
  /// Defaults to `gridColor`.
  final Color gridInnerColor;

  /// The crop grid color of the corner lines.
  ///
  /// Defaults to `gridColor`.
  final Color gridCornerColor;

  /// The size of the padding around the image and crop grid.
  ///
  /// Defaults to 0.
  final double paddingSize;

  /// The size of the touch area.
  ///
  /// Defaults to 50.
  final double touchSize;

  /// The size of the corner of the crop grid.
  ///
  /// Defaults to 25.
  final double gridCornerSize;

  /// The offset of the corner handles from the crop grid edges.
  ///
  /// Positive values move the corners outside the grid. Defaults to 0.
  final double cornerOffset;

  /// Whether to display the corners.
  ///
  /// Defaults to true.
  final bool showCorners;

  /// The width of the crop grid thin lines.
  ///
  /// Defaults to 2.
  final double gridThinWidth;

  /// The width of the crop grid thick lines.
  ///
  /// Defaults to 5.
  final double gridThickWidth;

  /// The crop grid scrim (outside area overlay) color.
  ///
  /// Defaults to 54% black.
  final Color scrimColor;

  /// True if third lines of the crop grid are always displayed.
  /// False if third lines are only displayed while the user manipulates the grid.
  ///
  /// Defaults to false.
  final bool alwaysShowThirdLines;

  /// Event called when the user changes the crop rectangle.
  ///
  /// The passed [Rect] is normalized between 0 and 1.
  ///
  /// See also:
  ///
  ///  * [CropController], which can be used to read this and other details of the crop rectangle.
  final ValueChanged<Rect>? onCrop;

  /// The minimum pixel size the crop rectangle can be shrunk to.
  ///
  /// Defaults to 100.
  final double minimumImageSize;

  /// The maximum pixel size the crop rectangle can be grown to.
  ///
  /// Defaults to infinity.
  /// You can constrain the crop rectangle to a fixed size by setting
  /// both [minimumImageSize] and [maximumImageSize] to the same value (the width) and using
  /// the [aspectRatio] of the controller to force the other dimension (width / height).
  /// Doing so disables the display of the corners.
  final double maximumImageSize;

  /// When `true`, moves when panning beyond corners, even beyond the crop rect.
  /// When `false`, moves when panning beyond corners but inside the crop rect.
  ///
  /// Ignored when [interactionMode] is [CropInteractionMode.panZoom].
  final bool alwaysMove;

  /// Whether to use corner handles or pan/pinch gestures.
  ///
  /// Defaults to [CropInteractionMode.handles].
  final CropInteractionMode interactionMode;

  /// Draw a thin border around the visible crop viewport in [CropInteractionMode.panZoom].
  ///
  /// Defaults to true.
  final bool showPanZoomViewportBorder;

  /// Fill color behind the image inside the pan-zoom viewport when overscrolled zoom-out
  /// ([CropInteractionMode.panZoom]) makes the image smaller than the viewport.
  ///
  /// Defaults to a light grey (`0xFFE8E8E8`).
  final Color panZoomLetterboxColor;

  /// During a pan-zoom gesture, the scrim region outside the viewport shows a dimmed copy of
  /// the full image for context. This sets that layer's opacity (0 = disabled, use solid [scrimColor] only).
  ///
  /// Defaults to `0.38`.
  final double panZoomSurroundOpacity;

  /// An optional painter between the image and the crop grid.
  ///
  /// Could be used for special effects on the cropped area.
  final CustomPainter? overlayPainter;

  /// An optional widget between the image and the crop grid.
  ///
  /// Can be used to display any kind of widget on top of the image.
  final Widget? overlayWidget;

  /// A widget rendered when the image is not ready.
  /// Default is const CircularProgressIndicator.adaptive()
  final Widget loadingPlaceholder;

  const CropImage({
    super.key,
    this.controller,
    required this.image,
    this.gridColor = Colors.white70,
    Color? gridInnerColor,
    Color? gridCornerColor,
    this.paddingSize = 0,
    this.touchSize = 50,
    this.gridCornerSize = 25,
    this.cornerOffset = 0,
    this.showCorners = true,
    this.gridThinWidth = 2,
    this.gridThickWidth = 5,
    this.scrimColor = Colors.black54,
    this.alwaysShowThirdLines = false,
    this.onCrop,
    this.minimumImageSize = 100,
    this.maximumImageSize = double.infinity,
    this.alwaysMove = false,
    this.interactionMode = CropInteractionMode.handles,
    this.showPanZoomViewportBorder = true,
    this.panZoomLetterboxColor = const Color(0xFFE8E8E8),
    this.panZoomSurroundOpacity = 0.3,
    this.overlayPainter,
    this.overlayWidget,
    this.loadingPlaceholder = const CircularProgressIndicator.adaptive(),
  })  : gridInnerColor = gridInnerColor ?? gridColor,
        gridCornerColor = gridCornerColor ?? gridColor,
        assert(gridCornerSize > 0, 'gridCornerSize cannot be zero'),
        assert(touchSize > 0, 'touchSize cannot be zero'),
        assert(gridThinWidth > 0, 'gridThinWidth cannot be zero'),
        assert(gridThickWidth > 0, 'gridThickWidth cannot be zero'),
        assert(minimumImageSize > 0, 'minimumImageSize cannot be zero'),
        assert(maximumImageSize >= minimumImageSize, 'maximumImageSize cannot be less than minimumImageSize'),
        assert(cornerOffset >= 0, 'cornerOffset cannot be negative'),
        assert(panZoomSurroundOpacity >= 0 && panZoomSurroundOpacity <= 1, 'panZoomSurroundOpacity must be 0..1');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties.add(DiagnosticsProperty<CropController>('controller', controller, defaultValue: null));
    properties.add(DiagnosticsProperty<Image>('image', image));
    properties.add(DiagnosticsProperty<Color>('gridColor', gridColor));
    properties.add(DiagnosticsProperty<Color>('gridInnerColor', gridInnerColor));
    properties.add(DiagnosticsProperty<Color>('gridCornerColor', gridCornerColor));
    properties.add(DiagnosticsProperty<double>('paddingSize', paddingSize));
    properties.add(DiagnosticsProperty<double>('touchSize', touchSize));
    properties.add(DiagnosticsProperty<double>('gridCornerSize', gridCornerSize));
    properties.add(DiagnosticsProperty<double>('cornerOffset', cornerOffset));
    properties.add(DiagnosticsProperty<bool>('showCorners', showCorners));
    properties.add(DiagnosticsProperty<double>('gridThinWidth', gridThinWidth));
    properties.add(DiagnosticsProperty<double>('gridThickWidth', gridThickWidth));
    properties.add(DiagnosticsProperty<Color>('scrimColor', scrimColor));
    properties.add(DiagnosticsProperty<bool>('alwaysShowThirdLines', alwaysShowThirdLines));
    properties.add(DiagnosticsProperty<ValueChanged<Rect>>('onCrop', onCrop, defaultValue: null));
    properties.add(DiagnosticsProperty<double>('minimumImageSize', minimumImageSize));
    properties.add(DiagnosticsProperty<double>('maximumImageSize', maximumImageSize));
    properties.add(DiagnosticsProperty<bool>('alwaysMove', alwaysMove));
    properties.add(EnumProperty<CropInteractionMode>('interactionMode', interactionMode));
    properties.add(DiagnosticsProperty<bool>('showPanZoomViewportBorder', showPanZoomViewportBorder));
    properties.add(DiagnosticsProperty<Color>('panZoomLetterboxColor', panZoomLetterboxColor));
    properties.add(DiagnosticsProperty<double>('panZoomSurroundOpacity', panZoomSurroundOpacity));
  }

  @override
  State<CropImage> createState() => _CropImageState();
}

const double _kMinPanZoomVisualScale = 0.22;

enum _CornerTypes { UpperLeft, UpperRight, LowerRight, LowerLeft, None, Move }

class _CropImageState extends State<CropImage> with SingleTickerProviderStateMixin {
  late CropController controller;
  late ImageStream _stream;
  late ImageStreamListener _streamListener;
  var currentCrop = Rect.zero;
  var size = Size.zero;
  _TouchPoint? panStart;

  /// Viewport size in [CropInteractionMode.panZoom] (updated each build).
  Size _viewportSize = Size.zero;

  double _panZoomLastScale = 1.0;

  /// Multiplies the pan-zoom cover scale; &lt; 1 letterboxes the image inside the viewport.
  double _panZoomVisualScale = 1.0;

  double _panZoomSnapFrom = 1.0;

  late final AnimationController _panZoomSnapController;

  /// True while a pan-zoom scale/pan gesture is in progress (surround preview).
  bool _panZoomGestureActive = false;

  Map<_CornerTypes, Offset> get gridCorners => <_CornerTypes, Offset>{
        _CornerTypes.UpperLeft: controller.crop.topLeft.scale(size.width, size.height).translate(widget.paddingSize - widget.cornerOffset, widget.paddingSize - widget.cornerOffset),
        _CornerTypes.UpperRight: controller.crop.topRight.scale(size.width, size.height).translate(widget.paddingSize + widget.cornerOffset, widget.paddingSize - widget.cornerOffset),
        _CornerTypes.LowerRight: controller.crop.bottomRight.scale(size.width, size.height).translate(widget.paddingSize + widget.cornerOffset, widget.paddingSize + widget.cornerOffset),
        _CornerTypes.LowerLeft: controller.crop.bottomLeft.scale(size.width, size.height).translate(widget.paddingSize - widget.cornerOffset, widget.paddingSize + widget.cornerOffset),
      };

  @override
  void initState() {
    super.initState();

    _panZoomSnapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _panZoomSnapController.addListener(_onPanZoomSnapTick);

    controller = widget.controller ?? CropController();
    controller.addListener(onChange);
    currentCrop = controller.crop;

    _stream = widget.image.image.resolve(const ImageConfiguration());
    _streamListener = ImageStreamListener((info, _) => controller.image = info.image);
    _stream.addListener(_streamListener);
  }

  @override
  void dispose() {
    controller.removeListener(onChange);

    if (widget.controller == null) {
      controller.dispose();
    }

    _stream.removeListener(_streamListener);

    _panZoomSnapController.dispose();

    super.dispose();
  }

  void _onPanZoomSnapTick() {
    if (!mounted) {
      return;
    }
    final double t = Curves.easeOutCubic.transform(_panZoomSnapController.value);
    setState(() {
      _panZoomVisualScale = ui.lerpDouble(_panZoomSnapFrom, 1.0, t)!;
    });
  }

  @override
  void didUpdateWidget(CropImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.interactionMode == CropInteractionMode.panZoom && widget.interactionMode != CropInteractionMode.panZoom) {
      _panZoomSnapController.stop();
      _panZoomVisualScale = 1.0;
      _panZoomGestureActive = false;
    }

    if (widget.controller == null && oldWidget.controller != null) {
      controller = CropController.fromValue(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      controller.dispose();
    }
  }

  double _getImageRatio(final double maxWidth, final double maxHeight) => controller.getImage()!.width / controller.getImage()!.height;

  double _getWidth(final double maxWidth, final double maxHeight) {
    double imageRatio = _getImageRatio(maxWidth, maxHeight);
    final screenRatio = maxWidth / maxHeight;
    if (controller.value.rotation.isSideways) {
      imageRatio = 1 / imageRatio;
    }
    if (imageRatio > screenRatio) {
      return maxWidth;
    }
    return maxHeight * imageRatio;
  }

  double _getHeight(final double maxWidth, final double maxHeight) {
    double imageRatio = _getImageRatio(maxWidth, maxHeight);
    final screenRatio = maxWidth / maxHeight;
    if (controller.value.rotation.isSideways) {
      imageRatio = 1 / imageRatio;
    }
    if (imageRatio < screenRatio) {
      return maxHeight;
    }
    return maxWidth / imageRatio;
  }

  @override
  Widget build(BuildContext context) => Center(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (controller.getImage() == null) {
              return widget.loadingPlaceholder;
            }
            final double maxWidth = constraints.maxWidth - 2 * widget.paddingSize;
            final double maxHeight = constraints.maxHeight - 2 * widget.paddingSize;
            final double width = _getWidth(maxWidth, maxHeight);
            final double height = _getHeight(maxWidth, maxHeight);
            size = Size(width, height);
            if (widget.interactionMode == CropInteractionMode.panZoom) {
              return _buildPanZoom(maxWidth, maxHeight, width, height);
            }
            final bool showCorners = widget.showCorners && widget.minimumImageSize != widget.maximumImageSize;
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  width: width,
                  height: height,
                  child: CustomPaint(
                    painter: _RotatedImagePainter(
                      controller.getImage()!,
                      controller.rotation,
                    ),
                  ),
                ),
                if (widget.overlayPainter != null)
                  SizedBox(
                    width: width,
                    height: height,
                    child: CustomPaint(painter: widget.overlayPainter),
                  ),
                if (widget.overlayWidget != null)
                  SizedBox(
                    width: width,
                    height: height,
                    child: widget.overlayWidget,
                  ),
                SizedBox(
                  width: width + 2 * widget.paddingSize,
                  height: height + 2 * widget.paddingSize,
                  child: GestureDetector(
                    onPanStart: onPanStart,
                    onPanUpdate: onPanUpdate,
                    onPanEnd: onPanEnd,
                    child: CropGrid(
                      crop: currentCrop,
                      gridColor: widget.gridColor,
                      gridInnerColor: widget.gridInnerColor,
                      gridCornerColor: widget.gridCornerColor,
                      paddingSize: widget.paddingSize,
                      cornerSize: showCorners ? widget.gridCornerSize : 0,
                      cornerOffset: widget.cornerOffset,
                      thinWidth: widget.gridThinWidth,
                      thickWidth: widget.gridThickWidth,
                      scrimColor: widget.scrimColor,
                      showCorners: showCorners,
                      alwaysShowThirdLines: widget.alwaysShowThirdLines,
                      isMoving: panStart != null,
                      onSize: (size) {
                        this.size = size;
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  Widget _buildPanZoom(double maxWidth, double maxHeight, double fittedW, double fittedH) {
    late final double vpW;
    late final double vpH;
    if (controller.aspectRatio != null) {
      final double ar = controller.aspectRatio!;
      var w = maxWidth;
      var h = w / ar;
      if (h > maxHeight) {
        h = maxHeight;
        w = h * ar;
      }
      vpW = w;
      vpH = h;
    } else {
      vpW = maxWidth;
      vpH = maxHeight;
    }
    _viewportSize = Size(vpW, vpH);
    final fitted = Size(fittedW, fittedH);
    final crop = controller.crop;

    return SizedBox(
      width: vpW + 2 * widget.paddingSize,
      height: vpH + 2 * widget.paddingSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          if (!_panZoomGestureActive || widget.panZoomSurroundOpacity <= 0)
            CustomPaint(
              size: Size(vpW + 2 * widget.paddingSize, vpH + 2 * widget.paddingSize),
              painter: _PanZoomScrimPainter(
                padding: widget.paddingSize,
                viewportSize: Size(vpW, vpH),
                scrimColor: widget.scrimColor,
              ),
            ),
          if (_panZoomGestureActive && widget.panZoomSurroundOpacity > 0)
            CustomPaint(
              size: Size(vpW + 2 * widget.paddingSize, vpH + 2 * widget.paddingSize),
              painter: _PanZoomDimmedSurroundPainter(
                padding: widget.paddingSize,
                viewportSize: Size(vpW, vpH),
                image: controller.getImage()!,
                rotation: controller.rotation,
                crop: crop,
                fittedSize: fitted,
                visualScale: _panZoomVisualScale,
                opacity: widget.panZoomSurroundOpacity,
              ),
            ),
          Positioned(
            left: widget.paddingSize,
            top: widget.paddingSize,
            width: vpW,
            height: vpH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onPanZoomScaleStart,
              onScaleUpdate: (details) => _onPanZoomScaleUpdate(details, fitted),
              onScaleEnd: _onPanZoomScaleEnd,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(color: widget.panZoomLetterboxColor),
                  CustomPaint(
                    painter: _PanZoomImagePainter(
                      image: controller.getImage()!,
                      rotation: controller.rotation,
                      crop: crop,
                      fittedSize: fitted,
                      visualScale: _panZoomVisualScale,
                    ),
                  ),
                  if (widget.overlayPainter != null) CustomPaint(painter: widget.overlayPainter),
                  if (widget.overlayWidget != null) widget.overlayWidget!,
                  if (widget.showPanZoomViewportBorder || widget.alwaysShowThirdLines)
                    CustomPaint(
                      painter: _PanZoomViewportOverlayPainter(
                        showBorder: widget.showPanZoomViewportBorder,
                        borderColor: widget.gridColor,
                        thinWidth: widget.gridThinWidth,
                        showThirds: widget.alwaysShowThirdLines,
                        innerColor: widget.gridInnerColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPanZoomScaleStart(ScaleStartDetails details) {
    _panZoomLastScale = 1.0;
    if (_panZoomSnapController.isAnimating) {
      _panZoomSnapController.stop();
    }
    setState(() {
      _panZoomGestureActive = true;
    });
  }

  void _onPanZoomScaleEnd(ScaleEndDetails details) {
    _panZoomLastScale = 1.0;
    setState(() {
      _panZoomGestureActive = false;
    });
    if (_panZoomVisualScale >= 1.0 - 1e-6) {
      return;
    }
    _panZoomSnapFrom = _panZoomVisualScale;
    _panZoomSnapController.forward(from: 0);
  }

  void _onPanZoomScaleUpdate(ScaleUpdateDetails details, Size fitted) {
    if (_viewportSize.isEmpty) {
      return;
    }
    final scaleDelta = details.scale / _panZoomLastScale;
    _panZoomLastScale = details.scale;

    var cropRect = controller.crop;
    var vs = _panZoomVisualScale;

    // [_panZoomApplyScale] uses w = crop.width / scaleDelta, so:
    // scaleDelta > 1 → smaller crop → zoom **in** on the image.
    // scaleDelta < 1 → larger crop → zoom **out** (see more image).
    if ((scaleDelta - 1.0).abs() > 1e-6) {
      if (scaleDelta > 1.0) {
        // Zoom in: only change crop; letterbox is cleared on [onScaleEnd] if still overscrolled.
        final Rect n = _panZoomApplyScale(cropRect, scaleDelta, details.localFocalPoint, fitted);
        cropRect = _clampPanZoomCrop(n, fitted);
      } else {
        final Rect n = _panZoomApplyScale(cropRect, scaleDelta, details.localFocalPoint, fitted);
        final Rect cl = _clampPanZoomCrop(n, fitted);
        final double vw = n.width > 0 ? cl.width / n.width : 1.0;
        final double vh = n.height > 0 ? cl.height / n.height : 1.0;
        var factor = math.min(vw, vh);
        if (factor >= 1.0 - 1e-9 && (cl.width - cropRect.width).abs() < 1e-6 && (cl.height - cropRect.height).abs() < 1e-6) {
          factor = scaleDelta;
        }
        vs = (vs * factor).clamp(_kMinPanZoomVisualScale, 1.0);
        cropRect = cl;
      }
    }
    if (details.focalPointDelta != Offset.zero) {
      cropRect = _panZoomApplyPan(cropRect, details.focalPointDelta, fitted);
      cropRect = _clampPanZoomCrop(cropRect, fitted);
    }

    setState(() {
      _panZoomVisualScale = vs;
    });
    controller.crop = cropRect;
    widget.onCrop?.call(controller.crop);
  }

  Rect _panZoomApplyScale(Rect c, double scaleDelta, Offset focalLocal, Size fitted) {
    final vp = _viewportSize;
    final relX = (focalLocal.dx / vp.width).clamp(0.0, 1.0);
    final relY = (focalLocal.dy / vp.height).clamp(0.0, 1.0);
    final ax = c.left + relX * c.width;
    final ay = c.top + relY * c.height;
    var w = c.width / scaleDelta;
    var h = c.height / scaleDelta;
    if (controller.aspectRatio != null) {
      final double ar = controller.aspectRatio!;
      h = w * fitted.width / (ar * fitted.height);
    }
    var left = ax - relX * w;
    var top = ay - relY * h;
    return Rect.fromLTWH(left, top, w, h);
  }

  Rect _panZoomApplyPan(Rect c, Offset delta, Size fitted) {
    final vp = _viewportSize;
    final dLeft = -delta.dx / vp.width * c.width;
    final dTop = -delta.dy / vp.height * c.height;
    return c.shift(Offset(dLeft, dTop));
  }

  Rect _clampPanZoomCrop(Rect c, Size fitted) {
    var w = c.width;
    var h = c.height;
    var minW = (widget.minimumImageSize / fitted.width).clamp(0.0, 1.0);
    var minH = (widget.minimumImageSize / fitted.height).clamp(0.0, 1.0);
    if (controller.aspectRatio != null) {
      final double ar = controller.aspectRatio!;
      if (ar < 1.0) {
        minW = (widget.minimumImageSize * ar / fitted.width).clamp(0.0, 1.0);
      } else if (ar > 1.0) {
        minH = (widget.minimumImageSize / (ar * fitted.height)).clamp(0.0, 1.0);
      }
    }
    final maxW = widget.maximumImageSize.isFinite ? (widget.maximumImageSize / fitted.width).clamp(minW, 1.0) : 1.0;
    final maxH = widget.maximumImageSize.isFinite ? (widget.maximumImageSize / fitted.height).clamp(minH, 1.0) : 1.0;

    if (controller.aspectRatio != null) {
      final double ar = controller.aspectRatio!;
      w = w.clamp(minW, maxW);
      h = w * fitted.width / (ar * fitted.height);
      h = h.clamp(minH, maxH);
      w = h * ar * fitted.height / fitted.width;
      w = w.clamp(minW, maxW);
      h = w * fitted.width / (ar * fitted.height);
    } else {
      w = w.clamp(minW, maxW);
      h = h.clamp(minH, maxH);
    }

    var left = c.left;
    var top = c.top;
    final right = left + w;
    final bottom = top + h;
    if (right > 1.0) {
      left -= right - 1.0;
    }
    if (bottom > 1.0) {
      top -= bottom - 1.0;
    }
    if (left < 0) {
      left = 0;
    }
    if (top < 0) {
      top = 0;
    }
    if (left + w > 1.0) {
      left = 1.0 - w;
    }
    if (top + h > 1.0) {
      top = 1.0 - h;
    }
    return Rect.fromLTWH(left, top, w, h);
  }

  void onPanStart(DragStartDetails details) {
    if (panStart == null) {
      final type = hitTest(details.localPosition);
      if (type != _CornerTypes.None) {
        var basePoint = gridCorners[(type == _CornerTypes.Move) ? _CornerTypes.UpperLeft : type]!;
        setState(() {
          panStart = _TouchPoint(type, details.localPosition - basePoint);
        });
      }
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
    if (panStart != null) {
      final offset = details.localPosition - panStart!.offset - Offset(widget.paddingSize, widget.paddingSize);
      if (panStart!.type == _CornerTypes.Move) {
        moveArea(offset);
      } else {
        moveCorner(panStart!.type, offset);
      }
      widget.onCrop?.call(controller.crop);
    }
  }

  void onPanEnd(DragEndDetails details) {
    setState(() {
      panStart = null;
    });
  }

  void onChange() {
    setState(() {
      currentCrop = controller.crop;
    });
  }

  _CornerTypes hitTest(Offset point) {
    for (final gridCorner in gridCorners.entries) {
      final area = Rect.fromCenter(center: gridCorner.value, width: widget.touchSize, height: widget.touchSize);
      if (area.contains(point)) {
        return gridCorner.key;
      }
    }

    if (widget.alwaysMove) {
      return _CornerTypes.Move;
    }

    final area = Rect.fromPoints(gridCorners[_CornerTypes.UpperLeft]!, gridCorners[_CornerTypes.LowerRight]!);
    return area.contains(point) ? _CornerTypes.Move : _CornerTypes.None;
  }

  void moveArea(Offset point) {
    final crop = controller.crop.multiply(size);
    final maxX = math.max(0.0, size.width - crop.width);
    final maxY = math.max(0.0, size.height - crop.height);
    controller.crop = Rect.fromLTWH(
      point.dx.clamp(0.0, maxX),
      point.dy.clamp(0.0, maxY),
      crop.width,
      crop.height,
    ).divide(size);
  }

  void moveCorner(_CornerTypes type, Offset point) {
    final crop = controller.crop.multiply(size);
    var left = crop.left;
    var top = crop.top;
    var right = crop.right;
    var bottom = crop.bottom;
    double minX, maxX;
    double minY, maxY;

    switch (type) {
      case _CornerTypes.UpperLeft:
        minX = math.max(0, right - widget.maximumImageSize);
        maxX = right - widget.minimumImageSize;
        if (minX <= maxX) {
          left = point.dx.clamp(minX, maxX);
        }
        minY = math.max(0, bottom - widget.maximumImageSize);
        maxY = bottom - widget.minimumImageSize;
        if (minY <= maxY) {
          top = point.dy.clamp(minY, maxY);
        }
        break;
      case _CornerTypes.UpperRight:
        minX = left + widget.minimumImageSize;
        maxX = math.min(left + widget.maximumImageSize, size.width);
        if (minX <= maxX) {
          right = point.dx.clamp(minX, maxX);
        }
        minY = math.max(0, bottom - widget.maximumImageSize);
        maxY = bottom - widget.minimumImageSize;
        if (minY <= maxY) {
          top = point.dy.clamp(minY, maxY);
        }
        break;
      case _CornerTypes.LowerRight:
        minX = left + widget.minimumImageSize;
        maxX = math.min(left + widget.maximumImageSize, size.width);
        if (minX <= maxX) {
          right = point.dx.clamp(minX, maxX);
        }
        minY = top + widget.minimumImageSize;
        maxY = math.min(top + widget.maximumImageSize, size.height);
        if (minY <= maxY) {
          bottom = point.dy.clamp(minY, maxY);
        }
        break;
      case _CornerTypes.LowerLeft:
        minX = math.max(0, right - widget.maximumImageSize);
        maxX = right - widget.minimumImageSize;
        if (minX <= maxX) {
          left = point.dx.clamp(minX, maxX);
        }
        minY = top + widget.minimumImageSize;
        maxY = math.min(top + widget.maximumImageSize, size.height);
        if (minY <= maxY) {
          bottom = point.dy.clamp(minY, maxY);
        }
        break;
      default:
        assert(false);
    }

    //FIXME: does not work with non-straight "rotation"
    if (controller.aspectRatio != null) {
      final width = right - left;
      final height = bottom - top;
      if (width / height > controller.aspectRatio!) {
        switch (type) {
          case _CornerTypes.UpperLeft:
          case _CornerTypes.LowerLeft:
            left = right - height * controller.aspectRatio!;
            break;
          case _CornerTypes.UpperRight:
          case _CornerTypes.LowerRight:
            right = left + height * controller.aspectRatio!;
            break;
          default:
            assert(false);
        }
      } else {
        switch (type) {
          case _CornerTypes.UpperLeft:
          case _CornerTypes.UpperRight:
            top = bottom - width / controller.aspectRatio!;
            break;
          case _CornerTypes.LowerRight:
          case _CornerTypes.LowerLeft:
            bottom = top + width / controller.aspectRatio!;
            break;
          default:
            assert(false);
        }
      }
    }

    controller.crop = Rect.fromLTRB(left, top, right, bottom).divide(size);
  }
}

class _TouchPoint {
  final _CornerTypes type;
  final Offset offset;

  _TouchPoint(this.type, this.offset);
}

void _paintRotatedImageIntoRect(
  Canvas canvas,
  ui.Image image,
  CropRotation rotation,
  Size size,
  Paint paint,
  Rect visibleRect,
) {
  double targetWidth = size.width;
  double targetHeight = size.height;
  double offset = 0;
  if (rotation != CropRotation.up) {
    if (rotation.isSideways) {
      final double tmp = targetHeight;
      targetHeight = targetWidth;
      targetWidth = tmp;
      offset = (targetWidth - targetHeight) / 2;
      if (rotation == CropRotation.left) {
        offset = -offset;
      }
    }
    canvas.save();
    canvas.translate(targetWidth / 2, targetHeight / 2);
    canvas.rotate(rotation.radians);
    canvas.translate(-targetWidth / 2, -targetHeight / 2);
  }

  Rect localVisibleRect = visibleRect;
  if (rotation != CropRotation.up) {
    final Matrix4 matrix = Matrix4.identity()
      ..translate(targetWidth / 2, targetHeight / 2)
      ..rotateZ(rotation.radians)
      ..translate(-targetWidth / 2, -targetHeight / 2);
    final Matrix4 inverse = matrix.clone()..invert();
    localVisibleRect = MatrixUtils.transformRect(inverse, visibleRect);
  }

  final Rect imageRect = Rect.fromLTWH(offset, offset, targetWidth, targetHeight);
  final Rect dstRect = localVisibleRect.intersect(imageRect);
  if (dstRect.width <= 0 || dstRect.height <= 0) {
    if (rotation != CropRotation.up) {
      canvas.restore();
    }
    return;
  }

  final double srcLeft = (dstRect.left - offset) / targetWidth * image.width;
  final double srcTop = (dstRect.top - offset) / targetHeight * image.height;
  final double srcWidth = dstRect.width / targetWidth * image.width;
  final double srcHeight = dstRect.height / targetHeight * image.height;
  final Rect srcRect = Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight);

  paint.filterQuality = FilterQuality.high;
  canvas.drawImageRect(
    image,
    srcRect,
    dstRect,
    paint,
  );
  if (rotation != CropRotation.up) {
    canvas.restore();
  }
}

/// Scrim with a transparent viewport hole (same geometry as [CropGrid]).
class _PanZoomScrimPainter extends CustomPainter {
  _PanZoomScrimPainter({
    required this.padding,
    required this.viewportSize,
    required this.scrimColor,
  });

  final double padding;
  final Size viewportSize;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect full = Offset(padding, padding) & Size(size.width - 2 * padding, size.height - 2 * padding);
    final Rect hole = Offset(padding, padding) & viewportSize;
    canvas.save();
    canvas.clipRect(hole, clipOp: ui.ClipOp.difference);
    canvas.drawRect(full, Paint()..color = scrimColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanZoomScrimPainter oldDelegate) => oldDelegate.padding != padding || oldDelegate.viewportSize != viewportSize || oldDelegate.scrimColor != scrimColor;
}

/// Full fitted image in the scrim ring, dimmed, using the same transform as
/// [_PanZoomImagePainter] so cropped-out regions line up with the viewport.
class _PanZoomDimmedSurroundPainter extends CustomPainter {
  _PanZoomDimmedSurroundPainter({
    required this.padding,
    required this.viewportSize,
    required this.image,
    required this.rotation,
    required this.crop,
    required this.fittedSize,
    required this.visualScale,
    required this.opacity,
  });

  final double padding;
  final Size viewportSize;
  final ui.Image image;
  final CropRotation rotation;
  final Rect crop;
  final Size fittedSize;
  final double visualScale;
  final double opacity;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) {
      return;
    }
    final Rect hole = Offset(padding, padding) & viewportSize;
    canvas.save();
    canvas.clipRect(hole, clipOp: ui.ClipOp.difference);
    canvas.translate(padding, padding);

    final pixelCrop = crop.multiply(fittedSize);
    final double pw = pixelCrop.width;
    final double ph = pixelCrop.height;
    if (pw <= 0 || ph <= 0) {
      canvas.restore();
      return;
    }
    final double s0 = math.max(viewportSize.width / pw, viewportSize.height / ph);
    final double s = s0 * visualScale.clamp(_kMinPanZoomVisualScale, 1.0);
    final double contentW = pw * s;
    final double contentH = ph * s;
    final double ox = (viewportSize.width - contentW) / 2;
    final double oy = (viewportSize.height - contentH) / 2;

    final double dx = ox - pixelCrop.left * s;
    final double dy = oy - pixelCrop.top * s;

    final Rect screenVisibleRect = Rect.fromLTWH(-padding, -padding, size.width, size.height);

    final Rect visibleRect = Rect.fromLTRB(
      (screenVisibleRect.left - dx) / s,
      (screenVisibleRect.top - dy) / s,
      (screenVisibleRect.right - dx) / s,
      (screenVisibleRect.bottom - dy) / s,
    );

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(s);
    _paint.color = Color.fromRGBO(255, 255, 255, opacity);
    _paint.blendMode = BlendMode.darken;
    _paintRotatedImageIntoRect(canvas, image, rotation, fittedSize, _paint, visibleRect);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanZoomDimmedSurroundPainter oldDelegate) => oldDelegate.padding != padding || oldDelegate.viewportSize != viewportSize || oldDelegate.image != image || oldDelegate.rotation != rotation || oldDelegate.crop != crop || oldDelegate.fittedSize != fittedSize || oldDelegate.visualScale != visualScale || oldDelegate.opacity != opacity;
}

/// Draws the portion of the fitted image described by [crop], scaled to cover the viewport.
///
/// [visualScale] is applied after the cover scale; values below 1 letterbox the image inside [size].
class _PanZoomImagePainter extends CustomPainter {
  _PanZoomImagePainter({
    required this.image,
    required this.rotation,
    required this.crop,
    required this.fittedSize,
    required this.visualScale,
  });

  final ui.Image image;
  final CropRotation rotation;
  final Rect crop;
  final Size fittedSize;

  /// In (0, 1]; 1 = fill viewport (cover). Smaller = overscroll zoom-out (letterboxed).
  final double visualScale;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final pixelCrop = crop.multiply(fittedSize);
    final double pw = pixelCrop.width;
    final double ph = pixelCrop.height;
    if (pw <= 0 || ph <= 0) {
      return;
    }
    final double s0 = math.max(size.width / pw, size.height / ph);
    final double s = s0 * visualScale.clamp(_kMinPanZoomVisualScale, 1.0);
    final double contentW = pw * s;
    final double contentH = ph * s;
    final double ox = (size.width - contentW) / 2;
    final double oy = (size.height - contentH) / 2;

    final double dx = ox - pixelCrop.left * s;
    final double dy = oy - pixelCrop.top * s;

    final Rect visibleRect = Rect.fromLTRB(
      (0 - dx) / s,
      (0 - dy) / s,
      (size.width - dx) / s,
      (size.height - dy) / s,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(dx, dy);
    canvas.scale(s);
    _paintRotatedImageIntoRect(canvas, image, rotation, fittedSize, _paint, visibleRect);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PanZoomImagePainter oldDelegate) => oldDelegate.image != image || oldDelegate.rotation != rotation || oldDelegate.crop != crop || oldDelegate.fittedSize != fittedSize || oldDelegate.visualScale != visualScale;
}

/// Rule-of-thirds and/or border on the pan-zoom viewport.
class _PanZoomViewportOverlayPainter extends CustomPainter {
  _PanZoomViewportOverlayPainter({
    required this.showBorder,
    required this.borderColor,
    required this.thinWidth,
    required this.showThirds,
    required this.innerColor,
  });

  final bool showBorder;
  final Color borderColor;
  final double thinWidth;
  final bool showThirds;
  final Color innerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    if (showBorder) {
      canvas.drawRect(
        bounds,
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = thinWidth
          ..isAntiAlias = true,
      );
    }
    if (showThirds) {
      final thirdHeight = bounds.height / 3.0;
      final thirdWidth = bounds.width / 3.0;
      final double o = thinWidth / 2;
      final path = Path()
        ..addPolygon([
          bounds.topLeft.translate(o, thirdHeight),
          bounds.topRight.translate(-o, thirdHeight),
        ], false)
        ..addPolygon([
          bounds.bottomLeft.translate(o, -thirdHeight),
          bounds.bottomRight.translate(-o, -thirdHeight),
        ], false)
        ..addPolygon([
          bounds.topLeft.translate(thirdWidth, o),
          bounds.bottomLeft.translate(thirdWidth, -o),
        ], false)
        ..addPolygon([
          bounds.topRight.translate(-thirdWidth, o),
          bounds.bottomRight.translate(-thirdWidth, -o),
        ], false);
      canvas.drawPath(
        path,
        Paint()
          ..color = innerColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = thinWidth
          ..strokeCap = StrokeCap.butt
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_PanZoomViewportOverlayPainter oldDelegate) => oldDelegate.showBorder != showBorder || oldDelegate.borderColor != borderColor || oldDelegate.thinWidth != thinWidth || oldDelegate.showThirds != showThirds || oldDelegate.innerColor != innerColor;
}

// FIXME: shouldn't be repainted each time the grid moves, should it?
class _RotatedImagePainter extends CustomPainter {
  _RotatedImagePainter(this.image, this.rotation);

  final ui.Image image;
  final CropRotation rotation;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    _paintRotatedImageIntoRect(canvas, image, rotation, size, _paint, Offset.zero & size);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
