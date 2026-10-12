import { OCRResult, OCRService, PageImage, ScreenState, TranslationService, VocabularyStore } from './types';
import { reconstructText } from './selection';

export interface ReaderSnapshot {
  state: ScreenState;
  bookId: string;
  page?: OCRResult;
  selectedIds: string[];
  original: string;
  translation: string;
  dirty: boolean;
  error?: string;
  notice?: string;
  duplicate: boolean;
  translationReceived: boolean;
}
export class ReaderController {
  private snapshot: ReaderSnapshot;
  private listeners = new Set<() => void>();
  private generation = 0;
  private translationAbort?: AbortController;
  private disposed = false;
  private cameraGranted = true;
  private selectionBaseline?: ReaderSnapshot;
  constructor(bookId: string, private ocr: OCRService, private translator: TranslationService, private store: VocabularyStore, private releaseImage: (image: PageImage) => void = () => {}) {
    this.snapshot = { state: 'CAMERA_READY', bookId, selectedIds: [], original: '', translation: '', dirty: false, duplicate: false, translationReceived: false };
  }
  getSnapshot = (): ReaderSnapshot => this.snapshot;
  subscribe = (listener: () => void) => { this.listeners.add(listener); return () => { this.listeners.delete(listener); }; };
  private update(patch: Partial<ReaderSnapshot>) { if (!this.disposed) { this.snapshot = { ...this.snapshot, ...patch }; this.listeners.forEach(listener => listener()); } }
  private invalidate() { this.generation++; this.translationAbort?.abort(); this.translationAbort = undefined; }
  get busy() { return ['CAPTURING', 'OCR_PROCESSING', 'SAVING'].includes(this.snapshot.state); }
  permission(granted: boolean) { this.cameraGranted = granted; if (!this.snapshot.page && !this.snapshot.original && !this.busy) this.update({ state: granted ? 'CAMERA_READY' : 'CAMERA_PERMISSION_DENIED' }); }
  async capture(takePhoto: () => Promise<PageImage>) {
    if (this.busy || this.snapshot.page) return;
    this.invalidate(); const generation = this.generation;
    this.update({ state: 'CAPTURING', original: '', translation: '', translationReceived: false, selectedIds: [], dirty: false, duplicate: false, error: undefined, notice: undefined });
    let image: PageImage | undefined;
    try {
      image = await takePhoto();
      if (this.disposed || generation !== this.generation) { this.releaseImage(image); return; }
      this.update({ state: 'OCR_PROCESSING', page: { image, words: [], coordinateSpace: 'upright-image-pixels', origin: 'top-left' } });
      const page = await this.ocr.recognize(image);
      if (this.disposed || generation !== this.generation) return;
      this.update({ state: 'PHOTO_READY', page, error: page.words.length ? undefined : 'No text detected. Try another photo with better lighting.' });
    } catch {
      if (this.disposed || generation !== this.generation) return;
      this.update({ state: image ? 'PHOTO_READY' : 'CAMERA_READY', error: image ? 'Text recognition failed. Retake the photo or enter text manually.' : 'Could not capture a photo. Please try again.' });
    }
  }
  select(ids: string[], finalized = false) {
    if (this.busy || !this.snapshot.page) return;
    if (!finalized && this.snapshot.state !== 'SELECTING') this.selectionBaseline = this.snapshot;
    this.invalidate();
    const words = this.snapshot.page.words.filter(word => ids.includes(word.id));
    this.update({ state: finalized ? (words.length ? 'TEXT_SELECTED' : 'PHOTO_READY') : 'SELECTING', selectedIds: words.map(word => word.id), original: reconstructText(words), translation: '', translationReceived: false, dirty: words.length > 0, error: undefined, notice: undefined, duplicate: false });
    if (finalized) this.selectionBaseline = undefined;
  }
  cancelSelection() {
    if (this.selectionBaseline) { const baseline = this.selectionBaseline; this.selectionBaseline = undefined; this.invalidate(); this.update({ ...baseline, state: baseline.translation ? 'TRANSLATED' : baseline.original ? 'TEXT_SELECTED' : 'PHOTO_READY' }); }
  }
  editOriginal(original: string) {
    if (this.busy || this.snapshot.state === 'SELECTING') return;
    this.invalidate();
    this.update({ original, translation: '', translationReceived: false, selectedIds: [], state: original.trim() ? 'TEXT_SELECTED' : this.snapshot.page ? 'PHOTO_READY' : this.cameraGranted ? 'CAMERA_READY' : 'CAMERA_PERMISSION_DENIED', dirty: !!original.trim(), error: undefined, notice: undefined, duplicate: false });
  }
  editTranslation(translation: string) {
    if (this.busy || this.snapshot.state === 'TRANSLATING' || this.snapshot.state === 'SELECTING') return;
    // Only edit a provider result; manual translation never fabricates provider success.
    if (!this.snapshot.translationReceived) return;
    this.update({ translation, state: translation.trim() ? 'TRANSLATED' : 'TEXT_SELECTED', dirty: true, notice: undefined, duplicate: false });
  }
  clear() {
    if (this.busy) return;
    this.invalidate(); this.selectionBaseline = undefined;
    this.update({ selectedIds: [], original: '', translation: '', translationReceived: false, state: this.snapshot.page ? 'PHOTO_READY' : this.cameraGranted ? 'CAMERA_READY' : 'CAMERA_PERMISSION_DENIED', dirty: false, error: undefined, notice: undefined, duplicate: false });
  }
  retake() {
    if (this.busy) return;
    const image = this.snapshot.page?.image;
    this.clear(); this.update({ page: undefined, state: this.cameraGranted ? 'CAMERA_READY' : 'CAMERA_PERMISSION_DENIED' });
    if (image) this.releaseImage(image);
  }
  async translate() {
    const text = this.snapshot.original.trim();
    if (!text || this.busy || ['TRANSLATING', 'SELECTING'].includes(this.snapshot.state)) return;
    this.invalidate(); const generation = this.generation; const abort = new AbortController(); this.translationAbort = abort;
    this.update({ state: 'TRANSLATING', translation: '', translationReceived: false, error: undefined, notice: undefined, duplicate: false });
    try {
      const translation = await this.translator.translate(text, 'en', 'ru', abort.signal);
      if (this.disposed || generation !== this.generation) return;
      if (!translation.trim()) throw new Error('Empty translation');
      this.update({ state: 'TRANSLATED', translation, translationReceived: true, dirty: true });
    } catch (error) {
      if (this.disposed || generation !== this.generation) return;
      this.update({ state: 'TRANSLATION_ERROR', error: error instanceof Error && error.message === 'offline' ? 'Translation requires an internet connection. Your selected text is still available.' : 'Translation failed. Please try again.' });
    } finally { if (generation === this.generation) this.translationAbort = undefined; }
  }
  async save(allowDuplicate = false) {
    const { original, translation, bookId, state } = this.snapshot;
    if (this.busy || !['TRANSLATED', 'SAVE_ERROR'].includes(state) || !original.trim() || !translation.trim() || !this.snapshot.dirty) return;
    this.update({ state: 'SAVING', error: undefined, notice: undefined, duplicate: false });
    try {
      const result = await this.store.save({ bookId, original: original.trim(), translation: translation.trim(), sourceLanguage: 'en', targetLanguage: 'ru' }, allowDuplicate);
      this.update(result.kind === 'duplicate' ? { state: 'TRANSLATED', duplicate: true } : { state: 'TRANSLATED', dirty: false, duplicate: false, notice: 'Saved to book.' });
    } catch { this.update({ state: 'SAVE_ERROR', error: 'Could not save this entry. Please try again.' }); }
  }
  dismissNotice() { this.update({ notice: undefined }); }
  dismissDuplicate() { this.update({ duplicate: false }); }
  dispose() { this.disposed = true; this.invalidate(); if (this.snapshot.page) this.releaseImage(this.snapshot.page.image); this.listeners.clear(); }
}
