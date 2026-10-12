import { useMemo, useRef, useState } from 'react';
import { Image, StyleSheet, View } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import { OCRResult, Point } from '../core/types';
import { hitWord, imageTransform } from '../core/geometry';
import { TextSelectionController } from '../core/selection';
import { OCRWordOverlay } from './OCRWordOverlay';

export function CapturedPageViewer({ page, selectedIds, enabled, onSelect, onCancel }: {
  page: OCRResult; selectedIds: string[]; enabled: boolean;
  onSelect: (ids: string[], finalized: boolean) => void; onCancel: () => void;
}) {
  const [viewport, setViewport] = useState({ width: 1, height: 1 });
  const [view, setView] = useState({ zoom: 1, pan: { x: 0, y: 0 } });
  const viewRef = useRef(view); const pinchStart = useRef({ ...view, focal: { x: 0, y: 0 } });
  const panStart = useRef<Point>({ x: 0, y: 0 });
  const selecting = useRef(false); const endpoint = useRef<string | undefined>(undefined);
  const pinching = useRef(false);
  const controller = useMemo(() => new TextSelectionController(page.words), [page.words]);
  const transform = imageTransform(page.image, viewport, view.zoom, view.pan);
  const transformRef = useRef(transform); transformRef.current = transform;
  const updateView = (next: typeof view) => { viewRef.current = next; setView(next); };
  const pan = Gesture.Pan().enabled(enabled).minDistance(0).maxPointers(1).runOnJS(true)
    .onBegin(event => {
      pinching.current = false; selecting.current = false; panStart.current = viewRef.current.pan;
      const word = hitWord(page.words, { x: event.x, y: event.y }, transformRef.current);
      if (word) { selecting.current = true; endpoint.current = word.id; onSelect(controller.begin(word.id).map(w => w.id), false); }
    })
    .onUpdate(event => {
      if (pinching.current) return;
      if (selecting.current) {
        const word = hitWord(page.words, { x: event.x, y: event.y }, transformRef.current);
        if (word && word.id !== endpoint.current) { endpoint.current = word.id; onSelect(controller.move(word.id).map(w => w.id), false); }
      } else updateView({ zoom: viewRef.current.zoom, pan: { x: panStart.current.x + event.translationX, y: panStart.current.y + event.translationY } });
    })
    .onEnd(() => { if (selecting.current && !pinching.current) onSelect(controller.current().map(w => w.id), true); })
    .onFinalize((_, success) => { if (!success && selecting.current) onCancel(); selecting.current = false; });
  const pinch = Gesture.Pinch().enabled(enabled).runOnJS(true)
    .onStart(event => {
      pinching.current = true;
      if (selecting.current) { onCancel(); selecting.current = false; }
      pinchStart.current = { ...viewRef.current, focal: { x: event.focalX, y: event.focalY } };
    })
    .onUpdate(event => {
      const start = pinchStart.current; const zoom = Math.max(1, Math.min(5, start.zoom * event.scale));
      const ratio = zoom / start.zoom;
      updateView({ zoom, pan: { x: event.focalX - viewport.width / 2 - (start.focal.x - viewport.width / 2 - start.pan.x) * ratio,
        y: event.focalY - viewport.height / 2 - (start.focal.y - viewport.height / 2 - start.pan.y) * ratio } });
    });
  return <GestureDetector gesture={Gesture.Simultaneous(pan, pinch)}>
    <View accessibilityLabel="Captured page. Drag over words to select. Use two fingers to zoom, or drag empty space to pan." style={local.viewer}
      onLayout={event => setViewport(event.nativeEvent.layout)}>
      <Image accessibilityLabel="Captured book page" source={{ uri: page.image.uri }} resizeMode="stretch"
        style={{ position: 'absolute', left: transform.offsetX, top: transform.offsetY, width: page.image.width * transform.scale, height: page.image.height * transform.scale }} />
      <OCRWordOverlay words={page.words} selectedIds={selectedIds} transform={transform} />
    </View>
  </GestureDetector>;
}
const local = StyleSheet.create({ viewer: { flex: 1, backgroundColor: '#171d19', overflow: 'hidden' } });
