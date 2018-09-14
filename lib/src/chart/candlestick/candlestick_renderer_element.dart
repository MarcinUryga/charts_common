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

import '../common/chart_canvas.dart' show getAnimatedColor, FillPatternType;
import '../common/processed_series.dart' show ImmutableSeries;
import '../../common/color.dart' show Color;

abstract class BaseCandlestickRendererElement {
  int barStackIndex;
  Color color;
  num cumulativeTotal;
  List<int> dashPattern;
  Color fillColor;
  FillPatternType fillPattern;
  double measureAxisPosition;
  num measureOffset;
  num measureOffsetPlusMeasure;
  double strokeWidthPx;

  BaseCandlestickRendererElement();

  BaseCandlestickRendererElement.clone(BaseCandlestickRendererElement other) {
    barStackIndex = other.barStackIndex;
    color =
        other.color != null ? new Color.fromOther(color: other.color) : null;
    cumulativeTotal = other.cumulativeTotal;
    dashPattern = other.dashPattern;
    fillColor = other.fillColor != null
        ? new Color.fromOther(color: other.fillColor)
        : null;
    fillPattern = other.fillPattern;
    measureAxisPosition = other.measureAxisPosition;
    measureOffset = other.measureOffset;
    measureOffsetPlusMeasure = other.measureOffsetPlusMeasure;
    strokeWidthPx = other.strokeWidthPx;
  }

  void updateAnimationPercent(BaseCandlestickRendererElement previous,
      BaseCandlestickRendererElement target, double animationPercent) {
    color = getAnimatedColor(previous.color, target.color, animationPercent);
    fillColor = getAnimatedColor(
        previous.fillColor, target.fillColor, animationPercent);
  }
}

abstract class BaseAnimatedCandlestick<D, R extends BaseCandlestickRendererElement> {
  final String key;
  dynamic datum;
  ImmutableSeries<D> series;
  D domainValue;

  R _previousBar;
  R _targetBar;
  R _currentBar;

  // Flag indicating whether this bar is being animated out of the chart.
  bool animatingOut = false;

  BaseAnimatedCandlestick({this.key, this.datum, this.series, this.domainValue});

  /// Animates a bar that was removed from the series out of the view.
  ///
  /// This should be called in place of "setNewTarget" for bars that represent
  /// data that has been removed from the series.
  ///
  /// Animates the height of the bar down to the measure axis position (position
  /// of 0). Animates the width of the bar down to 0, centered in the middle of
  /// the original bar width.
  void animateOut() {
    var newTarget = clone(_currentBar);

    animateElementToMeasureAxisPosition(newTarget);

    setNewTarget(newTarget);
    animatingOut = true;
  }

  /// Sets the bounds for the target to the measure axis position.
  void animateElementToMeasureAxisPosition(R target);

  /// Sets a new element to render.
  void setNewTarget(R newTarget) {
    animatingOut = false;
    _currentBar ??= clone(newTarget);
    _previousBar = clone(_currentBar);
    _targetBar = newTarget;
  }

  R get currentCandlestick => _currentBar;

  /// Gets the new state of the bar element for painting, updated for a
  /// transition between the previous state and the new animationPercent.
  R getCurrentCandlestick(double animationPercent) {
    if (animationPercent == 1.0 || _previousBar == null) {
      _currentBar = _targetBar;
      _previousBar = _targetBar;
      return _currentBar;
    }

    _currentBar.updateAnimationPercent(
        _previousBar, _targetBar, animationPercent);

    return _currentBar;
  }

  R clone(R bar);
}
