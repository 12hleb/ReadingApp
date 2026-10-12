import { Box, OCRResult, PageImage, Point } from './types';
export interface NativeRecognition {
  blocks: { lines: { elements: { text: string; confidence?: number; frame?: { left: number; top: number; width: number; height: number }; cornerPoints?: readonly Point[] }[] }[] }[];
}
// Retain ML Kit's document reading order rather than globally sorting by x/y,
// which interleaves columns. No invented equal-width word boxes.
export function normalizeRecognition(image: PageImage, result: NativeRecognition): OCRResult {
  const words: OCRResult['words'] = [];
  result.blocks.forEach((block, bi) => block.lines.forEach((line, li) => line.elements.forEach((element, wi) => {
    const polygon = element.cornerPoints?.map(p => ({ ...p }));
    let box: Box | undefined = element.frame ? { x: element.frame.left, y: element.frame.top, width: element.frame.width, height: element.frame.height } : undefined;
    if (!box && polygon?.length) {
      const x = Math.min(...polygon.map(p => p.x)); const y = Math.min(...polygon.map(p => p.y));
      box = { x, y, width: Math.max(...polygon.map(p => p.x)) - x, height: Math.max(...polygon.map(p => p.y)) - y };
    }
    if (!element.text.trim() || !box || !Object.values(box).every(Number.isFinite) || box.width <= 0 || box.height <= 0) return;
    words.push({ id: `b${bi}-l${li}-w${wi}`, blockId: `b${bi}`, lineId: `b${bi}-l${li}`, readingOrder: words.length, text: element.text, confidence: element.confidence, boundingBox: box, polygon: polygon?.every(p => Number.isFinite(p.x) && Number.isFinite(p.y)) ? polygon : undefined });
  })));
  return { image, words, coordinateSpace: 'upright-image-pixels', origin: 'top-left' };
}
