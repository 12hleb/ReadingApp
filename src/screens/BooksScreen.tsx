import { useCallback, useState } from 'react';
import { Alert, FlatList, Pressable, Text, TextInput, View } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { RootStackParams } from '../navigation';
import { useRepository } from '../services/RepositoryContext';
import { Book } from '../core/types';
import { Action, styles } from '../components/ui';
export function BooksScreen({ navigation }: NativeStackScreenProps<RootStackParams, 'Books'>) {
  const repo = useRepository(); const [books, setBooks] = useState<Book[]>([]); const [title, setTitle] = useState('');
  const [error, setError] = useState('');
  useFocusEffect(useCallback(() => { try { setBooks(repo.books()); setError(''); } catch { setError('Could not load your books. Reopen the app to retry.'); } }, [repo]));
  const add = () => {
    try { const book = repo.createBook(title); setTitle(''); setBooks(repo.books()); navigation.navigate('Album', { bookId: book.id }); }
    catch { Alert.alert('Could not create book', 'Please try again.'); }
  };
  return <SafeAreaView style={styles.screen}>
    <FlatList data={books} keyExtractor={book => book.id} contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled"
      ListHeaderComponent={<View style={{ gap: 14 }}>
        <Text style={styles.subtitle}>YOUR READING COMPANION</Text>
        <Text accessibilityRole="header" style={styles.title}>A book. A new word.</Text>
        <Text style={styles.subtitle}>Photograph an English page, select a phrase, and keep its Russian translation with your book.</Text>
        <TextInput accessibilityLabel="New book title" value={title} onChangeText={setTitle} placeholder="Book title" style={styles.input} returnKeyType="done" onSubmitEditing={() => { if (title.trim()) add(); }} />
        <Action label="Create book album" disabled={!title.trim()} onPress={add} />
        {error ? <Text style={styles.error}>{error}</Text> : null}
        <Text accessibilityRole="header" style={[styles.title, { fontSize: 22, marginTop: 12 }]}>Your books</Text>
      </View>}
      ListEmptyComponent={<Text style={styles.subtitle}>Create your first album to start reading.</Text>}
      renderItem={({ item }) => <Pressable accessibilityRole="button" accessibilityLabel={`Open ${item.title}`} onPress={() => navigation.navigate('Album', { bookId: item.id })} style={[styles.card, { marginTop: 12 }]}>
        <Text style={[styles.text, { fontWeight: '600' }]}>{item.title}</Text><Text style={styles.subtitle}>Open vocabulary →</Text>
      </Pressable>} />
  </SafeAreaView>;
}
