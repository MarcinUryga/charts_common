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

import 'base_candlestick_renderer_config.dart' show CandlestickGroupingType;
import 'candlestick_label_decorator.dart' show CandlestickLabelDecorator;
import 'candlestick_lane_renderer.dart' show CandlestickLaneRenderer;
import 'candlestick_renderer_config.dart' show CandlestickRendererConfig, CornerStrategy;
import 'candlestick_renderer_decorator.dart' show CandlestickRendererDecorator;
import '../common/chart_canvas.dart' show FillPatternType;
import '../layout/layout_view.dart' show LayoutViewPaintOrder;
import '../../common/color.dart' show Color;
import '../../common/style/style_factory.dart' show StyleFactory;
import '../../common/symbol_renderer.dart';

class CandlestickLaneRendererConfig extends CandlestickRendererConfig<String> {
  final Color backgroundCandlestickColor;

  /// Label text to draw on a merged empty lane.
  ///
  /// This will only be drawn if all of the measures for a domain are null, and
  /// [mergeEmptyLanes] is enabled.
  ///
  /// The renderer must be configured with a [CandlestickLabelDecorator] for this label
  /// to be drawn.
  final String emptyLaneLabel;

  /// Whether or not all lanes for a given domain value should be merged into
  /// one wide lane if all measure values for said domain are null.
  final bool mergeEmptyLanes;

  CandlestickLaneRendererConfig({
    String customRendererId,
    CornerStrategy cornerStrategy,
    this.emptyLaneLabel = 'No data',
    FillPatternType fillPattern,
    CandlestickGroupingType groupingType,
    int layoutPaintOrder = LayoutViewPaintOrder.candlestick,
    this.mergeEmptyLanes = false,
    int minCandlestickLengthPx = 0,
    double stackHorizontalSeparator,
    double strokeWidthPx = 0.0,
    CandlestickRendererDecorator candlestickRendererDecorator,
    SymbolRenderer symbolRenderer,
    Color backgroundCandlestickColor,
    List<int> weightPattern,
  })  : backgroundCandlestickColor =
            backgroundCandlestickColor ?? StyleFactory.style.noDataColor,
        super(
          candlestickRendererDecorator: candlestickRendererDecorator,
          cornerStrategy: cornerStrategy,
          customRendererId: customRendererId,
          groupingType: groupingType ?? CandlestickGroupingType.grouped,
          layoutPaintOrder: layoutPaintOrder,
          minCandlestickLengthPx: minCandlestickLengthPx,
          fillPattern: fillPattern,
          stackHorizontalSeparator: stackHorizontalSeparator,
          strokeWidthPx: strokeWidthPx,
          symbolRenderer: symbolRenderer,
          weightPattern: weightPattern,
        );

  @override
  CandlestickLaneRenderer<String> build() {
    return new CandlestickLaneRenderer<String>(
        config: this, rendererId: customRendererId);
  }

  @override
  bool operator ==(o) {
    if (identical(this, o)) {
      return true;
    }
    if (!(o is CandlestickLaneRendererConfig)) {
      return false;
    }
    return o.backgroundCandlestickColor == backgroundCandlestickColor &&
        o.emptyLaneLabel == emptyLaneLabel &&
        o.mergeEmptyLanes == mergeEmptyLanes &&
        super == (o);
  }

  @override
  int get hashCode {
    var hash = super.hashCode;
    hash = hash * 31 + (backgroundCandlestickColor?.hashCode ?? 0);
    hash = hash * 31 + (emptyLaneLabel?.hashCode ?? 0);
    hash = hash * 31 + (mergeEmptyLanes?.hashCode ?? 0);
    return hash;
  }
}
