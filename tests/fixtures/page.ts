import { normalizeRecognition } from '../../src/core/ocr';
import { PageImage } from '../../src/core/types';
export const image: PageImage = { uri: 'file:///page.jpg', width: 1200, height: 1800, orientation: 1, sourceWidth: 1200, sourceHeight: 1800 };
// Two lines and a separate paragraph in a printed-page pixel coordinate system.
const lines = [
  [['The', 120, 62], ['experience', 197, 183], ['was', 395, 60], ['strangely', 470, 152], ['exhilarating.', 637, 209]],
  [['She', 120, 58], ["couldn't", 193, 124], ['stop', 332, 68], ['reading.', 415, 126]],
] as const;
export const page = normalizeRecognition(image, { blocks: [{ lines: lines.map((words, li) => ({ elements: words.map(([text, left, width]) => ({ text, frame: { left, top: 180 + li * 52, width, height: 36 } })) })) }, { lines: [{ elements: [{ text: 'Tomorrow', frame: { left: 120, top: 390, width: 155, height: 36 } }] }] }] });
