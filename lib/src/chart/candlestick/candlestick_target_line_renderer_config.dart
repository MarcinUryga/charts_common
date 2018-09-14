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

import 'base_candlestick_renderer_config.dart'
    show CandlestickGroupingType, BaseCandlestickRendererConfig;
import 'candlestick_target_line_renderer.dart' show BarTargetLineRenderer;
import '../layout/layout_view.dart' show LayoutViewPaintOrder;
import '../../common/symbol_renderer.dart'
    show SymbolRenderer, LineSymbolRenderer;

/// Configuration for a bar target line renderer.
class BarTargetLineRendererConfig<D> extends BaseCandlestickRendererConfig<D> {
  /// The number of pixels that the line will extend beyond the bandwidth at the
  /// edges of the bar group.
  ///
  /// If set, this overrides overDrawPx for the beginning side of the first bar
  /// target line in the group, and the ending side of the last bar target line.
  /// overDrawPx will be used for overdrawing the target lines for interior
  /// sides of the bars.
  final int overDrawOuterPx;

  /// The number of pixels that the line will extend beyond the bandwidth for
  /// every bar in a group.
  final int overDrawPx;

  /// Whether target lines should have round end caps, or square if false.
  final bool roundEndCaps;

  BarTargetLineRendererConfig(
      {String customRendererId,
      List<int> dashPattern,
      groupingType = CandlestickGroupingType.grouped,
      int layoutPaintOrder = LayoutViewPaintOrder.barTargetLine,
      int minBarLengthPx = 0,
      this.overDrawOuterPx,
      this.overDrawPx = 0,
      this.roundEndCaps = true,
      double strokeWidthPx = 3.0,
      SymbolRenderer symbolRenderer,
      List<int> weightPattern})
      : super(
          customRendererId: customRendererId,
          dashPattern: dashPattern,
          groupingType: groupingType,
          layoutPaintOrder: layoutPaintOrder,
          minCandlestickLengthPx: minBarLengthPx,
          strokeWidthPx: strokeWidthPx,
          symbolRenderer: symbolRenderer ?? new LineSymbolRenderer(),
          weightPattern: weightPattern,
        );

  @override
  BarTargetLineRenderer<D> build() {
    return new BarTargetLineRenderer<D>(
        config: this, rendererId: customRendererId);
  }

  @override
  bool operator ==(o) {
    if (identical(this, o)) {
      return true;
    }
    if (!(o is BarTargetLineRendererConfig)) {
      return false;
    }
    return o.overDrawOuterPx == overDrawOuterPx &&
        o.overDrawPx == overDrawPx &&
        o.roundEndCaps == roundEndCaps &&
        super == (o);
  }

  @override
  int get hashCode {
    var hash = 1;
    hash = hash * 31 + (overDrawOuterPx?.hashCode ?? 0);
    hash = hash * 31 + (overDrawPx?.hashCode ?? 0);
    hash = hash * 31 + (roundEndCaps?.hashCode ?? 0);
    return hash;
  }
}
