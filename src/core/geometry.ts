import { Box, OCRWord, Point } from './types';

export interface ViewTransform {
  scale: number;
  offsetX: number;
  offsetY: number;
}
// Image is contained (never cropped); pan and pinch scale about the viewport center.
export function imageTransform(image: { width: number; height: number }, viewport: { width: number; height: number }, zoom = 1, pan: Point = { x: 0, y: 0 }): ViewTransform {
  if (image.width <= 0 || image.height <= 0 || viewport.width <= 0 || viewport.height <= 0) throw new Error('Invalid image or viewport size');
  const scale = Math.min(viewport.width / image.width, viewport.height / image.height) * zoom;
  return { scale, offsetX: (viewport.width - image.width * scale) / 2 + pan.x, offsetY: (viewport.height - image.height * scale) / 2 + pan.y };
}
export const toDisplay = (p: Point, t: ViewTransform): Point => ({ x: p.x * t.scale + t.offsetX, y: p.y * t.scale + t.offsetY });
export const toImage = (p: Point, t: ViewTransform): Point => ({ x: (p.x - t.offsetX) / t.scale, y: (p.y - t.offsetY) / t.scale });
export function displayBox(box: Box, t: ViewTransform): Box {
  return { ...toDisplay(box, t), width: box.width * t.scale, height: box.height * t.scale };
}
function insidePolygon(p: Point, points: Point[]): boolean {
  let inside = false;
  for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
    const a = points[i]!; const b = points[j]!;
    if ((a.y > p.y) !== (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) inside = !inside;
  }
  return inside;
}
function segmentDistance(p: Point, a: Point, b: Point): number {
  const dx = b.x - a.x; const dy = b.y - a.y;
  const ratio = Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy || 1)));
  return Math.hypot(p.x - a.x - ratio * dx, p.y - a.y - ratio * dy);
}
export function hitWord(words: OCRWord[], touch: Point, transform: ViewTransform, tolerance = 8): OCRWord | undefined {
  const p = toImage(touch, transform);
  let best: OCRWord | undefined; let bestDistance = Infinity;
  for (const word of words) {
    const box = word.boundingBox;
    const polygon = word.polygon?.length ? word.polygon : [
      { x: box.x, y: box.y }, { x: box.x + box.width, y: box.y },
      { x: box.x + box.width, y: box.y + box.height }, { x: box.x, y: box.y + box.height },
    ];
    const distance = insidePolygon(p, polygon) ? 0 : Math.min(...polygon.map((a, i) => segmentDistance(p, a, polygon[(i + 1) % polygon.length]!))) * transform.scale;
    // Tolerance is in screen points and never snaps across a distant blank area.
    if (distance <= tolerance && distance < bestDistance) { best = word; bestDistance = distance; }
  }
  return best;
}
