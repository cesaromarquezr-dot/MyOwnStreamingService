# Home navigation fix

The app-wide Home navigation control now replaces the root Navigator stack with a fresh `MainScreen` route named `/main/home`.

This avoids relying on a cached `_MainScreenState` reference or on finding an existing `/main/...` route underneath Login/Signup. Route-stack changes are deferred until the current frame has completed to avoid `setState() or markNeedsBuild() called during build`.

After extracting the project, run:

```powershell
flutter pub get
flutter analyze
flutter run
```

Then open Login and Signup and use the global Home navigation control. The Home action should return to a fresh main Home screen.

Flutter/Dart analysis was not run when this archive was prepared because Flutter and Dart are not installed in the packaging environment.
