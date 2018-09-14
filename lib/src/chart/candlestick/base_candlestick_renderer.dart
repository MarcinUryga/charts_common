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

import 'dart:collection' show LinkedHashMap;
import 'dart:math' show Point, Rectangle, max;
import 'package:meta/meta.dart' show protected, required;

import 'base_candlestick_renderer_config.dart' show BaseCandlestickRendererConfig;
import 'candlestick_renderer_element.dart' show BaseAnimatedCandlestick, BaseCandlestickRendererElement;
import '../cartesian/cartesian_renderer.dart' show BaseCartesianRenderer;
import '../cartesian/axis/axis.dart' show ImmutableAxis, domainAxisKey, measureAxisKey, OrdinalAxis;
import '../common/base_chart.dart' show BaseChart;
import '../common/chart_canvas.dart' show ChartCanvas, FillPatternType;
import '../common/datum_details.dart' show DatumDetails;
import '../common/processed_series.dart' show ImmutableSeries, MutableSeries;
import '../../common/color.dart' show Color;
import '../../common/math.dart' show clamp;
import '../../common/symbol_renderer.dart' show RoundedRectSymbolRenderer;
import '../../data/series.dart' show AttributeKey;

const candlestickGroupIndexKey = const AttributeKey<int>('CandlestickRenderer.candlestickGroupIndex');

const candlestickGroupCountKey = const AttributeKey<int>('CandlestickRenderer.candlestickGroupCount');

const candlestickGroupWeightKey = const AttributeKey<double>('CandlestickRenderer.candlestickGroupWeight');

const previousCandlestickGroupWeightKey = const AttributeKey<double>('CandlestickRenderer.previousCandlestickGroupWeight');

const stackKeyKey = const AttributeKey<String>('CandlestickRenderer.stackKey');

const candlestickElementsKey = const AttributeKey<List<BaseCandlestickRendererElement>>('CandlestickRenderer.elements');

abstract class BaseCandlestickRenderer<D, R extends BaseCandlestickRendererElement, B extends BaseAnimatedCandlestick<D, R>> extends BaseCartesianRenderer<D> {
  final BaseCandlestickRendererConfig config;

  @protected
  BaseChart<D> chart;

  final _candlestickStackMap = new LinkedHashMap<String, List<B>>();

  final _currentKeys = <String>[];

  final _currentGroupsStackKeys = new LinkedHashMap<D, Set<String>>();

  ImmutableAxis<D> _prevDomainAxis;

  BaseCandlestickRenderer(
      {@required BaseCandlestickRendererConfig config,
      String rendererId,
      int layoutPaintOrder})
      : this.config = config,
        super(
          rendererId: rendererId,
          layoutPaintOrder: layoutPaintOrder,
          symbolRenderer:
              config?.symbolRenderer ?? new RoundedRectSymbolRenderer(),
        );

