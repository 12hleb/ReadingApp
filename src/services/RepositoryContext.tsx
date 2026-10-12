import { createContext, useContext } from 'react';
import { BookRepository } from '../core/storage';
export const RepositoryContext = createContext<BookRepository | null>(null);
export function useRepository(): BookRepository {
  const repository = useContext(RepositoryContext);
  if (!repository) throw new Error('Book storage is unavailable');
  return repository;
}
