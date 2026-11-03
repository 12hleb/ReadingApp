# Camera light checks

Cover and text photos use the app’s custom live camera preview and still-photo service. Both offer a Light On / Light Off button on cameras with a torch. The light illuminates the preview continuously and remains on during capture. It starts off and turns off when capture completes, the camera closes, Photos opens, the session is interrupted, or the app backgrounds. Retaking a photo starts with the light off. Cameras without a torch omit the button.

Physical iPhone checks:

- Open Add Book → Take Cover Photo. Toggle Light On in dim lighting; confirm the preview brightens immediately. Toggle Off and confirm it darkens.
- Turn the light on and capture a cover; confirm the image is returned and the light switches off.
- Repeat in Start Reading; confirm OCR and text selection work after capture.
- Retake and confirm the light starts off. Toggle it on and choose Photos, leave the reader, or background the app; confirm it switches off.
- Cancel cover capture with the light on; confirm it switches off and the existing cover is preserved.
- Check permission denial and camera unavailability retain cancel, retry/settings, and Photos fallbacks.
- On a camera without a torch, confirm capture works without a light button.

A simulator build verifies compilation only. Actual illumination and hardware interruption behavior require an iPhone.
