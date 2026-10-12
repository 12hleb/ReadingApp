import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { ActivityIndicator, Alert, AppState, KeyboardAvoidingView, Linking, Platform, Text, View } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useIsFocused, usePreventRemove } from '@react-navigation/native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { SafeAreaView } from 'react-native-safe-area-context';
import { RootStackParams } from '../navigation';
import { useRepository } from '../services/RepositoryContext';
import { normalizePhoto, ocrService, releaseImage, translationService } from '../services/native';
import { ReaderController } from '../core/reader';
import { CameraPreview } from '../components/CameraPreview';
import { CapturedPageViewer } from '../components/CapturedPageViewer';
import { TranslationPanel } from '../components/TranslationPanel';
import { Action, colors, styles } from '../components/ui';

export function ReaderScreen({ route, navigation }: NativeStackScreenProps<RootStackParams, 'Reader'>) {
  const repo = useRepository();
  const [reader] = useState(() => new ReaderController(route.params.bookId, ocrService, translationService, repo, releaseImage));
  const snapshot = useSyncExternalStore(reader.subscribe, reader.getSnapshot);
  const book = repo.book(route.params.bookId);
  const [permission, requestPermission, getPermission] = useCameraPermissions();
  const cameraRef = useRef<CameraView>(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [cameraError, setCameraError] = useState(false);
  const [flash, setFlash] = useState(false);
  const [foreground, setForeground] = useState(AppState.currentState === 'active');
  const focused = useIsFocused();
  const busy = reader.busy;
  useEffect(() => () => reader.dispose(), [reader]);
  useEffect(() => { if (permission) reader.permission(permission.granted); }, [reader, permission]);
  useEffect(() => {
    const subscription = AppState.addEventListener('change', state => {
      setForeground(state === 'active');
      if (state === 'active') void getPermission();
    });
    return () => subscription.remove();
  }, [getPermission]);
  useEffect(() => { if (!focused || !foreground || snapshot.page) setCameraReady(false); }, [focused, foreground, snapshot.page]);
  usePreventRemove(snapshot.dirty || busy, ({ data }) => {
    if (busy) { Alert.alert('Please wait', 'Finish the current photo or save operation before leaving.'); return; }
    Alert.alert('Discard unsaved entry?', 'Your saved vocabulary will remain in this book.', [
      { text: 'Keep reading', style: 'cancel' },
      { text: 'Discard and leave', style: 'destructive', onPress: () => navigation.dispatch(data.action) },
    ]);
  });
  useEffect(() => {
    if (!snapshot.duplicate) return;
    Alert.alert('Already in this book', 'Save another copy of this phrase?', [
      { text: 'Cancel', style: 'cancel', onPress: () => reader.dismissDuplicate() },
      { text: 'Save another', onPress: () => { void reader.save(true); } },
    ], { cancelable: false });
  }, [reader, snapshot.duplicate]);
  useEffect(() => {
    if (!snapshot.notice) return;
    const timer = setTimeout(() => reader.dismissNotice(), 3000);
    return () => clearTimeout(timer);
  }, [reader, snapshot.notice]);
  const retake = () => {
    const reset = () => { setCameraReady(false); setCameraError(false); reader.retake(); };
    if (snapshot.dirty) Alert.alert('Discard unsaved entry?', 'Retaking clears the current selection and typed edits.', [
      { text: 'Keep photo', style: 'cancel' }, { text: 'Retake', style: 'destructive', onPress: reset },
    ]); else reset();
  };
  const takePhoto = () => { void reader.capture(async () => {
    if (!cameraRef.current || !cameraReady) throw Error('Camera not ready');
    const photo = await cameraRef.current.takePictureAsync({ quality: 1, exif: true, skipProcessing: false });
    return normalizePhoto(photo);
  }); };
  const capture = () => {
    if (snapshot.dirty) Alert.alert('Discard unsaved entry?', 'Capturing a page clears your current typed entry.', [
      { text: 'Keep entry', style: 'cancel' }, { text: 'Capture', style: 'destructive', onPress: takePhoto },
    ]); else takePhoto();
  };
  const askPermission = () => {
    if (permission?.canAskAgain === false) void Linking.openSettings();
    else void requestPermission();
  };
  if (!book) return <SafeAreaView style={styles.screen}><View style={styles.content}><Text style={styles.error}>This book could not be found.</Text><Action label="Back" onPress={() => navigation.goBack()} /></View></SafeAreaView>;
  return <SafeAreaView style={styles.screen}>
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={[styles.row, { padding: 12 }]}>
        <Action label="Back" secondary onPress={() => navigation.goBack()} />
        <Text accessibilityRole="header" numberOfLines={2} style={[styles.text, { flex: 1, fontWeight: '600' }]}>{book.title}</Text>
        <Action label={flash ? 'Flash on' : 'Flash off'} secondary disabled={!!snapshot.page || busy} onPress={() => setFlash(!flash)} />
      </View>
      <View style={{ flex: 1, minHeight: 120, backgroundColor: '#171d19' }}>
        {snapshot.page ? <CapturedPageViewer key={snapshot.page.image.uri} page={snapshot.page} selectedIds={snapshot.selectedIds} enabled={!busy}
          onSelect={(ids, finalized) => reader.select(ids, finalized)} onCancel={() => reader.cancelSelection()} /> : permission?.granted && focused && foreground ?
          <CameraPreview cameraRef={cameraRef} flash={flash} onReady={() => { setCameraReady(true); setCameraError(false); }} onError={() => { setCameraReady(false); setCameraError(true); }} /> :
          <View style={[styles.content, { flex: 1, justifyContent: 'center', alignItems: 'center' }]}>
            <Text style={[styles.text, { color: '#fff', textAlign: 'center' }]}>Camera access lets you photograph a book page. You can also enter a phrase manually below.</Text>
            <Action label={permission?.canAskAgain === false ? 'Open camera settings' : 'Enable camera'} onPress={askPermission} />
          </View>}
        {['CAPTURING', 'OCR_PROCESSING'].includes(snapshot.state) && <View style={{ position: 'absolute', left: 20, right: 20, top: 20, padding: 16, borderRadius: 12, backgroundColor: colors.paper }}>
          <ActivityIndicator color={colors.green} /><Text accessibilityLiveRegion="polite" style={styles.text}>{snapshot.state === 'CAPTURING' ? 'Capturing page…' : 'Recognizing printed words…'}</Text>
        </View>}
      </View>
      {cameraError && <Text accessibilityRole="alert" style={[styles.error, { padding: 12 }]}>Camera could not start. Check permissions or reopen this screen. Manual entry is still available.</Text>}
      <View style={[styles.row, { paddingHorizontal: 12, paddingTop: 8 }]}>
        <Action label={snapshot.page ? 'Retake' : 'Capture page'} disabled={busy || (!snapshot.page && (!cameraReady || !permission?.granted))} onPress={snapshot.page ? retake : capture} />
        <Text style={[styles.subtitle, { flex: 1, fontSize: 13 }]}>{snapshot.page ? 'Drag text to select · Pinch to zoom' : 'Photo Mode · Live Camera coming later'}</Text>
      </View>
      <TranslationPanel reader={reader} snapshot={snapshot} busy={busy} />
    </KeyboardAvoidingView>
  </SafeAreaView>;
}
