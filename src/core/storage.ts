import { Book, SaveResult, VocabularyEntry, VocabularyStore } from './types';

export type SQLValue = string | number | null;
export interface SQLDatabase {
  exec(sql: string): void;
  run(sql: string, params: SQLValue[]): void;
  all<T>(sql: string, params: SQLValue[]): T[];
}
export class BookRepository implements VocabularyStore {
  constructor(private db: SQLDatabase, private id: () => string, private now = () => new Date().toISOString()) {
    db.exec(`PRAGMA foreign_keys = ON;
      CREATE TABLE IF NOT EXISTS books (id TEXT PRIMARY KEY, title TEXT NOT NULL, createdAt TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS vocabulary (
        id TEXT PRIMARY KEY, bookId TEXT NOT NULL REFERENCES books(id), original TEXT NOT NULL,
        translation TEXT NOT NULL, sourceLanguage TEXT NOT NULL, targetLanguage TEXT NOT NULL,
        createdAt TEXT NOT NULL, updatedAt TEXT NOT NULL, entryKey TEXT NOT NULL);
      CREATE INDEX IF NOT EXISTS vocabulary_book_key ON vocabulary(bookId, entryKey, sourceLanguage, targetLanguage);`);
  }
  books(): Book[] { return this.db.all<Book>('SELECT * FROM books ORDER BY createdAt DESC, id', []); }
  createBook(title: string): Book {
    if (!title.trim()) throw new Error('A book title is required');
    const book = { id: this.id(), title: title.trim(), createdAt: this.now() };
    this.db.run('INSERT INTO books VALUES (?, ?, ?)', [book.id, book.title, book.createdAt]);
    return book;
  }
  book(id: string): Book | undefined { return this.db.all<Book>('SELECT * FROM books WHERE id = ?', [id])[0]; }
  entries(bookId: string): VocabularyEntry[] { return this.db.all<VocabularyEntry>('SELECT * FROM vocabulary WHERE bookId = ? ORDER BY createdAt DESC, id', [bookId]); }
  async save(input: Omit<VocabularyEntry, 'id' | 'createdAt' | 'updatedAt'>, allowDuplicate = false): Promise<SaveResult> {
    if (!input.original.trim() || !input.translation.trim()) throw new Error('Both fields are required');
    const entryKey = input.original.trim().replace(/\s+/g, ' ').toLowerCase();
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const exists = this.db.all<{ id: string }>('SELECT id FROM vocabulary WHERE bookId = ? AND entryKey = ? AND sourceLanguage = ? AND targetLanguage = ? LIMIT 1', [input.bookId, entryKey, input.sourceLanguage, input.targetLanguage]).length > 0;
      if (exists && !allowDuplicate) { this.db.exec('COMMIT'); return { kind: 'duplicate' }; }
      const timestamp = this.now();
      const entry = { ...input, id: this.id(), original: input.original.trim(), translation: input.translation.trim(), createdAt: timestamp, updatedAt: timestamp };
      this.db.run('INSERT INTO vocabulary VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', [entry.id, entry.bookId, entry.original, entry.translation, entry.sourceLanguage, entry.targetLanguage, timestamp, timestamp, entryKey]);
      this.db.exec('COMMIT');
      return { kind: 'saved', entry };
    } catch (error) { this.db.exec('ROLLBACK'); throw error; }
  }
}
