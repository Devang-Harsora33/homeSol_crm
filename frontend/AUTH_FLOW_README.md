# HomeSol Authentication Flow

## Overview

The app now implements a **home-first authentication flow** where:

1. **App starts with the home page** (no authentication required)
2. **Protected pages require authentication** (CRM, Projects, Passbook, More)
3. **Users are redirected to login** when accessing protected pages without authentication
4. **After successful login, users can access all pages**

## How It Works

### 1. App Launch

- App starts directly with `MainNavigation`
- Home page is accessible without authentication
- Other pages are wrapped with `AuthWrapper`

### 2. Navigation Flow

```
Home Page (No Auth) ←→ Protected Pages (Auth Required)
     ↓
Login Page (if not authenticated)
     ↓
Back to requested page after successful login
```

### 3. Authentication Wrapper

The `AuthWrapper` component:

- Checks authentication status when a protected page is accessed
- Shows loading indicator while checking
- Redirects to login page if not authenticated
- Allows access to the wrapped page if authenticated

### 4. Protected Pages

The following pages require authentication:

- **CRM Page** (`/crm`)
- **Projects Page** (`/projects`)
- **Passbook Page** (`/passbook`)
- **More Page** (`/more`)

### 5. Logout Functionality

- **Home Page**: Logout button in header (next to help icon)
- **Protected Pages**: Logout button in app bar and as a button
- Logout clears authentication tokens
- Returns user to home page

## File Structure

```
lib/
├── components/
│   └── auth_wrapper.dart          # Authentication guard component
├── services/
│   └── auth_service.dart          # Authentication API service
├── pages/
│   ├── home_page.dart             # Home page (no auth required)
│   ├── auth/
│   │   ├── login_page.dart        # Login form
│   │   └── register_page.dart     # Registration stepper
│   └── [other pages]              # Protected pages
└── main_navigation.dart           # Main navigation with auth wrappers
```

## Key Components

### AuthWrapper

```dart
const AuthWrapper(
  child: CRMPage(),        // Page to protect
  requireAuth: true,       // Default: true
)
```

### Main Navigation

```dart
final List<Widget> _pages = [
  const HomePage(),                    // No auth required
  const AuthWrapper(child: CRMPage()), // Auth required
  const AuthWrapper(child: ProjectsPage()), // Auth required
  // ... other protected pages
];
```

## User Experience

1. **New Users**: Can browse home page without login
2. **Existing Users**: Can access home page immediately
3. **Protected Access**: When tapping on CRM, Projects, etc., users are prompted to login
4. **Seamless Navigation**: After login, users return to the page they were trying to access
5. **Easy Logout**: Logout button available on all pages

## Benefits

- **Better UX**: Users can see the app content immediately
- **Progressive Disclosure**: Authentication only when needed
- **Flexible Access**: Home page serves as a landing page
- **Secure Navigation**: Protected features require proper authentication
- **Clear Flow**: Users understand when and why they need to login

## Future Enhancements

- **Guest Mode**: Allow limited access to some protected features
- **Remember Me**: Option to stay logged in
- **Biometric Auth**: Fingerprint/face recognition for quick access
- **Offline Mode**: Cache some content for offline viewing
