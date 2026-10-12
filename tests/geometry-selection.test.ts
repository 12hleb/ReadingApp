import { describe, expect, it } from 'vitest';
import { displayBox, hitWord, imageTransform, toDisplay, toImage } from '../src/core/geometry';
import { contiguousSelection, reconstructText, TextSelectionController } from '../src/core/selection';
import { normalizeRecognition } from '../src/core/ocr';
import { image, page } from './fixtures/page';

describe('printed page selection', () => {
  const words = page.words;
  it('selects an actual single word without adjacent text', () => {
    const t = imageTransform(image, { width: 360, height: 640 });
    expect(hitWord(words, toDisplay({ x: 520, y: 198 }, t), t)?.text).toBe('strangely');
  });
  it('selects just the contiguous phrase, preserving punctuation', () => {
    expect(reconstructText(contiguousSelection(words, words[3]!.id, words[4]!.id))).toBe('strangely exhilarating.');
  });
  it('supports reverse and multiline selection in natural order', () => {
    expect(reconstructText(contiguousSelection(words, words[6]!.id, words[3]!.id))).toBe("strangely exhilarating. She couldn't");
  });
  it('leaves endpoint unchanged over distant whitespace', () => {
    const t = imageTransform(image, { width: 360, height: 640 });
    const controller = new TextSelectionController(words);
    controller.begin(words[3]!.id);
    expect(hitWord(words, { x: 350, y: 620 }, t)).toBeUndefined();
    expect(controller.move(undefined).map(w => w.text)).toEqual(['strangely']);
  });
  it.each([1, 2.5])('maps image and touch coordinates at zoom %s with pan and fit offsets', zoom => {
    const t = imageTransform(image, { width: 320, height: 450 }, zoom, { x: 28, y: -57 });
    const point = { x: 500, y: 198 };
    expect(toImage(toDisplay(point, t), t).x).toBeCloseTo(point.x);
    expect(toImage(toDisplay(point, t), t).y).toBeCloseTo(point.y);
    expect(hitWord(words, toDisplay(point, t), t)?.text).toBe('strangely');
    expect(displayBox(words[3]!.boundingBox, t).width).toBeCloseTo(152 * t.scale);
  });
  it('recomputes fitting after device rotation', () => {
    const t = imageTransform(image, { width: 700, height: 320 });
    expect(hitWord(words, toDisplay({ x: 500, y: 198 }, t), t)?.text).toBe('strangely');
  });
  it('preserves apostrophes and ambiguous hyphenated line endings', () => {
    const sample = words.slice(3, 6).map((w, i) => ({ ...w, text: ['well-', 'known', 'story'][i]! }));
    expect(reconstructText(sample)).toBe('well- known story');
  });
  it('keeps engine order across columns and ignores missing geometry', () => {
    const result = normalizeRecognition(image, { blocks: [{ lines: [{ elements: [{ text: 'unlocated' }] }] }] });
    expect(result.words).toEqual([]);
    expect(page.words.at(-1)?.blockId).toBe('b1');
  });
  it('uses polygons rather than enclosing boxes for hit testing', () => {
    const word = { ...words[0]!, boundingBox: { x: 0, y: 0, width: 100, height: 100 }, polygon: [{ x: 50, y: 0 }, { x: 100, y: 50 }, { x: 50, y: 100 }, { x: 0, y: 50 }] };
    expect(hitWord([word], { x: 1, y: 1 }, { scale: 1, offsetX: 0, offsetY: 0 }, 0)).toBeUndefined();
  });
});
