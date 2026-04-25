# Flutter Frontend (Web + Mobile)

This app targets Android (emulator) and Web using a single codebase.

## Run

```powershell
cd frontend_flutter
flutter pub get
flutter run -d chrome
```

For Android emulator:

```powershell
flutter devices
flutter run -d <android-device-id>
```

Default backend URL is `http://127.0.0.1:9000/api`.
Update it in `lib/services/api_service.dart` if needed.

## JWT (Django REST)

The app now authenticates with Django REST JWT (`/api/auth/token/`) before calling protected prediction endpoints.

The UI includes:

- standard login (username/password)
- immediate development login (demo) via `/api/auth/dev-quick-login/`
- dashboard cards (model status, success rate, volume, accuracy)
- recent prediction history

Backend quick setup:

```powershell
cd backend
python manage.py createsuperuser
python manage.py runserver 0.0.0.0:9000
```

Then use the same username/password in the Flutter login section.

For immediate access in development, use the "Connexion demo immediate" button in the app.