  @override
  void preprocessSeries(List<MutableSeries<D>> seriesList) {
    var candlestickGroupIndex = 0;

    // Maps used to store the final measure offset of the previous series, for
    // each domain value.
    final posDomainToStackKeyToDetailsMap = {};
    final negDomainToStackKeyToDetailsMap = {};
    final categoryToIndexMap = {};

    var maxCandlestickStackSize = 0;

    final orderedSeriesList = getOrderedSeriesList(seriesList);

    orderedSeriesList.forEach((MutableSeries<D> series) {
      var elements = <BaseCandlestickRendererElement>[];

      var domainFn = series.domainFn;
      var measureFn = series.measureFn;
      var measureOffsetFn = series.measureOffsetFn;
      var fillPatternFn = series.fillPatternFn;
      var strokeWidthPxFn = series.strokeWidthPxFn;

      series.dashPatternFn ??= (_) => config.dashPattern;

      // Identifies which stack the series will go in, by default a single
      // stack.
      var stackKey = '__defaultKey__';

      // Override the stackKey with seriesCategory if we are GROUPED_STACKED
      // so we have a way to choose which series go into which stacks.
      if (config.grouped && config.stacked) {
        if (series.seriesCategory != null) {
          stackKey = series.seriesCategory;
        }

        candlestickGroupIndex = categoryToIndexMap[stackKey];
        if (candlestickGroupIndex == null) {
          candlestickGroupIndex = categoryToIndexMap.length;
          categoryToIndexMap[stackKey] = candlestickGroupIndex;
        }
      }

      var needsMeasureOffset = false;

      for (var candlestickIndex = 0; candlestickIndex < series.data.length; candlestickIndex++) {
        dynamic datum = series.data[candlestickIndex];
        final details = getBaseDetails(datum, candlestickIndex);

        details.candlestickStackIndex = 0;
        details.measureOffset = 0;

        if (fillPatternFn != null) {
          details.fillPattern = fillPatternFn(candlestickIndex);
        } else {
          details.fillPattern = config.fillPattern;
        }

        if (strokeWidthPxFn != null) {
          details.strokeWidthPx = strokeWidthPxFn(candlestickIndex).toDouble();
        } else {
          details.strokeWidthPx = config.strokeWidthPx;
        }

        // When stacking is enabled, adjust the measure offset for each domain
        // value in each series by adding up the measures and offsets of lower
        // series.
        if (config.stacked) {
          needsMeasureOffset = true;
          var domain = domainFn(candlestickIndex);
          var measure = measureFn(candlestickIndex);

          var domainToCategoryToDetailsMap = measure == null || measure >= 0
              ? posDomainToStackKeyToDetailsMap
              : negDomainToStackKeyToDetailsMap;

          var categoryToDetailsMap =
              domainToCategoryToDetailsMap.putIfAbsent(domain, () => {});

          var prevDetail = categoryToDetailsMap[stackKey];

          if (prevDetail != null) {
            details.candlestickStackIndex = prevDetail.candlestickStackIndex + 1;
          }

          details.cumulativeTotal = measure != null ? measure : 0;

          // Get the previous series' measure offset.
          var measureOffset = measureOffsetFn(candlestickIndex);
          if (prevDetail != null) {
            measureOffset += prevDetail.measureOffsetPlusMeasure;

            details.cumulativeTotal += prevDetail.cumulativeTotal;
          }

          // And overwrite the details measure offset.
          details.measureOffset = measureOffset;
          var measureValue = (measure != null ? measure : 0);
          details.measureOffsetPlusMeasure = measureOffset + measureValue;

          categoryToDetailsMap[stackKey] = details;
        }

        maxCandlestickStackSize = max(maxCandlestickStackSize, details.candlestickStackIndex + 1);

        elements.add(details);
      }

      if (needsMeasureOffset) {
        // Override the measure offset function to return the measure offset we
        // calculated for each datum. This already includes any measure offset
        // that was configured in the series data.
        series.measureOffsetFn = (index) => elements[index].measureOffset;
      }

      series.setAttr(candlestickGroupIndexKey, candlestickGroupIndex);
      series.setAttr(stackKeyKey, stackKey);
      series.setAttr(candlestickElementsKey, elements);

      if (config.grouped) {
        candlestickGroupIndex++;
      }
    });

    var numCandlestickGroups = 0;
    if (config.grouped && config.stacked) {
      numCandlestickGroups = categoryToIndexMap.length;
    } else if (config.stacked) {
      numCandlestickGroups = 1;
    } else {
      numCandlestickGroups = seriesList.length;
    }

    final candlestickWeights = _calculateCandlestickWeights(numCandlestickGroups);

    seriesList.forEach((MutableSeries<D> series) {
      series.setAttr(candlestickGroupCountKey, numCandlestickGroups);

      if (candlestickWeights.length > 0) {
        final candlestickGroupIndex = series.getAttr(candlestickGroupIndexKey);
        final candlestickWeight = candlestickWeights[candlestickGroupIndex];

        final previousCandlestickWeights = rtl
            ? candlestickWeights.getRange(candlestickGroupIndex + 1, numCandlestickGroups)
            : candlestickWeights.getRange(0, candlestickGroupIndex);

        final previousCandlestickWeight = previousCandlestickWeights.length > 0
            ? previousCandlestickWeights.reduce((a, b) => a + b)
            : 0.0;

        series.setAttr(candlestickGroupWeightKey, candlestickWeight);
        series.setAttr(previousCandlestickGroupWeightKey, previousCandlestickWeight);
      }
    });
  }

