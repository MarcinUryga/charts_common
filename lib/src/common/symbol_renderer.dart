// Copyright 2018 the Charts project authors. Please see the AUTHORS file
// for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math' show Rectangle, Point, min;
import 'color.dart' show Color;
import '../chart/common/chart_canvas.dart' show ChartCanvas;

/// Strategy for rendering a symbol.
abstract class BaseSymbolRenderer {
  bool shouldRepaint(covariant BaseSymbolRenderer oldRenderer);
}

/// Strategy for rendering a symbol bounded within a box.
abstract class SymbolRenderer extends BaseSymbolRenderer {
  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {Color fillColor, Color strokeColor, double strokeWidthPx});
}

/// Strategy for rendering a symbol centered around a point.
///
/// An optional second point can describe an extended symbol.
abstract class PointSymbolRenderer extends BaseSymbolRenderer {
  void paint(ChartCanvas canvas, Point<double> p1, double radius,
      {Point<double> p2, Color fillColor, strokeColor});
}

/// Rounded rectangular symbol with corners having [radius].
class RoundedRectSymbolRenderer extends SymbolRenderer {
  final double radius;

  RoundedRectSymbolRenderer({double radius}) : radius = radius ?? 1.0;

  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {Color fillColor, Color strokeColor, double strokeWidthPx}) {
    canvas.drawRRect(bounds,
        fill: fillColor,
        stroke: strokeColor,
        radius: radius,
        roundTopLeft: true,
        roundTopRight: true,
        roundBottomRight: true,
        roundBottomLeft: true);
  }

  bool shouldRepaint(RoundedRectSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) {
    return other is RoundedRectSymbolRenderer && other.radius == radius;
  }

  @override
  int get hashCode => radius.hashCode;
}

/// Line symbol renderer.
class LineSymbolRenderer extends SymbolRenderer {
  static const roundEndCapsPixels = 2;
  static const minLengthToRoundCaps = (roundEndCapsPixels * 2) + 1;

  /// Thickness of the line stroke.
  final double strokeWidth;

  LineSymbolRenderer({double strokeWidth}) : strokeWidth = strokeWidth ?? 4.0;

  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {Color fillColor, Color strokeColor, double strokeWidthPx}) {
    final centerHeight = (bounds.bottom - bounds.top) / 2;

    // Adjust the length so the total width includes the rounded pixels.
    // Otherwise the cap is drawn past the bounds and appears to be cut off.
    // If bounds is not long enough to accommodate the line, do not adjust.
    var left = bounds.left;
    var right = bounds.right;

    if (bounds.width >= minLengthToRoundCaps) {
      left += roundEndCapsPixels;
      right -= roundEndCapsPixels;
    }

    // TODO: Pass in strokeWidth, roundEndCaps, and dashPattern from
    // line renderer config.
    canvas.drawLine(
      points: [new Point(left, centerHeight), new Point(right, centerHeight)],
      fill: fillColor,
      stroke: strokeColor,
      roundEndCaps: true,
      strokeWidthPx: strokeWidth,
    );
  }

  bool shouldRepaint(LineSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) {
    return other is LineSymbolRenderer && other.strokeWidth == strokeWidth;
  }

  @override
  int get hashCode => strokeWidth.hashCode;
}

/// Circle symbol renderer.
class CircleSymbolRenderer extends SymbolRenderer {
  CircleSymbolRenderer();

  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {Color fillColor, Color strokeColor, double strokeWidthPx}) {
    final center = new Point(
      bounds.left + (bounds.width / 2),
      bounds.top + (bounds.height / 2),
    );
    final radius = min(bounds.width, bounds.height) / 2;
    canvas.drawPoint(point: center, fill: fillColor, radius: radius);
  }

  bool shouldRepaint(CircleSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) => other is CircleSymbolRenderer;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Rectangle symbol renderer.
class RectSymbolRenderer extends SymbolRenderer {
  RectSymbolRenderer();

  void paint(ChartCanvas canvas, Rectangle<num> bounds,
      {Color fillColor, Color strokeColor, double strokeWidthPx}) {
    canvas.drawRect(bounds,
        fill: fillColor, stroke: strokeColor, strokeWidthPx: strokeWidthPx);
  }

  bool shouldRepaint(RectSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) => other is RectSymbolRenderer;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Draws a cylindrical shape connecting two points.
class CylinderSymbolRenderer extends PointSymbolRenderer {
  CylinderSymbolRenderer();

  void paint(ChartCanvas canvas, Point<double> p1, double radius,
      {Point<double> p2, Color fillColor, strokeColor, double strokeWidthPx}) {
    if (p1 == null) {
      throw new ArgumentError('Invalid point p1 "${p1}"');
    }

    if (p2 == null) {
      throw new ArgumentError('Invalid point p2 "${p2}"');
    }

    final adjustedP1 = new Point<double>(p1.x, p1.y);
    final adjustedP2 = new Point<double>(p2.x, p2.y);

    canvas.drawLine(
        points: [adjustedP1, adjustedP2],
        stroke: strokeColor,
        roundEndCaps: true,
        strokeWidthPx: radius * 2);
  }

  bool shouldRepaint(CylinderSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) => other is CylinderSymbolRenderer;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Draws a rectangular shape connecting two points.
class RectangleRangeSymbolRenderer extends PointSymbolRenderer {
  RectangleRangeSymbolRenderer();

  void paint(ChartCanvas canvas, Point<double> p1, double radius,
      {Point<double> p2, Color fillColor, strokeColor, double strokeWidthPx}) {
    if (p1 == null) {
      throw new ArgumentError('Invalid point p1 "${p1}"');
    }

    if (p2 == null) {
      throw new ArgumentError('Invalid point p2 "${p2}"');
    }

    final adjustedP1 = new Point<double>(p1.x, p1.y);
    final adjustedP2 = new Point<double>(p2.x, p2.y);

    canvas.drawLine(
        points: [adjustedP1, adjustedP2],
        stroke: strokeColor,
        roundEndCaps: false,
        strokeWidthPx: radius * 2);
  }

  bool shouldRepaint(RectangleRangeSymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }

  @override
  bool operator ==(Object other) => other is RectangleRangeSymbolRenderer;

  @override
  int get hashCode => runtimeType.hashCode;
}
