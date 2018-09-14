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

import 'candlestick_renderer.dart' show AnimatedCandlestick, CandlestickRenderer, CandlestickRendererElement;
import 'candlestick_lane_renderer_config.dart' show CandlestickLaneRendererConfig;
import 'candlestick_renderer_decorator.dart' show CandlestickRendererDecorator;
import 'base_candlestick_renderer.dart'
    show
        candlestickGroupCountKey,
        candlestickGroupIndexKey,
        candlestickGroupWeightKey,
        previousCandlestickGroupWeightKey,
        stackKeyKey;
import 'candlestick_renderer_element.dart' show BaseCandlestickRendererElement;
import '../cartesian/cartesian_chart.dart' show CartesianChart;
import '../cartesian/axis/axis.dart' show ImmutableAxis, domainAxisKey, measureAxisKey;
import '../common/chart_canvas.dart' show ChartCanvas;
import '../common/processed_series.dart' show ImmutableSeries, MutableSeries;
import '../../data/series.dart' show AttributeKey;

const domainValuesKey = const AttributeKey<Set>('CandlestickLaneRenderer.domainValues');

class CandlestickLaneRenderer<D> extends CandlestickRenderer<D> {
  final CandlestickRendererDecorator candlestickRendererDecorator;

  final _candlestickLaneStackMap = new LinkedHashMap<String, List<AnimatedCandlestick<D>>>();

  final _allMeasuresForDomainNullMap = new LinkedHashMap<D, bool>();

  factory CandlestickLaneRenderer({CandlestickLaneRendererConfig config, String rendererId}) {
    rendererId ??= 'candlestick';
    config ??= new CandlestickLaneRendererConfig();
    return new CandlestickLaneRenderer._internal(
        config: config, rendererId: rendererId);
  }

  CandlestickLaneRenderer._internal({CandlestickLaneRendererConfig config, String rendererId})
      : candlestickRendererDecorator = config.candlestickRendererDecorator,
        super.internal(config: config, rendererId: rendererId);

  @override
  void preprocessSeries(List<MutableSeries<D>> seriesList) {
    super.preprocessSeries(seriesList);

    _allMeasuresForDomainNullMap.clear();

    seriesList.forEach((MutableSeries<D> series) {
      final domainFn = series.domainFn;
      final measureFn = series.rawMeasureFn;

      final domainValues = new Set<D>();

      for (var candlestickIndex = 0; candlestickIndex < series.data.length; candlestickIndex++) {
        final domain = domainFn(candlestickIndex);
        final measure = measureFn(candlestickIndex);

        domainValues.add(domain);

        if ((config as CandlestickLaneRendererConfig).mergeEmptyLanes) {
          final allNull = _allMeasuresForDomainNullMap[domain];
          final isNull = measure == null;

          _allMeasuresForDomainNullMap[domain] =
              allNull != null ? allNull && isNull : isNull;
        }
      }

      series.setAttr(domainValuesKey, domainValues);
    });
  }

