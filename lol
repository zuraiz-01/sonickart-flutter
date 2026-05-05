
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 14 pixels on the right.

The relevant error-causing widget was:
  Row
  Row:file:///E:/work%20space/zia%20tech%20projects/soniccart_flutter/lib/app/modules/cart/widgets  /universal_add.dart:69:24

The overflowing RenderFlex has an orientation of Axis.horizontal.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,like a ListView.
The specific RenderFlex in question is: RenderFlex#bdfe1 relayoutBoundary=up7 OVERFLOWING:
  creator: Row ← Padding ← Padding ← DecoratedBox ← ConstrainedBox ← Container ← AnimatedContainer  ←
    Obx ← UniversalAdd ← SizedBox ← Align ← Column ← ⋯
  parentData: offset=Offset(3.8, 5.0) (can use size)
  constraints: BoxConstraints(w=48.0, 29.7<=h<=Infinity)
  size: Size(48.0, 29.7)
  direction: horizontal
  mainAxisAlignment: spaceBetween
  mainAxisSize: max
  crossAxisAlignment: center
  textDirection: ltr
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════


isko sahi kro ur home page pa view more ka neachy jo lines wagra reactnative ma hai vo flutter ma bhe dalo 