export type Point = { x: number; y: number };
export type Box = Point & { width: number; height: number };
export interface PageImage {
  uri: string;
  width: number;
  height: number;
  orientation: 1; // Pixels are normalized upright before recognition and display.
  sourceOrientation?: number;
  sourceWidth: number;
  sourceHeight: number;
}
export interface OCRWord {
  id: string;
  text: string;
  lineId: string;
  blockId: string;
  readingOrder: number;
  boundingBox: Box;
  polygon?: Point[];
  confidence?: number;
}
export interface OCRResult {
  image: PageImage;
  words: OCRWord[];
  coordinateSpace: 'upright-image-pixels';
  origin: 'top-left';
}
export interface OCRService { recognize(image: PageImage): Promise<OCRResult> }
export interface TranslationService {
  translate(text: string, sourceLanguage: string, targetLanguage: string, signal: AbortSignal): Promise<string>;
}
export interface Book { id: string; title: string; createdAt: string }
export interface VocabularyEntry {
  id: string;
  bookId: string;
  original: string;
  translation: string;
  sourceLanguage: string;
  targetLanguage: string;
  createdAt: string;
  updatedAt: string;
}
export type SaveResult = { kind: 'saved'; entry: VocabularyEntry } | { kind: 'duplicate' };
export interface VocabularyStore {
  save(entry: Omit<VocabularyEntry, 'id' | 'createdAt' | 'updatedAt'>, allowDuplicate?: boolean): Promise<SaveResult>;
}
export type ScreenState = 'CAMERA_READY' | 'CAMERA_PERMISSION_DENIED' | 'CAPTURING' | 'OCR_PROCESSING' |
  'PHOTO_READY' | 'SELECTING' | 'TEXT_SELECTED' | 'TRANSLATING' | 'TRANSLATED' |
  'TRANSLATION_ERROR' | 'SAVING' | 'SAVE_ERROR';
