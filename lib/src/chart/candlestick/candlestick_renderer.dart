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

import 'dart:math' show Point, Random, Rectangle, max, min;

import 'package:meta/meta.dart' show protected, required;

import '../../common/color.dart' show Color;
import '../cartesian/axis/axis.dart' show ImmutableAxis, domainAxisKey, measureAxisKey;
import '../common/canvas_shapes.dart' show CanvasBarStack, CanvasRect;
import '../common/chart_canvas.dart' show ChartCanvas, FillPatternType;
import '../common/datum_details.dart' show DatumDetails;
import '../common/processed_series.dart' show ImmutableSeries, MutableSeries, SeriesDatum;
import 'candlestick_renderer_config.dart' show CandlestickRendererConfig, CornerStrategy;
import 'candlestick_renderer_decorator.dart' show CandlestickRendererDecorator;
import 'base_candlestick_renderer.dart'
    show
        BaseBarRenderer,
        barGroupCountKey,
        candlestickGroupIndexKey,
        previousBarGroupWeightKey,
        barGroupWeightKey;
import 'candlestick_renderer_element.dart'
    show BaseAnimatedCandlestick, BaseCandlestickRendererElement;

/// Renders series data as a series of bars.
class CandlestickRenderer<D>
    extends BaseBarRenderer<D, CandlestickRendererElement<D>, AnimatedCandlestick<D>> {
  /// If we are grouped, use this spacing between the bars in a group.
  final _barGroupInnerPadding = 2;

  /// The padding between bar stacks.
  ///
  /// The padding comes out of the bottom of the bar.
  final _stackedBarPadding = 1;

  final CandlestickRendererDecorator candlestickRendererDecorator;

  factory CandlestickRenderer({CandlestickRendererConfig config, String rendererId}) {
    rendererId ??= 'bar';
    config ??= new CandlestickRendererConfig();
    return new CandlestickRenderer.internal(config: config, rendererId: rendererId);
  }

  /// This constructor is protected because it is used by child classes, which
  /// cannot call the factory in their own constructors.
  @protected
  CandlestickRenderer.internal({CandlestickRendererConfig config, String rendererId})
      : candlestickRendererDecorator = config.candlestickRendererDecorator,
        super(
            config: config,
            rendererId: rendererId,
            layoutPaintOrder: config.layoutPaintOrder);

  @override
  void configureSeries(List<MutableSeries<D>> seriesList) {
    assignMissingColors(getOrderedSeriesList(seriesList),
        emptyCategoryUsesSinglePalette: true);
  }

  DatumDetails<D> addPositionToDetailsForSeriesDatum(
      DatumDetails<D> details, SeriesDatum<D> seriesDatum) {
    final series = details.series;

    final domainAxis = series.getAttr(domainAxisKey) as ImmutableAxis<D>;
    final measureAxis = series.getAttr(measureAxisKey) as ImmutableAxis<num>;

    final barGroupIndex = series.getAttr(candlestickGroupIndexKey);
    final previousBarGroupWeight = series.getAttr(previousBarGroupWeightKey);
    final barGroupWeight = series.getAttr(barGroupWeightKey);
    final numBarGroups = series.getAttr(barGroupCountKey);

    final bounds = _getBarBounds(
        details.domain,
        domainAxis,
        domainAxis.rangeBand.round(),
        details.measure,
        details.measureOffset,
        measureAxis,
        barGroupIndex,
        previousBarGroupWeight,
        barGroupWeight,
        numBarGroups);

    var chartPosition;

    if (renderingVertically) {
      chartPosition = new Point<double>(
          (bounds.left + (bounds.width / 2)).toDouble(), bounds.top.toDouble());
    } else {
      chartPosition = new Point<double>(
          rtl ? bounds.left.toDouble() : bounds.right.toDouble(),
          (bounds.top + (bounds.height / 2)).toDouble());
    }

    return new DatumDetails.from(details, chartPosition: chartPosition);
  }

  @override
  CandlestickRendererElement<D> getBaseDetails(dynamic datum, int index) {
    return new CandlestickRendererElement<D>();
  }

  CornerStrategy get cornerStrategy {
    return (config as CandlestickRendererConfig).cornerStrategy;
  }

  /// Generates an [AnimatedCandlestick] to represent the previous and current state
  /// of one bar on the chart.
  @override
  AnimatedCandlestick<D> makeAnimatedCandlestick(
      {String key,
      ImmutableSeries<D> series,
      List<int> dashPattern,
      dynamic datum,
      Color color,
      CandlestickRendererElement<D> details,
      D domainValue,
      ImmutableAxis<D> domainAxis,
      int domainWidth,
      num measureValue,
      num measureOffsetValue,
      ImmutableAxis<num> measureAxis,
      double measureAxisPosition,
      Color fillColor,
      FillPatternType fillPattern,
      double strokeWidthPx,
      int barGroupIndex,
      double previousBarGroupWeight,
      double barGroupWeight,
      int numBarGroups}) {
    return new AnimatedCandlestick<D>(
        key: key, datum: datum, series: series, domainValue: domainValue)
      ..setNewTarget(makeCandlestickRendererElement(
          color: color,
          dashPattern: dashPattern,
          details: details,
          domainValue: domainValue,
          domainAxis: domainAxis,
          domainWidth: domainWidth,
          measureValue: measureValue,
          measureOffsetValue: measureOffsetValue,
          measureAxisPosition: measureAxisPosition,
          measureAxis: measureAxis,
          fillColor: fillColor,
          fillPattern: fillPattern,
          strokeWidthPx: strokeWidthPx,
          barGroupIndex: barGroupIndex,
          previousBarGroupWeight: previousBarGroupWeight,
          barGroupWeight: barGroupWeight,
          numBarGroups: numBarGroups));
  }

  /// Generates a [CandlestickRendererElement] to represent the rendering data for one
  /// bar on the chart.
  @override
  CandlestickRendererElement<D> makeCandlestickRendererElement(
      {Color color,
      List<int> dashPattern,
      CandlestickRendererElement<D> details,
      D domainValue,
      ImmutableAxis<D> domainAxis,
      int domainWidth,
      num measureValue,
      num measureOffsetValue,
      ImmutableAxis<num> measureAxis,
      double measureAxisPosition,
      Color fillColor,
      FillPatternType fillPattern,
      double strokeWidthPx,
      int barGroupIndex,
      double previousBarGroupWeight,
      double barGroupWeight,
      int numBarGroups}) {
    return new CandlestickRendererElement<D>()
      ..color = color
      ..dashPattern = dashPattern
      ..fillColor = fillColor
      ..fillPattern = fillPattern
      ..measureAxisPosition = measureAxisPosition
      ..roundPx = details.roundPx
      ..strokeWidthPx = strokeWidthPx
      ..bounds = _getBarBounds(
          domainValue,
          domainAxis,
          domainWidth,
          measureValue,
          measureOffsetValue,
          measureAxis,
          barGroupIndex,
          previousBarGroupWeight,
          barGroupWeight,
          numBarGroups);
  }

  @override
  void paintCandlestick(ChartCanvas canvas, double animationPercent,
      Iterable<CandlestickRendererElement<D>> barElements) {
    final bars = <CanvasRect>[];

    // When adjusting bars for stacked bar padding, do not modify the first bar
    // if rendering vertically and do not modify the last bar if rendering
    // horizontally.
    final unmodifiedBar =
        renderingVertically ? barElements.first : barElements.last;

    // Find the max bar width from each segment to calculate corner radius.
    int maxBarWidth = 0;
    var random = new Random();
    for (var bar in barElements) {
      var bounds = bar.bounds;
      bounds = new Rectangle(bar.bounds.left, bar.bounds.top, bar.bounds.width, random.nextInt(100));

      if (bar != unmodifiedBar) {
        bounds = renderingVertically
            ? new Rectangle<int>(
                bar.bounds.left,
                bar.bounds.top,
                bar.bounds.width,
                max(0, bar.bounds.height - _stackedBarPadding),
              )
            : new Rectangle<int>(
                bar.bounds.left,
                bar.bounds.top,
                max(0, bar.bounds.width - _stackedBarPadding),
                bar.bounds.height,
              );
      }

      bars.add(new CanvasRect(bounds,
          dashPattern: bar.dashPattern,
          fill: bar.fillColor,
          pattern: bar.fillPattern,
          stroke: bar.color,
          strokeWidthPx: bar.strokeWidthPx));

      maxBarWidth = max(
          maxBarWidth, (renderingVertically ? bounds.width : bounds.height));

      canvas.drawLine(
          points: [
            new Point((bounds.left + (bounds.width) / 2.0), bounds.top - 10),
            new Point((bounds.left + (bounds.width) / 2.0), bounds.bottom + 10),
          ],
          fill: Color.black,
          stroke: Color.black,
          strokeWidthPx: bar.strokeWidthPx);
    }

    final barStack = new CanvasBarStack(
      bars,
      radius: cornerStrategy.getRadius(maxBarWidth),
      stackedBarPadding: _stackedBarPadding,
      roundTopLeft: renderingVertically || rtl ? true : false,
      roundTopRight: rtl ? false : true,
      roundBottomLeft: rtl ? true : false,
      roundBottomRight: renderingVertically || rtl ? false : true,
    );

    // If bar stack's range width is:
    // * Within the component bounds, then draw the bar stack.
    // * Partially out of component bounds, then clip the stack where it is out
    // of bounds.
    // * Fully out of component bounds, do not draw.

    final barOutsideBounds = renderingVertically
        ? barStack.fullStackRect.left < componentBounds.left ||
            barStack.fullStackRect.right > componentBounds.right
        : barStack.fullStackRect.top < componentBounds.top ||
            barStack.fullStackRect.bottom > componentBounds.bottom;

    // TODO: When we have initial viewport, add image test for
    // clipping.
    if (barOutsideBounds) {
      final clipBounds = _getBarStackBounds(barStack.fullStackRect);

      // Do not draw the bar stack if it is completely outside of the component
      // bounds.
      if (clipBounds.width <= 0 || clipBounds.height <= 0) {
        return;
      }

      canvas.setClipBounds(clipBounds);
    }

    canvas.drawBarStack(barStack);

    if (barOutsideBounds) {
      canvas.resetClipBounds();
    }

    // Decorate the bar segments if there is a decorator.
    candlestickRendererDecorator?.decorate(barElements, canvas, graphicsFactory,
        drawBounds: drawBounds,
        animationPercent: animationPercent,
        renderingVertically: renderingVertically,
        rtl: rtl);
  }

  /// Calculate the clipping region for a rectangle that represents the full bar
  /// stack.
  Rectangle<int> _getBarStackBounds(Rectangle<int> barStackRect) {
    int left;
    int right;
    int top;
    int bottom;

    if (renderingVertically) {
      // Only clip at the start and end so that the bar's width stays within
      // the viewport, but any bar decorations above the bar can still show.
      left = max(componentBounds.left, barStackRect.left);
      right = min(componentBounds.right, barStackRect.right);
      top = componentBounds.top;
      bottom = componentBounds.bottom;
    } else {
      // Only clip at the top and bottom so that the bar's height stays within
      // the viewport, but any bar decorations to the right of the bar can still
      // show.
      left = componentBounds.left;
      right = componentBounds.right;
      top = max(componentBounds.top, barStackRect.top);
      bottom = min(componentBounds.bottom, barStackRect.bottom);
    }

    final width = right - left;
    final height = bottom - top;

    return new Rectangle(left, top, width, height);
  }

  /// Generates a set of bounds that describe a bar.
  Rectangle<int> _getBarBounds(
      D domainValue,
      ImmutableAxis<D> domainAxis,
      int domainWidth,
      num measureValue,
      num measureOffsetValue,
      ImmutableAxis<num> measureAxis,
      int barGroupIndex,
      double previousBarGroupWeight,
      double barGroupWeight,
      int numBarGroups) {
    // If no weights were passed in, default to equal weight per bar.
    if (barGroupWeight == null) {
      barGroupWeight = 1 / numBarGroups;
      previousBarGroupWeight = barGroupIndex * barGroupWeight;
    }

    // Calculate how wide each bar should be within the group of bars. If we
    // only have one series, or are stacked, then barWidth should equal
    // domainWidth.
    int spacingLoss = (_barGroupInnerPadding * (numBarGroups - 1));
    int barWidth = ((domainWidth - spacingLoss) * barGroupWeight).round();

    // Flip bar group index for calculating location on the domain axis if RTL.
    final adjustedBarGroupIndex =
        rtl ? numBarGroups - barGroupIndex - 1 : barGroupIndex;

    // Calculate the start and end of the bar, taking into account accumulated
    // padding for grouped bars.
    int previousAverageWidth = adjustedBarGroupIndex > 0
        ? ((domainWidth - spacingLoss) *
                (previousBarGroupWeight / adjustedBarGroupIndex))
            .round()
        : 0;

    int domainStart = (domainAxis.getLocation(domainValue) -
            (domainWidth / 2) +
            (previousAverageWidth + _barGroupInnerPadding) *
                adjustedBarGroupIndex)
        .round();

    int domainEnd = domainStart + barWidth;

    measureValue = measureValue != null ? measureValue : 0;

    // Calculate measure locations. Stacked bars should have their
    // offset calculated previously.
    int measureStart = measureAxis.getLocation(measureOffsetValue).round();
    int measureEnd =
        measureAxis.getLocation(measureValue + measureOffsetValue).round();

    var bounds;
    if (this.renderingVertically) {
      // Rectangle clamps to zero width/height
      bounds = new Rectangle<int>(domainStart, measureEnd,
          domainEnd - domainStart, measureStart - measureEnd);
    } else {
      // Rectangle clamps to zero width/height
      bounds = new Rectangle<int>(min(measureStart, measureEnd), domainStart,
          (measureEnd - measureStart).abs(), domainEnd - domainStart);
    }
    return bounds;
  }

  @override
  Rectangle<int> getBoundsForBar(CandlestickRendererElement bar) => bar.bounds;
}

