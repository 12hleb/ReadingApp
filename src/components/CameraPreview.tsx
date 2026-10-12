import { RefObject } from 'react';
import { CameraView } from 'expo-camera';
import { StyleSheet } from 'react-native';
export function CameraPreview({ cameraRef, flash, onReady, onError }: { cameraRef: RefObject<CameraView | null>; flash: boolean; onReady: () => void; onError: () => void }) {
  return <CameraView ref={cameraRef} style={StyleSheet.absoluteFill} facing="back" flash={flash ? 'on' : 'off'} mode="picture"
    onCameraReady={onReady} onMountError={onError} />;
}
