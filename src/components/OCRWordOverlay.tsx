import Svg, { Polygon } from 'react-native-svg';
import { StyleSheet } from 'react-native';
import { OCRWord } from '../core/types';
import { toDisplay, ViewTransform } from '../core/geometry';
export function OCRWordOverlay({ words, selectedIds, transform }: { words: OCRWord[]; selectedIds: string[]; transform: ViewTransform }) {
  const selected = new Set(selectedIds);
  return <Svg pointerEvents="none" style={StyleSheet.absoluteFill} width="100%" height="100%">
    {words.map(word => {
      const b = word.boundingBox;
      const points = (word.polygon?.length ? word.polygon : [{ x: b.x, y: b.y }, { x: b.x + b.width, y: b.y }, { x: b.x + b.width, y: b.y + b.height }, { x: b.x, y: b.y + b.height }]).map(point => toDisplay(point, transform));
      return <Polygon key={word.id} points={points.map(p => `${p.x},${p.y}`).join(' ')} fill={selected.has(word.id) ? 'rgba(239,126,35,0.32)' : 'transparent'}
        stroke={selected.has(word.id) ? '#bf5b12' : 'rgba(40,86,66,0.24)'} strokeWidth={selected.has(word.id) ? 1 : 0.5} />;
    })}
  </Svg>;
}
