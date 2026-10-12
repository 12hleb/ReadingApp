import { TranslationService } from '../core/types';

// Public MyMemory endpoint; selected text only, never the page image.
// No embedded credentials. Public quota/quality are provider controlled.
export class MyMemoryTranslationService implements TranslationService {
  constructor(private request: typeof fetch = fetch, private online: () => Promise<boolean> = async () => true) {}
  async translate(text: string, sourceLanguage: string, targetLanguage: string, signal: AbortSignal): Promise<string> {
    if (!await this.online()) throw new Error('offline');
    if (Array.from(text).reduce((bytes, character) => { const code = character.codePointAt(0)!; return bytes + (code < 128 ? 1 : code < 2048 ? 2 : code < 65536 ? 3 : 4); }, 0) > 500) throw new Error('Provider limit: 500 UTF-8 bytes');
    const abort = new AbortController();
    const cancel = () => abort.abort();
    signal.addEventListener('abort', cancel);
    if (signal.aborted) abort.abort();
    const timer = setTimeout(() => abort.abort(), 15000);
    try {
      const response = await this.request(`https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${encodeURIComponent(`${sourceLanguage}|${targetLanguage}`)}`, { signal: abort.signal });
      if (!response.ok) throw new Error('Provider failed');
      const data: unknown = await response.json();
      if (!data || typeof data !== 'object') throw new Error('Invalid provider response');
      const result = data as { responseStatus?: number; responseData?: { translatedText?: string }; quotaFinished?: boolean };
      if (result.responseStatus !== 200 || result.quotaFinished || typeof result.responseData?.translatedText !== 'string' || !result.responseData.translatedText.trim()) throw new Error('Provider failed');
      return result.responseData.translatedText;
    } catch (error) {
      if (!signal.aborted && (!await this.online() || (error instanceof TypeError && /network request failed|failed to fetch/i.test(error.message)))) throw new Error('offline');
      throw error;
    } finally { clearTimeout(timer); signal.removeEventListener('abort', cancel); }
  }
}
