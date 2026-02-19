# HomeSol Authentication System

This document describes the authentication system implemented in the HomeSol Flutter application.

## Overview

The authentication system includes:

- **Splash Screen**: Shows company logo and checks authentication status
- **Login Page**: User authentication with username/password
- **Registration Page**: Multi-step broker registration form
- **Authentication Service**: Handles API calls and token management

## Features

### Splash Screen

- Displays company logo (`assets/logo/logo.png`)
- Animated entrance with fade and scale effects
- Automatically checks if user is logged in
- Redirects to login page or main app based on authentication status

### Login Page

- Clean, modern UI with company branding
- Username and password fields with validation
- Password visibility toggle
- Loading states during authentication
- Error handling with user-friendly messages
- Navigation to registration page

### Registration Page

- **4-Step Stepper Form** for better user experience:

  1. **Basic Info**: Username, email, password, confirm password
  2. **Personal Info**: Lead name, full name, phone number
  3. **Business Info**: RERA number, address
  4. **Profile Image**: Optional profile photo upload

- Form validation at each step
- Image picker for profile photos
- Progressive disclosure of information
- Smooth navigation between steps

### Authentication Service

- **Base URL**: `http://localhost:8000`
- **Endpoints**:
  - `POST /api/v1/broker/register` - Register new broker
  - `POST /api/v1/broker/login` - Login broker
- JWT token storage using SharedPreferences
- User data persistence
- Error handling and network error management

## API Integration

### Registration Payload

```json
{
  "username": "john_broker21",
  "email": "john@broker.com",
  "password": "securepass123",
  "lead_name": "John Broker",
  "name": "John Doe",
  "address": "123 Broker Street, Mumbai, Maharashtra",
  "phone_no": "+91-9876543110",
  "rera_number": "MahaRERA/B12345",
  "profile_image": "https://example.com/profile.jpg"
}
```

### Login Payload

```json
{
  "username": "john_broker21",
  "password": "securepass123"
}
```

## Dependencies

The following packages have been added to `pubspec.yaml`:

- `http: ^1.1.0` - For API calls
- `shared_preferences: ^2.2.2` - For token storage
- `image_picker: ^1.0.4` - For profile image selection

## File Structure

```
lib/
├── services/
│   └── auth_service.dart          # Authentication API service
├── pages/
│   ├── splash_screen.dart         # App entry point
│   └── auth/
│       ├── login_page.dart        # Login form
│       └── register_page.dart     # Registration stepper
└── main.dart                      # App configuration
```

## Usage

1. **App Launch**: App starts with splash screen
2. **Authentication Check**: Automatically checks for existing login
3. **Login Flow**: Users can sign in with credentials
4. **Registration Flow**: New users can create accounts step-by-step
5. **Token Management**: JWT tokens are automatically stored and managed

## Security Features

- Password validation (minimum 6 characters)
- Email format validation
- Secure token storage
- Form validation at each step
- Error handling without exposing sensitive information

## UI/UX Features

- Dark theme with orange accent color (`#FF6A2E`)
- Smooth animations and transitions
- Responsive design
- Loading states and progress indicators
- User-friendly error messages
- Intuitive stepper navigation

## Future Enhancements

- Password strength indicator
- Biometric authentication
- Two-factor authentication
- Password reset functionality
- Social login integration
- Offline authentication support
