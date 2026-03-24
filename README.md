# Transvolt Frontend

Flutter frontend application for the **Transvolt platform**.

---

## Tech Stack

| Tool     | Version |
| -------- | ------- |
| Flutter  | 3.41.3  |
| Dart     | 3.11.1  |
| DevTools | 2.54.1  |

---

## Prerequisites

Make sure the following tools are installed:

- Flutter SDK **3.41.3**
- Dart **3.11.1**
- Android Studio / VS Code
- Chrome (for web testing)
- Android/iOS device or emulator

Verify installation:

```bash
flutter doctor -v
Project Setup
1. Clone Repository
git clone <repository-url>
cd transvolt_frontend
2. Install Dependencies

From the project root directory, run:

flutter pub get

This command downloads all required dependencies.

3. Configure Environment

Create the .env.development and .env.production file from .env.example and configure the backend API URL.
Keep .env.production file as API_URL= do not put any URL as this is not live yet

Example:

BACKEND_URL=https://your-backend-domain.com
Running the Application
List Available Devices
flutter devices

This command shows all available devices (mobile, emulator, web).

Run on Mobile Device
flutter run -d <device_name>

Example:

flutter run -d android
Run on Web Browser
flutter run

This will launch the application in a web browser.
```