  List<double> _calculateCandlestickWeights(int numCandlestickGroups) {
    final weights = <double>[];

    if (config.weightPattern != null) {
      if (numCandlestickGroups > config.weightPattern.length) {
        throw new ArgumentError('Number of series exceeds length of weight ' +
            'pattern ${config.weightPattern}');
      }

      var totalCandlestickWeight = 0;

      for (var i = 0; i < numCandlestickGroups; i++) {
        totalCandlestickWeight += config.weightPattern[i];
      }

      for (var i = 0; i < numCandlestickGroups; i++) {
        weights.add(config.weightPattern[i] / totalCandlestickWeight);
      }
    } else {
      for (var i = 0; i < numCandlestickGroups; i++) {
        weights.add(1 / numCandlestickGroups);
      }
    }

    return weights;
  }

  /// Construct a base details element for a given datum.
  ///
  /// This is intended to be overridden by child classes that need to add
  /// customized rendering properties.
  R getBaseDetails(dynamic datum, int index);

  @override
  void configureDomainAxes(List<MutableSeries<D>> seriesList) {
    super.configureDomainAxes(seriesList);

    // TODO: tell axis that we some rangeBand configuration.
  }

  void update(List<ImmutableSeries<D>> seriesList, bool isAnimatingThisDraw) {
    _currentKeys.clear();
    _currentGroupsStackKeys.clear();

    final orderedSeriesList = getOrderedSeriesList(seriesList);

    orderedSeriesList.forEach((final ImmutableSeries<D> series) {
      final domainAxis = series.getAttr(domainAxisKey) as ImmutableAxis<D>;
      final domainFn = series.domainFn;
      final measureAxis = series.getAttr(measureAxisKey) as ImmutableAxis<num>;
      final measureFn = series.measureFn;
      final colorFn = series.colorFn;
      final dashPatternFn = series.dashPatternFn;
      final fillColorFn = series.fillColorFn;
      final seriesStackKey = series.getAttr(stackKeyKey);
      final candlestickGroupCount = series.getAttr(candlestickGroupCountKey);
      final candlestickGroupIndex = series.getAttr(candlestickGroupIndexKey);
      final previousCandlestickGroupWeight = series.getAttr(previousCandlestickGroupWeightKey);
      final candlestickGroupWeight = series.getAttr(candlestickGroupWeightKey);
      final measureAxisPosition = measureAxis.getLocation(0.0);

      var elementsList = series.getAttr(candlestickElementsKey);

      // Save off domainAxis for getNearest.
      _prevDomainAxis = domainAxis;

      for (var candlestickIndex = 0; candlestickIndex < series.data.length; candlestickIndex++) {
        final datum = series.data[candlestickIndex];
        BaseCandlestickRendererElement details = elementsList[candlestickIndex];
        D domainValue = domainFn(candlestickIndex);

        var candlestickStackMapKey = domainValue.toString() +
            '__' +
            seriesStackKey +
            '__' +
            candlestickGroupIndex.toString();

        var candlestickKey = candlestickStackMapKey + details.candlestickStackIndex.toString();

        var candlestickStackList = _candlestickStackMap.putIfAbsent(candlestickStackMapKey, () => []);

        var animatingCandlestick = candlestickStackList.firstWhere((B candlestick) => candlestick.key == candlestickKey,
            orElse: () => null);

        if (animatingCandlestick == null) {
          animatingCandlestick = makeAnimatedCandlestick(
              key: candlestickKey,
              series: series,
              datum: datum,
              candlestickGroupIndex: candlestickGroupIndex,
              previousCandlestickGroupWeight: previousCandlestickGroupWeight,
              candlestickGroupWeight: candlestickGroupWeight,
              color: colorFn(candlestickIndex),
              dashPattern: dashPatternFn(candlestickIndex),
              details: details,
              domainValue: domainFn(candlestickIndex),
              domainAxis: domainAxis,
              domainWidth: domainAxis.rangeBand.round(),
              fillColor: fillColorFn(candlestickIndex),
              fillPattern: details.fillPattern,
              measureValue: 0.0,
              measureOffsetValue: 0.0,
              measureAxisPosition: measureAxisPosition,
              measureAxis: measureAxis,
              numCandlestickGroups: candlestickGroupCount,
              strokeWidthPx: details.strokeWidthPx);

          candlestickStackList.add(animatingCandlestick);
        } else {
          animatingCandlestick
            ..datum = datum
            ..series = series
            ..domainValue = domainValue;
        }

        _currentKeys.add(candlestickKey);

        _currentGroupsStackKeys
            .putIfAbsent(domainValue, () => new Set<String>())
            .add(candlestickStackMapKey);

        BaseCandlestickRendererElement candlestickElement = makeCandlestickRendererElement(
            candlestickGroupIndex: candlestickGroupIndex,
            previousCandlestickGroupWeight: previousCandlestickGroupWeight,
            candlestickGroupWeight: candlestickGroupWeight,
            color: colorFn(candlestickIndex),
            dashPattern: dashPatternFn(candlestickIndex),
            details: details,
            domainValue: domainFn(candlestickIndex),
            domainAxis: domainAxis,
            domainWidth: domainAxis.rangeBand.round(),
            fillColor: fillColorFn(candlestickIndex),
            fillPattern: details.fillPattern,
            measureValue: measureFn(candlestickIndex),
            measureOffsetValue: details.measureOffset,
            measureAxisPosition: measureAxisPosition,
            measureAxis: measureAxis,
            numCandlestickGroups: candlestickGroupCount,
            strokeWidthPx: details.strokeWidthPx);

        animatingCandlestick.setNewTarget(candlestickElement);
      }
    });

    _candlestickStackMap.forEach((String key, List<B> candlestickStackList) {
      for (var candlestickIndex = 0; candlestickIndex < candlestickStackList.length; candlestickIndex++) {
        var candlestick = candlestickStackList[candlestickIndex];

        if (_currentKeys.contains(candlestick.key) != true) {
          candlestick.animateOut();
        }
      }
    });
  }

