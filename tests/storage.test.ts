import { DatabaseSync } from 'node:sqlite';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { expect, it } from 'vitest';
import { BookRepository, SQLDatabase } from '../src/core/storage';
const adapt = (db: DatabaseSync): SQLDatabase => ({ exec: sql => db.exec(sql), run: (sql, params) => { db.prepare(sql).run(...params); }, all: <T>(sql: string, params: (string | number | null)[]) => db.prepare(sql).all(...params) as T[] });
it('persists books and entries after reopening SQLite and isolates albums and duplicates', async () => {
  const folder = mkdtempSync(join(tmpdir(), 'reading-')); const path = join(folder, 'test.db');
  let db = new DatabaseSync(path); let sequence = 0; const id = () => `id-${++sequence}`;
  try {
    let repo = new BookRepository(adapt(db), id); const first = repo.createBook('First'); const second = repo.createBook('Second');
    const input = { bookId: first.id, original: 'strangely exhilarating', translation: 'странно волнующий', sourceLanguage: 'en', targetLanguage: 'ru' };
    expect((await repo.save(input)).kind).toBe('saved');
    expect((await repo.save({ ...input, original: ' Strangely   exhilarating ' })).kind).toBe('duplicate');
    expect((await repo.save(input, true)).kind).toBe('saved');
    expect((await repo.save({ ...input, bookId: second.id })).kind).toBe('saved');
    await expect(repo.save({ ...input, bookId: 'missing' })).rejects.toThrow();
    db.close(); db = new DatabaseSync(path); repo = new BookRepository(adapt(db), id);
    expect(repo.books()).toHaveLength(2); expect(repo.entries(first.id)).toHaveLength(2); expect(repo.entries(second.id)).toHaveLength(1);
    expect(repo.entries(first.id)[0]).toMatchObject({ original: input.original, translation: input.translation, sourceLanguage: 'en', targetLanguage: 'ru' });
    expect(repo.entries(first.id)[0]?.createdAt).toBeTruthy();
  } finally { db.close(); rmSync(folder, { recursive: true }); }
});
