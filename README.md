# doorunlockersmartkeyapp

A new Flutter project.

## Getting Started

# 🏗️ Construction Site Smart Key Scheduler

A Flutter web application for managing construction site access schedules with Bluetooth connectivity to ESP32 smart keys.

## 🌐 Live Demo
**[Visit the App](https://[your-username].github.io/door-unlocker-web-app/)**

## ✨ Features

- **📅 7-Day Schedule Management** - Set start/end times for construction site access
- **🔵 Bluetooth Connectivity** - Send updates to ESP32 smart keys via Web Bluetooth
- **🔐 Email 2FA Authentication** - Secure admin access with email verification
- **☁️ Google Sheets Integration** - Real-time data sync and backup
- **🏗️ Construction Context** - 12-tower site management
- **📱 Responsive Design** - Works on desktop and mobile devices

## 🚀 Quick Start

### For Testers:
1. **Visit the live app** (link above)
2. **Test Bluetooth** - Click the Bluetooth icon (no login required)
3. **Login for editing** - Use the login button with password: `tigerskydiveabout`

### For Developers:
```bash
git clone [repository-url]
cd doorunlockersmartkeyapp
flutter pub get
flutter run -d chrome
```

## 🔧 Technology Stack

- **Flutter 3.24.0** - Cross-platform framework
- **Web Bluetooth API** - ESP32 communication
- **Google Sheets API** - Data storage
- **EmailJS** - Authentication emails
- **GitHub Pages** - Hosting

## 📡 ESP32 Integration

The app communicates with ESP32 devices via Bluetooth Low Energy (BLE):
- Automatic device discovery
- Send schedule updates
- Test message functionality
- Connection status monitoring

## 🏗️ Construction Site Features

- **12 Tower Management** - Individual or whole property scheduling
- **Hour-based Times** - 6 AM to 11 PM operational hours
- **Auto-save** - Changes sync to Google Sheets immediately
- **Admin Controls** - Secure access for schedule modifications

## 🔒 Security

- Email-based 2FA authentication
- Admin-only editing permissions
- Secure Google Sheets integration
- No sensitive data stored locally

## 📞 Support

For issues or questions, contact the development team.

---
*Built for modern construction site management with IoT integration*
