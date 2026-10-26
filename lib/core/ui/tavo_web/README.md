# Tavo web kit

Flutter widgets that reproduce the Tavo marketing site inside the restaurant
panel. Tokens are logical pixels sampled 1:1 from the site's CSS, so a value in
`tavo_tokens.dart` is the value in `Tavo-Website/src/app/globals.css`. The full
evidence trail, contrast notes and CSS→Flutter map live in
[`docs/design/tavo-website-design-system.md`](../../../../docs/design/tavo-website-design-system.md).

```dart
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';

TavoCard(
  child: Column(children: [
    TavoSectionHeader(title: t('tonight'), action: TavoStatusPill(label: t('live'), tone: TavoTone.success)),
    TavoStatTile(label: t('covers'), value: covers),
    TavoButton.primary(label: t('save'), onPressed: save),
  ]),
);
```

| Export | Use |
|---|---|
| `TavoButton` | primary / secondary / ghost / destructive, 3 sizes, icon slots, loading, disabled |
| `TavoCard` · `TavoStatTile` · `TavoSectionHeader` | content surfaces |
| `TavoStatusPill` · `TavoChip` · `TavoIconTile` | status, filter and icon pills |
| `TavoSheet.show` | drag-to-dismiss modal sheet |
| `TavoReveal` · `TavoPressScale` · `TavoAnimatedSwitcher` | motion, reduced-motion aware |
| `TavoColors` · `TavoType` · `TavoSpace` · `TavoRadii` · `TavoShadows` · `TavoMotion` | tokens |

No copy lives in the kit: pass localised strings. Layout is directionality-safe
(`EdgeInsetsDirectional`, `Row` order, no `left`/`right`), so Arabic mirrors
without a flag.
