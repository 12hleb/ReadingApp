import { Pressable, StyleSheet, Text } from 'react-native';
export const colors = { ink: '#202a26', muted: '#5d6962', paper: '#faf8f2', border: '#dcded5', green: '#285642', orange: '#e97822', error: '#9d2828' };
export function Action({ label, onPress, disabled = false, secondary = false }: { label: string; onPress: () => void; disabled?: boolean; secondary?: boolean }) {
  return <Pressable accessibilityRole="button" accessibilityLabel={label} accessibilityState={{ disabled }} disabled={disabled} onPress={onPress}
    style={({ pressed }) => [styles.button, secondary && styles.secondary, (disabled || pressed) && { opacity: 0.5 }]}>
    <Text style={[styles.buttonText, secondary && { color: colors.ink }]}>{label}</Text>
  </Pressable>;
}
export const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.paper },
  content: { padding: 20, gap: 16 },
  title: { fontSize: 28, fontWeight: '700', color: colors.ink },
  subtitle: { fontSize: 16, color: colors.muted, lineHeight: 24 },
  label: { fontSize: 14, fontWeight: '600', color: colors.ink },
  text: { color: colors.ink, fontSize: 17, lineHeight: 25 },
  input: { borderWidth: 1, borderColor: colors.border, borderRadius: 12, padding: 12, color: colors.ink, backgroundColor: '#fff', fontSize: 17, minHeight: 48 },
  row: { flexDirection: 'row', gap: 8, alignItems: 'center', flexWrap: 'wrap' },
  card: { backgroundColor: '#fff', padding: 18, gap: 8, borderRadius: 16, borderWidth: 1, borderColor: colors.border },
  button: { minHeight: 48, paddingHorizontal: 16, paddingVertical: 12, borderRadius: 12, backgroundColor: colors.green, alignItems: 'center', justifyContent: 'center' },
  secondary: { backgroundColor: '#eeeee6' },
  buttonText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  error: { color: colors.error, fontSize: 16 },
});
