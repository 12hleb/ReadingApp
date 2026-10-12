import { Component, ReactNode, useState } from 'react';
import { Text, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { RootStackParams } from './src/navigation';
import { createRepository } from './src/services/native';
import { RepositoryContext } from './src/services/RepositoryContext';
import { BooksScreen } from './src/screens/BooksScreen';
import { AlbumScreen } from './src/screens/AlbumScreen';
import { ReaderScreen } from './src/screens/ReaderScreen';
import { styles } from './src/components/ui';
const Stack = createNativeStackNavigator<RootStackParams>();
class StartupBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  render() {
    if (this.state.failed) return <View style={[styles.screen, styles.content, { justifyContent: 'center' }]}><Text style={styles.error}>Could not initialize Reading Translator. Reopen the app to retry. This app requires a native development build.</Text></View>;
    return this.props.children;
  }
}
function Navigator() {
  const [repository] = useState(createRepository);
  return <RepositoryContext.Provider value={repository}><NavigationContainer>
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Books" component={BooksScreen} />
      <Stack.Screen name="Album" component={AlbumScreen} />
      <Stack.Screen name="Reader" component={ReaderScreen} />
    </Stack.Navigator>
  </NavigationContainer></RepositoryContext.Provider>;
}
export default function App() {
  return <GestureHandlerRootView style={{ flex: 1 }}><SafeAreaProvider><StartupBoundary><Navigator /></StartupBoundary></SafeAreaProvider></GestureHandlerRootView>;
}