  B makeAnimatedCandlestick(
      {String key,
      ImmutableSeries<D> series,
      dynamic datum,
      int candlestickGroupIndex,
      double previousCandlestickGroupWeight,
      double candlestickGroupWeight,
      Color color,
      List<int> dashPattern,
      R details,
      D domainValue,
      ImmutableAxis<D> domainAxis,
      int domainWidth,
      num measureValue,
      num measureOffsetValue,
      ImmutableAxis<num> measureAxis,
      double measureAxisPosition,
      int numCandlestickGroups,
      Color fillColor,
      FillPatternType fillPattern,
      double strokeWidthPx});

  R makeCandlestickRendererElement(
      {int candlestickGroupIndex,
      double previousCandlestickGroupWeight,
      double candlestickGroupWeight,
      Color color,
      List<int> dashPattern,
      R details,
      D domainValue,
      ImmutableAxis<D> domainAxis,
      int domainWidth,
      num measureValue,
      num measureOffsetValue,
      ImmutableAxis<num> measureAxis,
      double measureAxisPosition,
      int numCandlestickGroups,
      Color fillColor,
      FillPatternType fillPattern,
      double strokeWidthPx});

  @override
  void onAttach(BaseChart<D> chart) {
    super.onAttach(chart);
    // We only need the chart.context.rtl setting, but context is not yet
    // available when the default renderer is attached to the chart on chart
    // creation time, since chart onInit is called after the chart is created.
    this.chart = chart;
  }

