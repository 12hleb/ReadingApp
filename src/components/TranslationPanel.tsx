import { useState } from 'react';
import { ActivityIndicator, ScrollView, Text, TextInput, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { ReaderController, ReaderSnapshot } from '../core/reader';
import { Action, colors, styles } from './ui';
import { SaveVocabularyAction } from './SaveVocabularyAction';
export function TranslationPanel({ reader, snapshot, busy }: { reader: ReaderController; snapshot: ReaderSnapshot; busy: boolean }) {
  const [expanded, setExpanded] = useState(true);
  const [copyError, setCopyError] = useState('');
  const copy = async (text: string) => { try { await Clipboard.setStringAsync(text); setCopyError(''); } catch { setCopyError('Could not copy text.'); } };
  const selecting = snapshot.state === 'SELECTING';
  return <View style={{ padding: 12, gap: 8, backgroundColor: colors.paper }}>
    <Action label={expanded ? 'Collapse translation panel' : 'Expand translation panel'} secondary onPress={() => setExpanded(!expanded)} />
    {!expanded && <Text numberOfLines={1} style={styles.text}>{snapshot.original || 'Select text or expand for manual entry'}</Text>}
    {expanded && <ScrollView style={{ maxHeight: 280 }} keyboardShouldPersistTaps="handled" contentContainerStyle={{ gap: 10, paddingBottom: 8 }}>
      <Text style={styles.label}>Original English</Text>
      <TextInput accessibilityLabel="Original English" multiline value={snapshot.original} onChangeText={text => reader.editOriginal(text)}
        editable={!busy && !selecting} placeholder="Select words or enter text manually" style={styles.input} />
      <View style={styles.row}>
        <Action label="Copy English" secondary disabled={!snapshot.original} onPress={() => { void copy(snapshot.original); }} />
        <Action label="Clear Selection" secondary disabled={busy || selecting || !snapshot.original} onPress={() => reader.clear()} />
        <Action label={snapshot.state === 'TRANSLATING' ? 'Translating…' : snapshot.state === 'TRANSLATION_ERROR' ? 'Retry Translation' : 'Translate'}
          disabled={busy || selecting || snapshot.state === 'TRANSLATING' || !snapshot.original.trim()} onPress={() => { void reader.translate(); }} />
      </View>
      {snapshot.state === 'TRANSLATING' && <ActivityIndicator accessibilityLabel="Translation in progress" color={colors.green} />}
      <Text style={styles.label}>Russian translation</Text>
      <TextInput accessibilityLabel="Russian translation" multiline value={snapshot.translation} onChangeText={text => reader.editTranslation(text)}
        editable={!busy && !selecting && snapshot.state !== 'TRANSLATING' && snapshot.translationReceived} style={styles.input} placeholder="Your translation will appear here" />
      <View style={styles.row}>
        <Action label="Copy Russian" secondary disabled={!snapshot.translation} onPress={() => { void copy(snapshot.translation); }} />
        <SaveVocabularyAction snapshot={snapshot} onSave={() => { void reader.save(); }} />
      </View>
      <Text style={[styles.subtitle, { fontSize: 12 }]}>Translate sends the English phrase to MyMemory. Page photos stay on your device. Public service limits apply.</Text>
    </ScrollView>}
    {snapshot.error && <Text accessibilityRole="alert" accessibilityLiveRegion="polite" style={styles.error}>{snapshot.error}</Text>}
    {copyError ? <Text style={styles.error}>{copyError}</Text> : null}
    {snapshot.notice && <Text accessibilityLiveRegion="polite" style={{ color: colors.green }}>{snapshot.notice}</Text>}
  </View>;
}
