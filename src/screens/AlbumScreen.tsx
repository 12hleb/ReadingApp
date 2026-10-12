import { useCallback, useState } from 'react';
import { FlatList, Text, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { RootStackParams } from '../navigation';
import { useRepository } from '../services/RepositoryContext';
import { VocabularyEntry } from '../core/types';
import { Action, styles } from '../components/ui';
export function AlbumScreen({ navigation, route }: NativeStackScreenProps<RootStackParams, 'Album'>) {
  const repo = useRepository(); const [entries, setEntries] = useState<VocabularyEntry[]>([]);
  const [title, setTitle] = useState('Book'); const [error, setError] = useState(''); const [valid, setValid] = useState(false);
  const { bookId } = route.params;
  useFocusEffect(useCallback(() => {
    try {
      const book = repo.book(bookId);
      if (!book) throw Error('Missing book');
      setTitle(book.title); setEntries(repo.entries(bookId)); setValid(true); setError('');
    } catch { setError('Could not open this book. Return to your books and try again.'); setValid(false); }
  }, [repo, bookId]));
  return <SafeAreaView style={styles.screen}>
    <FlatList data={entries} keyExtractor={entry => entry.id} contentContainerStyle={styles.content}
      ListHeaderComponent={<View style={{ gap: 14 }}>
        <Action label="Back to books" secondary onPress={() => navigation.goBack()} />
        <Text accessibilityRole="header" style={styles.title}>{title}</Text>
        <Text style={styles.subtitle}>{entries.length} saved {entries.length === 1 ? 'phrase' : 'phrases'} · English → Russian</Text>
        <Action label="Read with camera" disabled={!valid} onPress={() => navigation.navigate('Reader', { bookId })} />
        {error ? <Text style={styles.error}>{error}</Text> : null}
      </View>}
      ListEmptyComponent={<Text style={[styles.subtitle, { marginTop: 20 }]}>Your saved vocabulary will appear here.</Text>}
      renderItem={({ item }) => <View style={[styles.card, { marginTop: 12 }]}>
        <Text selectable style={[styles.text, { fontWeight: '600' }]}>{item.original}</Text>
        <Text selectable style={styles.text}>{item.translation}</Text>
        <Text style={[styles.subtitle, { fontSize: 12 }]}>{new Date(item.createdAt).toLocaleDateString()}</Text>
      </View>} />
  </SafeAreaView>;
}