  void paint(ChartCanvas canvas, double animationPercent) {
    if (animationPercent == 1.0) {
      final keysToRemove = <String>[];

      _candlestickStackMap.forEach((String key, List<B> candlestickStackList) {
        candlestickStackList.retainWhere((B candlestick) => !candlestick.animatingOut);

        if (candlestickStackList.isEmpty) {
          keysToRemove.add(key);
        }
      });

      keysToRemove.forEach((String key) => _candlestickStackMap.remove(key));
    }

    _candlestickStackMap.forEach((String stackKey, List<B> candlestickStack) {
      final candlestickElements = candlestickStack
          .map((B animatingCandlestick) => animatingCandlestick.getCurrentCandlestick(animationPercent))
          .toList();

      paintCandlestick(canvas, animationPercent, candlestickElements);
    });
  }

  void paintCandlestick(
      ChartCanvas canvas, double animationPercent, Iterable<R> candlestickElements);

  @override
  List<DatumDetails<D>> getNearestDatumDetailPerSeries(
      Point<double> chartPoint, bool byDomain, Rectangle<int> boundsOverride) {
    var nearest = <DatumDetails<D>>[];

    // Was it even in the component bounds?
    if (!isPointWithinBounds(chartPoint, boundsOverride)) {
      return nearest;
    }

    if (_prevDomainAxis is OrdinalAxis) {
      final domainValue = _prevDomainAxis
          .getDomain(renderingVertically ? chartPoint.x : chartPoint.y);

      // If we have a domainValue for the event point, then find all segments
      // that match it.
      if (domainValue != null) {
        if (renderingVertically) {
          nearest = _getVerticalDetailsForDomainValue(domainValue, chartPoint);
        } else {
          nearest =
              _getHorizontalDetailsForDomainValue(domainValue, chartPoint);
        }
      }
    } else {
      if (renderingVertically) {
        nearest = _getVerticalDetailsForDomainValue(null, chartPoint);
      } else {
        nearest = _getHorizontalDetailsForDomainValue(null, chartPoint);
      }

      // Find the closest domain and only keep values that match the domain.
      var minRelativeDistance = double.maxFinite;
      var minDomainDistance = double.maxFinite;
      var minMeasureDistance = double.maxFinite;
      D nearestDomain;

      // TODO: Optimize this with a binary search based on chartX.
      for (DatumDetails<D> detail in nearest) {
        if (byDomain) {
          if (detail.domainDistance < minDomainDistance ||
              (detail.domainDistance == minDomainDistance &&
                  detail.measureDistance < minMeasureDistance)) {
            minDomainDistance = detail.domainDistance;
            minMeasureDistance = detail.measureDistance;
            nearestDomain = detail.domain;
          }
        } else {
          if (detail.relativeDistance < minRelativeDistance) {
            minRelativeDistance = detail.relativeDistance;
            nearestDomain = detail.domain;
          }
        }
      }

      nearest.retainWhere((d) => d.domain == nearestDomain);
    }

    // If we didn't find anything, then keep an empty list.
    nearest ??= <DatumDetails<D>>[];

    // Note: the details are already sorted by domain & measure distance in
    // base chart.
    return nearest;
  }

  Rectangle<int> getBoundsForCandlestick(R candlestick);

  @protected
  List<BaseAnimatedCandlestick<D, R>> _getSegmentsForDomainValue(D domainValue,
      {bool where(BaseAnimatedCandlestick<D, R> candlestick)}) {
    final matchingSegments = <BaseAnimatedCandlestick<D, R>>[];

    final stackKeys = (domainValue != null)
        ? _currentGroupsStackKeys[domainValue]
        : _currentGroupsStackKeys.values
            .reduce((allKeys, keys) => allKeys..addAll(keys));
    stackKeys?.forEach((String stackKey) {
      if (where != null) {
        matchingSegments.addAll(_candlestickStackMap[stackKey].where(where));
      } else {
        matchingSegments.addAll(_candlestickStackMap[stackKey]);
      }
    });

    return matchingSegments;
  }

