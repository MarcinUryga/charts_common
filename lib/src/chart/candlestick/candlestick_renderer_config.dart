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
import 'candlestick_renderer.dart' show CandlestickRenderer;
import 'candlestick_renderer_decorator.dart' show CandlestickRendererDecorator;
import '../common/chart_canvas.dart' show FillPatternType;
import '../layout/layout_view.dart' show LayoutViewPaintOrder;
import '../../common/symbol_renderer.dart';

/// Configuration for a bar renderer.
class CandlestickRendererConfig<D> extends BaseCandlestickRendererConfig<D> {
  /// Strategy for determining the corner radius of a bar.
  final CornerStrategy cornerStrategy;

  /// Decorator for optionally decorating painted bars.
  final CandlestickRendererDecorator candlestickRendererDecorator;

  CandlestickRendererConfig({
    String customRendererId,
    CornerStrategy cornerStrategy,
    FillPatternType fillPattern,
    CandlestickGroupingType groupingType,
    int layoutPaintOrder = LayoutViewPaintOrder.candlestick,
    int minBarLengthPx = 0,
    double stackHorizontalSeparator,
    double strokeWidthPx = 0.0,
    this.candlestickRendererDecorator,
    SymbolRenderer symbolRenderer,
    List<int> weightPattern,
  })  : cornerStrategy = cornerStrategy ?? const ConstCornerStrategy(2),
        super(
          customRendererId: customRendererId,
          groupingType: groupingType ?? CandlestickGroupingType.grouped,
          layoutPaintOrder: layoutPaintOrder,
          minCandlestickLengthPx: minBarLengthPx,
          fillPattern: fillPattern,
          stackHorizontalSeparator: stackHorizontalSeparator,
          strokeWidthPx: strokeWidthPx,
          symbolRenderer: symbolRenderer,
          weightPattern: weightPattern,
        );

  @override
  CandlestickRenderer<D> build() {
    return new CandlestickRenderer<D>(config: this, rendererId: customRendererId);
  }

  @override
  bool operator ==(o) {
    if (identical(this, o)) {
      return true;
    }
    if (!(o is CandlestickRendererConfig)) {
      return false;
    }
    return o.cornerStrategy == cornerStrategy && super == (o);
  }

  @override
  int get hashCode {
    var hash = super.hashCode;
    hash = hash * 31 + (cornerStrategy?.hashCode ?? 0);
    return hash;
  }
}

abstract class CornerStrategy {
  /// Returns the radius of the rounded corners in pixels.
  int getRadius(int barWidth);
}

/// Strategy for constant corner radius.
class ConstCornerStrategy implements CornerStrategy {
  final int radius;
  const ConstCornerStrategy(this.radius);

  @override
  int getRadius(_) => radius;
}

/// Strategy for no corner radius.
class NoCornerStrategy extends ConstCornerStrategy {
  const NoCornerStrategy() : super(0);
}
