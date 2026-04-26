# Products Clean Architecture Demo

A Flutter application that fetches products from the public
[DummyJSON Products API](https://dummyjson.com/products), caches them locally,
and displays them using BLoC with pagination and offline support.

---

## ✨ Features

- Paginated product list (limit = 10)
- Infinite scrolling
- Pull-to-refresh
- Hive-based local caching
- Offline-first behavior with cached data fallback
- Connectivity-aware UI (online/offline indicator + snackbar)
- Auto-sync every 2 minutes (skipped when offline)
- Manual sync via AppBar
- Non-destructive refresh (loaded pages remain visible)
- Handles API errors (empty, failure, unauthorized)
- `401 / 403` → redirects to mock login page

---

## 🧱 Architecture

This project follows **Clean Architecture**:

- core → shared utilities, network, error handling, DI
- domain → entities, repositories, use cases
- data → models, data sources, repository implementations
- presentation → BLoC, UI (screens + widgets)

### State Management

- `flutter_bloc` (BLoC pattern)

### Error Handling

- Functional programming using `Either` from `fpdart`

---

## ⚙️ Tech Stack

- Flutter 3.x
- BLoC (flutter_bloc)
- Hive (local storage)
- Dio (network layer)
- get_it (dependency injection)
- fpdart (functional error handling)
- integration_test + flutter_test (testing)

---

## 💾 Caching & Sync Behavior

- Products are cached locally using Hive
- Pull-to-refresh reloads from page 1
- Manual sync / reconnect / auto-sync:
  - Refresh only already loaded pages
  - Do NOT collapse list back to page 1
- Auto-sync runs every 2 minutes (online only)
- Offline scrolling:
  - Loads next page from cache if available
  - Otherwise shows failure feedback

---

## 🔐 Unauthorized Flow

The `/products` endpoint is public.

To test `401 / 403` behavior:

1. Change endpoint in `AppConstants`:

```
/products to /auth/products
```

2. Run the app

3. App will redirect to **Mock Login Page**

---

## ▶️ Running the App

```bash
flutter pub get
flutter run
```

## 🧪 Running Tests
Run unit and widget test:
```
flutter test
```

Run integration tests on a connected device:
```
flutter test integration_test -d <device_id>
```

You can list available devices using:
```
flutter devices
```

## 📌 Notes

- Hive is used without code generation for simplicity
- The mock login page is intentionally minimal (requirement-focused)