  // In the case of null [domainValue] return all values to be compared, since
  // we can't use the optimized comparison for [OrdinalAxis].
  List<DatumDetails<D>> _getVerticalDetailsForDomainValue(
      D domainValue, Point<double> chartPoint) {
    return new List<DatumDetails<D>>.from(_getSegmentsForDomainValue(
            domainValue,
            where: (BaseAnimatedCandlestick<D, R> candlestick) => !candlestick.series.overlaySeries)
        .map<DatumDetails<D>>((BaseAnimatedCandlestick<D, R> candlestick) {
      final candlestickBounds = getBoundsForCandlestick(candlestick.currentCandlestick);
      final segmentDomainDistance =
          _getDistance(chartPoint.x.round(), candlestickBounds.left, candlestickBounds.right);
      final segmentMeasureDistance =
          _getDistance(chartPoint.y.round(), candlestickBounds.top, candlestickBounds.bottom);

      final nearestPoint = new Point<double>(
          clamp(chartPoint.x, candlestickBounds.left, candlestickBounds.right).toDouble(),
          clamp(chartPoint.y, candlestickBounds.top, candlestickBounds.bottom).toDouble());

      final relativeDistance = chartPoint.distanceTo(nearestPoint);

      return new DatumDetails<D>(
        series: candlestick.series,
        datum: candlestick.datum,
        domain: candlestick.domainValue,
        domainDistance: segmentDomainDistance,
        measureDistance: segmentMeasureDistance,
        relativeDistance: relativeDistance,
      );
    }));
  }

  List<DatumDetails<D>> _getHorizontalDetailsForDomainValue(
      D domainValue, Point<double> chartPoint) {
    return new List<DatumDetails<D>>.from(_getSegmentsForDomainValue(
            domainValue,
            where: (BaseAnimatedCandlestick<D, R> candlestick) => !candlestick.series.overlaySeries)
        .map((BaseAnimatedCandlestick<D, R> candlestick) {
      final candlestickBounds = getBoundsForCandlestick(candlestick.currentCandlestick);
      final segmentDomainDistance =
          _getDistance(chartPoint.y.round(), candlestickBounds.top, candlestickBounds.bottom);
      final segmentMeasureDistance =
          _getDistance(chartPoint.x.round(), candlestickBounds.left, candlestickBounds.right);

      return new DatumDetails<D>(
        series: candlestick.series,
        datum: candlestick.datum,
        domain: candlestick.domainValue,
        domainDistance: segmentDomainDistance,
        measureDistance: segmentMeasureDistance,
      );
    }));
  }

  double _getDistance(int point, int min, int max) {
    if (max >= point && min <= point) {
      return 0.0;
    }
    return (point > max ? (point - max) : (min - point)).toDouble();
  }

  @protected
  Iterable<S> getOrderedSeriesList<S extends ImmutableSeries>(
      List<S> seriesList) {
    return (renderingVertically && config.stacked)
        ? config.grouped
            ? new _ReversedSeriesIterable(seriesList)
            : seriesList.reversed
        : seriesList;
  }

  bool get rtl => chart.context.rtl;
}

/// Iterable wrapping the seriesList that returns the ReversedSeriesItertor.
class _ReversedSeriesIterable<S extends ImmutableSeries> extends Iterable<S> {
  final List<S> seriesList;

  _ReversedSeriesIterable(this.seriesList);

  @override
  Iterator<S> get iterator => new _ReversedSeriesIterator(seriesList);
}

class _ReversedSeriesIterator<S extends ImmutableSeries> extends Iterator<S> {
  final List<S> _list;
  final _visitIndex = <int>[];
  int _current;

  _ReversedSeriesIterator(List<S> list) : _list = list {
    // In the order of the list, save the category and the indices of the series
    // with the same category.
    final categoryAndSeriesIndexMap = <String, List<int>>{};
    for (var i = 0; i < list.length; i++) {
      categoryAndSeriesIndexMap
          .putIfAbsent(list[i].seriesCategory, () => <int>[])
          .add(i);
    }

    // Creates a visit that is categories in order, but the series is reversed.
    categoryAndSeriesIndexMap
        .forEach((_, indices) => _visitIndex.addAll(indices.reversed));
  }
  @override
  bool moveNext() {
    _current = (_current == null) ? 0 : _current + 1;

    return _current < _list.length;
  }

  @override
  S get current => _list[_visitIndex[_current]];
}
