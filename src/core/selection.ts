import { OCRWord } from './types';

export function contiguousSelection(words: OCRWord[], anchorId: string, endpointId: string): OCRWord[] {
  const ordered = [...words].sort((a, b) => a.readingOrder - b.readingOrder);
  const a = ordered.findIndex(word => word.id === anchorId);
  const b = ordered.findIndex(word => word.id === endpointId);
  return a < 0 || b < 0 ? [] : ordered.slice(Math.min(a, b), Math.max(a, b) + 1);
}
export function reconstructText(words: OCRWord[]): string {
  let result = '';
  const ordered = [...words].sort((a, b) => a.readingOrder - b.readingOrder);
  ordered.forEach((word, index) => {
    const previous = ordered[index - 1];
    // Keep ambiguous line-ending hyphens: removing one could change a compound.
    // Join only an explicit soft hyphen at a wrap, in the same block.
    if (previous && previous.blockId === word.blockId && previous.lineId !== word.lineId && result.endsWith('\u00ad')) {
      result = result.slice(0, -1) + word.text;
    } else if (!result || /^[,.;:!?%)\]}]/.test(word.text) || /[(\[{“]$/.test(result) || /^['’]/.test(word.text)) {
      result += word.text;
    } else result += ' ' + word.text;
  });
  return result;
}
export class TextSelectionController {
  private anchor?: string;
  private endpoint?: string;
  constructor(private readonly words: OCRWord[]) {}
  begin(wordId: string): OCRWord[] { this.anchor = wordId; this.endpoint = wordId; return this.current(); }
  move(wordId?: string): OCRWord[] { if (this.anchor && wordId) this.endpoint = wordId; return this.current(); }
  current(): OCRWord[] { return this.anchor && this.endpoint ? contiguousSelection(this.words, this.anchor, this.endpoint) : []; }
  clear(): void { this.anchor = undefined; this.endpoint = undefined; }
}
