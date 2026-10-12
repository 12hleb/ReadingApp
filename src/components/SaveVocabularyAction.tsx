import { ReaderSnapshot } from '../core/reader';
import { Action } from './ui';
export function SaveVocabularyAction({ snapshot, onSave }: { snapshot: ReaderSnapshot; onSave: () => void }) {
  if (!snapshot.translation.trim()) return null;
  return <Action label={snapshot.state === 'SAVING' ? 'Saving…' : snapshot.dirty ? 'Save to Book' : 'Saved to Book'} onPress={onSave}
    disabled={!snapshot.dirty || !['TRANSLATED', 'SAVE_ERROR'].includes(snapshot.state) || !snapshot.original.trim()} />;
}