  @override
  void update(List<ImmutableSeries<D>> seriesList, bool isAnimatingThisDraw) {
    super.update(seriesList, isAnimatingThisDraw);

    seriesList.forEach((ImmutableSeries<D> series) {
      Set<D> domainValues = series.getAttr(domainValuesKey) as Set<D>;

      final domainAxis = series.getAttr(domainAxisKey) as ImmutableAxis<D>;
      final measureAxis = series.getAttr(measureAxisKey) as ImmutableAxis<num>;
      final seriesStackKey = series.getAttr(stackKeyKey);
      final candlestickGroupCount = series.getAttr(candlestickGroupCountKey);
      final candlestickGroupIndex = series.getAttr(candlestickGroupIndexKey);
      final previousCandlestickGroupWeight = series.getAttr(previousCandlestickGroupWeightKey);
      final candlestickGroupWeight = series.getAttr(candlestickGroupWeightKey);
      final measureAxisPosition = measureAxis.getLocation(0.0);
      final maxMeasureValue = _getMaxMeasureValue(measureAxis);

      final laneSeries = new MutableSeries<D>.clone(seriesList[0]);
      laneSeries.data = [];

      // Don't render any labels on the swim lanes.
      laneSeries.labelAccessorFn = (int index) => '';

      var laneSeriesIndex = 0;
      domainValues.forEach((D domainValue) {
        if (_allMeasuresForDomainNullMap[domainValue] == true) {
          return;
        }

        final datum = {'index': laneSeriesIndex};
        laneSeries.data.add(datum);

        final candlestickStackMapKey = domainValue.toString() +
            '__' +
            seriesStackKey +
            '__' +
            candlestickGroupIndex.toString();

        final candlestickKey = candlestickStackMapKey + '0';

        final candlestickStackList = _candlestickLaneStackMap.putIfAbsent(
            candlestickStackMapKey, () => <AnimatedCandlestick<D>>[]);

        var animatingCandlestick = candlestickStackList.firstWhere(
            (AnimatedCandlestick candlestick) => candlestick.key == candlestickKey,
            orElse: () => null);

        if (animatingCandlestick == null) {
          animatingCandlestick = makeAnimatedCandlestick(
              key: candlestickKey,
              series: laneSeries,
              datum: datum,
              candlestickGroupIndex: candlestickGroupIndex,
              previousCandlestickGroupWeight: previousCandlestickGroupWeight,
              candlestickGroupWeight: candlestickGroupWeight,
              color: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
              details: new CandlestickRendererElement<D>(),
              domainValue: domainValue,
              domainAxis: domainAxis,
              domainWidth: domainAxis.rangeBand.round(),
              fillColor: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
              measureValue: maxMeasureValue,
              measureOffsetValue: 0.0,
              measureAxisPosition: measureAxisPosition,
              measureAxis: measureAxis,
              numCandlestickGroups: candlestickGroupCount,
              strokeWidthPx: config.strokeWidthPx);

          candlestickStackList.add(animatingCandlestick);
        } else {
          animatingCandlestick
            ..datum = datum
            ..series = laneSeries
            ..domainValue = domainValue;
        }

        BaseCandlestickRendererElement candlestickElement = makeCandlestickRendererElement(
            candlestickGroupIndex: candlestickGroupIndex,
            previousCandlestickGroupWeight: previousCandlestickGroupWeight,
            candlestickGroupWeight: candlestickGroupWeight,
            color: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
            details: new CandlestickRendererElement<D>(),
            domainValue: domainValue,
            domainAxis: domainAxis,
            domainWidth: domainAxis.rangeBand.round(),
            fillColor: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
            measureValue: maxMeasureValue,
            measureOffsetValue: 0.0,
            measureAxisPosition: measureAxisPosition,
            measureAxis: measureAxis,
            numCandlestickGroups: candlestickGroupCount,
            strokeWidthPx: config.strokeWidthPx);

        animatingCandlestick.setNewTarget(candlestickElement);

        laneSeriesIndex++;
      });
    });

    if ((config as CandlestickLaneRendererConfig).mergeEmptyLanes) {
      // Use the axes from the first series.
      final domainAxis =
          seriesList[0].getAttr(domainAxisKey) as ImmutableAxis<D>;
      final measureAxis =
          seriesList[0].getAttr(measureAxisKey) as ImmutableAxis<num>;

      final measureAxisPosition = measureAxis.getLocation(0.0);
      final maxMeasureValue = _getMaxMeasureValue(measureAxis);

      final candlestickGroupIndex = 0;
      final previousCandlestickGroupWeight = 0.0;
      final candlestickGroupWeight = 1.0;
      final candlestickGroupCount = 1;

      final mergedSeries = new MutableSeries<D>.clone(seriesList[0]);
      mergedSeries.data = [];

      // Add a label accessor that returns the empty lane label.
      mergedSeries.labelAccessorFn =
          (int index) => (config as CandlestickLaneRendererConfig).emptyLaneLabel;

      var mergedSeriesIndex = 0;
      _allMeasuresForDomainNullMap.forEach((D domainValue, bool allNull) {
        if (allNull) {
          final datum = {'index': mergedSeriesIndex};
          mergedSeries.data.add(datum);

          final candlestickStackMapKey = domainValue.toString() + '__allNull__';

          final candlestickKey = candlestickStackMapKey + '0';

          final candlestickStackList = _candlestickLaneStackMap.putIfAbsent(
              candlestickStackMapKey, () => <AnimatedCandlestick<D>>[]);

          var animatingCandlestick = candlestickStackList.firstWhere(
              (AnimatedCandlestick candlestick) => candlestick.key == candlestickKey,
              orElse: () => null);

          if (animatingCandlestick == null) {
            animatingCandlestick = makeAnimatedCandlestick(
                key: candlestickKey,
                series: mergedSeries,
                datum: datum,
                candlestickGroupIndex: candlestickGroupIndex,
                previousCandlestickGroupWeight: previousCandlestickGroupWeight,
                candlestickGroupWeight: candlestickGroupWeight,
                color: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
                details: new CandlestickRendererElement<D>(),
                domainValue: domainValue,
                domainAxis: domainAxis,
                domainWidth: domainAxis.rangeBand.round(),
                fillColor: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
                measureValue: maxMeasureValue,
                measureOffsetValue: 0.0,
                measureAxisPosition: measureAxisPosition,
                measureAxis: measureAxis,
                numCandlestickGroups: candlestickGroupCount,
                strokeWidthPx: config.strokeWidthPx);

            candlestickStackList.add(animatingCandlestick);
          } else {
            animatingCandlestick
              ..datum = datum
              ..series = mergedSeries
              ..domainValue = domainValue;
          }

          BaseCandlestickRendererElement candlestickElement = makeCandlestickRendererElement(
              candlestickGroupIndex: candlestickGroupIndex,
              previousCandlestickGroupWeight: previousCandlestickGroupWeight,
              candlestickGroupWeight: candlestickGroupWeight,
              color: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
              details: new CandlestickRendererElement<D>(),
              domainValue: domainValue,
              domainAxis: domainAxis,
              domainWidth: domainAxis.rangeBand.round(),
              fillColor: (config as CandlestickLaneRendererConfig).backgroundCandlestickColor,
              measureValue: maxMeasureValue,
              measureOffsetValue: 0.0,
              measureAxisPosition: measureAxisPosition,
              measureAxis: measureAxis,
              numCandlestickGroups: candlestickGroupCount,
              strokeWidthPx: config.strokeWidthPx);

          animatingCandlestick.setNewTarget(candlestickElement);

          mergedSeriesIndex++;
        }
      });
    }
  }

  /// Gets the maximum measure value that will fit in the draw area.
  num _getMaxMeasureValue(ImmutableAxis<num> measureAxis) {
    final pos = (chart as CartesianChart).vertical
        ? chart.drawAreaBounds.top
        : rtl ? chart.drawAreaBounds.left : chart.drawAreaBounds.right;

    return measureAxis.getDomain(pos.toDouble());
  }

  @override
  void paint(ChartCanvas canvas, double animationPercent) {
    _candlestickLaneStackMap.forEach((String stackKey, List<AnimatedCandlestick<D>> candlestickStack) {
      List<CandlestickRendererElement<D>> candlestickElements = candlestickStack
          .map((AnimatedCandlestick<D> animatingCandlestick) =>
              animatingCandlestick.getCurrentCandlestick(animationPercent))
          .toList();

      paintCandlestick(canvas, animationPercent, candlestickElements);
    });

    super.paint(canvas, animationPercent);
  }
}
