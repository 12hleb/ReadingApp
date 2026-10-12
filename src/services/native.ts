import { requireNativeModule } from 'expo-modules-core';
import { ImageManipulator, SaveFormat } from 'expo-image-manipulator';
import { File } from 'expo-file-system';
import { openDatabaseSync } from 'expo-sqlite';
import { randomUUID } from 'expo-crypto';
import { getNetworkStateAsync } from 'expo-network';
import { CameraCapturedPicture } from 'expo-camera';
import { BookRepository } from '../core/storage';
import { NativeRecognition, normalizeRecognition } from '../core/ocr';
import { OCRService, PageImage } from '../core/types';
import { MyMemoryTranslationService } from './translation';

const nativeOCR = requireNativeModule<{ recognize(uri: string): Promise<NativeRecognition> }>('ReadingOCR');
export const ocrService: OCRService = {
  async recognize(image) { return normalizeRecognition(image, await nativeOCR.recognize(image.uri)); },
};
export const translationService = new MyMemoryTranslationService(fetch, async () => {
  const network = await getNetworkStateAsync();
  return network.isConnected !== false && network.isInternetReachable !== false;
});
export function createRepository(): BookRepository {
  const db = openDatabaseSync('reading-translator.db');
  return new BookRepository({
    exec: sql => db.execSync(sql),
    run: (sql, params) => { db.runSync(sql, ...params); },
    all: <T>(sql: string, params: (string | number | null)[]) => db.getAllSync<T>(sql, ...params),
  }, randomUUID);
}
export function releaseImage(image: PageImage): void {
  try { const file = new File(image.uri); if (file.exists) file.delete(); } catch { /* OS cache cleanup may race deletion. */ }
}
export async function normalizePhoto(photo: CameraCapturedPicture): Promise<PageImage> {
  try {
    // A full-resolution decode/re-encode bakes orientation into pixel data.
    // Both OCR and Image use this same upright file, never the EXIF-rotated original.
    const context = ImageManipulator.manipulate(photo.uri);
    let rendered: Awaited<ReturnType<typeof context.renderAsync>> | undefined;
    try {
      rendered = await context.renderAsync();
      const upright = await rendered.saveAsync({ compress: 1, format: SaveFormat.JPEG });
      return { uri: upright.uri, width: upright.width, height: upright.height, orientation: 1,
        sourceWidth: photo.width, sourceHeight: photo.height,
        sourceOrientation: typeof photo.exif?.Orientation === 'number' ? photo.exif.Orientation : undefined };
    } finally { rendered?.release(); context.release(); }
  } finally {
    try { const original = new File(photo.uri); if (original.exists) original.delete(); } catch { /* Best effort cache release. */ }
  }
}
