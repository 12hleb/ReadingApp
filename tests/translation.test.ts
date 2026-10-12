import { expect, it, vi } from 'vitest';
import { MyMemoryTranslationService } from '../src/services/translation';
it('sends only selected text and language codes, accepts real provider response', async () => {
  const request = vi.fn<typeof fetch>(async () => new Response(JSON.stringify({ responseStatus: 200, responseData: { translatedText: 'книга' } })));
  expect(await new MyMemoryTranslationService(request).translate('book', 'en', 'ru', new AbortController().signal)).toBe('книга');
  const url = new URL(String(request.mock.calls[0]?.[0])); expect(url.searchParams.get('q')).toBe('book'); expect(url.searchParams.get('langpair')).toBe('en|ru');
});
it.each([new Response('{}'), new Response('{"responseStatus":429}'), new Response('failure', { status: 503 })])('rejects failed provider responses', async response => {
  const provider = new MyMemoryTranslationService(async () => response);
  await expect(provider.translate('book', 'en', 'ru', new AbortController().signal)).rejects.toThrow();
});
it('detects unavailable internet without making a request', async () => {
  const request = vi.fn<typeof fetch>(); const provider = new MyMemoryTranslationService(request, async () => false);
  await expect(provider.translate('book', 'en', 'ru', new AbortController().signal)).rejects.toThrow('offline'); expect(request).not.toHaveBeenCalled();
});