abstract class ImmutableCandlestickRendererElement<D> {
  ImmutableSeries<D> get series;

  dynamic get datum;

  int get index;

  Rectangle<int> get bounds;
}

class CandlestickRendererElement<D> extends BaseCandlestickRendererElement
    implements ImmutableCandlestickRendererElement<D> {
  ImmutableSeries<D> series;
  Rectangle<int> bounds;
  int roundPx;
  int index;
  dynamic _datum;

  dynamic get datum => _datum;

  set datum(dynamic datum) {
    _datum = datum;
    index = series?.data?.indexOf(datum);
  }

  CandlestickRendererElement();

  CandlestickRendererElement.clone(CandlestickRendererElement other) : super.clone(other) {
    series = other.series;
    bounds = other.bounds;
    roundPx = other.roundPx;
    index = other.index;
    _datum = other._datum;
  }

  @override
  void updateAnimationPercent(BaseCandlestickRendererElement previous,
      BaseCandlestickRendererElement target, double animationPercent) {
    final CandlestickRendererElement localPrevious = previous;
    final CandlestickRendererElement localTarget = target;

    final previousBounds = localPrevious.bounds;
    final targetBounds = localTarget.bounds;

    var top = ((targetBounds.top - previousBounds.top) * animationPercent) +
        previousBounds.top;
    var right =
        ((targetBounds.right - previousBounds.right) * animationPercent) +
            previousBounds.right;
    var bottom =
        ((targetBounds.bottom - previousBounds.bottom) * animationPercent) +
            previousBounds.bottom;
    var left = ((targetBounds.left - previousBounds.left) * animationPercent) +
        previousBounds.left;

    bounds = new Rectangle<int>(left.round(), top.round(),
        (right - left).round(), (bottom - top).round());

    roundPx = localTarget.roundPx;

    super.updateAnimationPercent(previous, target, animationPercent);
  }
}

class AnimatedCandlestick<D> extends BaseAnimatedCandlestick<D, CandlestickRendererElement<D>> {
  AnimatedCandlestick(
      {@required String key,
      @required dynamic datum,
      @required ImmutableSeries<D> series,
      @required D domainValue})
      : super(key: key, datum: datum, series: series, domainValue: domainValue);

  @override
  animateElementToMeasureAxisPosition(BaseCandlestickRendererElement target) {
    final CandlestickRendererElement localTarget = target;

    // TODO: Animate out bars in the middle of a stack.
    localTarget.bounds = new Rectangle<int>(
        localTarget.bounds.left + (localTarget.bounds.width / 2).round(),
        localTarget.measureAxisPosition.round(),
        0,
        0);
  }

  CandlestickRendererElement<D> getCurrentCandlestick(double animationPercent) {
    final CandlestickRendererElement<D> bar = super.getCurrentCandlestick(animationPercent);

    // Update with series and datum information to pass to bar decorator.
    bar.series = series;
    bar.datum = datum;

    return bar;
  }

  @override
  CandlestickRendererElement<D> clone(CandlestickRendererElement other) =>
      new CandlestickRendererElement<D>.clone(other);
}
