import { describe, expect, it, vi } from 'vitest';
import { ReaderController } from '../src/core/reader';
import { OCRService, TranslationService, VocabularyStore } from '../src/core/types';
import { image, page } from './fixtures/page';
function setup(ocr: OCRService = { recognize: async () => page }, translator: TranslationService = { translate: async () => 'странно волнующий' }) {
  const save = vi.fn<VocabularyStore['save']>(async input => ({ kind: 'saved', entry: { ...input, id: 'entry', createdAt: 'now', updatedAt: 'now' } }));
  const release = vi.fn();
  const reader = new ReaderController('book-a', ocr, translator, { save }, release);
  return { reader, save, release };
}
describe('reader workflow', () => {
  it('handles permission denial and recovery', () => {
    const { reader } = setup(); reader.permission(false);
    expect(reader.getSnapshot().state).toBe('CAMERA_PERMISSION_DENIED');
    reader.permission(true); expect(reader.getSnapshot().state).toBe('CAMERA_READY');
  });
  it('lets users fully replace Russian text after clearing it', async () => {
    const { reader } = setup(); reader.editOriginal('text'); await reader.translate();
    reader.editTranslation(''); reader.editTranslation('новый перевод');
    expect(reader.getSnapshot().translation).toBe('новый перевод');
  });
  it('restores prior edited entry when selection is cancelled for zoom', async () => {
    const { reader } = setup(); await reader.capture(async () => image); reader.editOriginal('Keep my edits'); await reader.translate();
    reader.select([page.words[0]!.id]); reader.cancelSelection();
    expect(reader.getSnapshot()).toMatchObject({ original: 'Keep my edits', translation: 'странно волнующий', dirty: true, state: 'TRANSLATED' });
  });
  it('keeps manual-entry permission state consistent after clearing', () => {
    const { reader } = setup(); reader.permission(false); reader.editOriginal('word'); reader.editOriginal('');
    expect(reader.getSnapshot().state).toBe('CAMERA_PERMISSION_DENIED');
  });
  it('handles empty OCR without losing the photo or manual entry', async () => {
    const { reader } = setup({ recognize: async () => ({ ...page, words: [] }) });
    await reader.capture(async () => image);
    expect(reader.getSnapshot().error).toBe('No text detected. Try another photo with better lighting.');
    reader.editOriginal('Manual phrase'); await reader.translate();
    expect(reader.getSnapshot().translation).toBeTruthy();
  });
  it('keeps image and offers manual recovery after OCR failure', async () => {
    const { reader } = setup({ recognize: async () => { throw Error('ocr'); } });
    await reader.capture(async () => image);
    expect(reader.getSnapshot().page?.image).toBe(image);
    expect(reader.getSnapshot().error).toContain('Text recognition failed');
  });
  it('invalidates a translation on English edits and uses corrected text', async () => {
    const translate = vi.fn<TranslationService['translate']>(async () => 'перевод');
    const { reader } = setup(undefined, { translate });
    await reader.capture(async () => image); reader.select([page.words[0]!.id], true);
    await reader.translate(); reader.editOriginal('Corrected text');
    expect(reader.getSnapshot().translation).toBe('');
    await reader.translate(); expect(translate.mock.calls.at(-1)?.slice(0, 3)).toEqual(['Corrected text', 'en', 'ru']);
  });
  it('does not translate intermediate gestures', async () => {
    const translate = vi.fn<TranslationService['translate']>(async () => 'текст');
    const { reader } = setup(undefined, { translate }); await reader.capture(async () => image);
    reader.select([page.words[0]!.id]); await reader.translate(); expect(translate).not.toHaveBeenCalled();
    reader.select([page.words[0]!.id], true); await reader.translate(); expect(translate).toHaveBeenCalledOnce();
  });
  it('reports offline failure and retries without discarding English', async () => {
    const translate = vi.fn<TranslationService['translate']>().mockRejectedValueOnce(Error('offline')).mockResolvedValueOnce('текст');
    const { reader } = setup(undefined, { translate }); reader.editOriginal('text'); await reader.translate();
    expect(reader.getSnapshot().state).toBe('TRANSLATION_ERROR'); expect(reader.getSnapshot().original).toBe('text');
    expect(reader.getSnapshot().error).toContain('internet connection'); await reader.translate(); expect(reader.getSnapshot().state).toBe('TRANSLATED');
  });
  it('rejects stale translation results and prevents duplicate requests', async () => {
    let resolve!: (value: string) => void;
    const translate = vi.fn<TranslationService['translate']>(() => new Promise(r => { resolve = r; }));
    const { reader } = setup(undefined, { translate }); reader.editOriginal('old'); const pending = reader.translate();
    await reader.translate(); expect(translate).toHaveBeenCalledOnce(); reader.editOriginal('new'); resolve('старый'); await pending;
    expect(reader.getSnapshot().original).toBe('new'); expect(reader.getSnapshot().translation).toBe('');
  });
  it('saves corrected fields to active book, blocks double taps, and preserves page', async () => {
    const { reader, save, release } = setup(); await reader.capture(async () => image);
    reader.editOriginal('text'); await reader.translate(); reader.editTranslation('текст');
    await Promise.all([reader.save(), reader.save()]); expect(save).toHaveBeenCalledOnce();
    expect(save.mock.calls[0]?.[0]).toMatchObject({ bookId: 'book-a', original: 'text', translation: 'текст', sourceLanguage: 'en', targetLanguage: 'ru' });
    expect(reader.getSnapshot().page?.image).toBe(image); expect(reader.getSnapshot().dirty).toBe(false);
    reader.retake(); expect(release).toHaveBeenCalledWith(image); expect(save).toHaveBeenCalledOnce();
  });
  it('requires explicit duplicate confirmation', async () => {
    const { reader, save } = setup(); save.mockResolvedValueOnce({ kind: 'duplicate' }); reader.editOriginal('text'); await reader.translate(); await reader.save();
    expect(reader.getSnapshot().duplicate).toBe(true); await reader.save(true); expect(save.mock.calls[1]?.[1]).toBe(true);
  });
  it('prevents invalid saves and preserves text after storage error', async () => {
    const { reader, save } = setup(); await reader.save(); expect(save).not.toHaveBeenCalled(); reader.editOriginal('text'); await reader.translate();
    save.mockRejectedValueOnce(Error('disk')); await reader.save(); expect(reader.getSnapshot().state).toBe('SAVE_ERROR'); expect(reader.getSnapshot().original).toBe('text');
    await reader.save(); expect(reader.getSnapshot().notice).toBe('Saved to book.');
  });
  it('releases images from captures completed after leaving', async () => {
    const { reader, release } = setup(); let complete!: (value: typeof image) => void;
    const pending = reader.capture(() => new Promise(r => { complete = r; })); reader.dispose(); complete(image); await pending;
    expect(release).toHaveBeenCalledOnce();
  });
});
