# 💜 WeSafe - You Deserve to be Safe!

WeSafe is a next-generation, premium safety application designed to offer robust protection, continuous real-time monitoring, and instant community response systems. Built with a modern, glassmorphic design language, WeSafe empowers users to dynamically broadcast emergency alerts, find local support resources, connect with regional safety networks, and trigger alarms.

---

## 📱 Visual Showcase & Design Philosophy
WeSafe is designed using a premium, minimal, dark-mode inspired blush-lavender color palette featuring:
- **Primary Deep Violet** (`#3A004D`), **Lavender Pink** (`#8B1A4A`), and **Muted Blush Lavender** (`#D4B8D0`) for a modern, high-end look.
- **Glassmorphism** layouts with blurred backdrops (`BackdropFilter`) and glowing gradients.
- Micro-animations for high-fidelity interactive elements.
- Responsive, premium navigation bars and action-oriented layouts.

---

## 🚀 Key Features

### 👥 WeSafe Community Safety Network (New)
A real-time group chat system connecting verified users within specific regions (cities, campuses, or areas):
- **Location-Based Groups:** Join, discover, or create localized safety groups (e.g. *Mumbai Women Safety Network*, *College Campus Safety Group*).
- **Auto-Broadcast SOS Alerts:** When a user triggers an SOS, an emergency alert is instantly broadcasted as a pinned, pulsing red-purple gradient banner inside all their joined community group chats in real-time.
- **Community Response Actions:** Members in the group can interact with the alert using live-updated response buttons:
  - ✅ *I'm Safe*
  - 🏃 *Going to Help*
  - 🚔 *Notify Authorities*
  - 📢 *Share Alert*
- **Stealth & Privacy:** Features an **Anonymous Mode toggle** in the chat interface to post messages under a generic alias.
- **Group Management:** Group creators can permanently delete groups (clearing members, messages, and Firestore records) with a single click.

### 🎙️ Real-Time Panic Voice Detection
Continuous background speech recognition to identify safety keywords even in high-stress situations:
- **Multi-lingual Support:** Pre-configured trigger phrases in English, Hindi (`बचाओ`, `मदद`), and Marathi (`वाचवा`, `मदत करा`).
- **Dynamic Threat Score Engine:** Calculates a threat index (0-100) based on trigger frequency and keyword severity.
- **Decay Algorithm:** The threat index decays naturally over time to prevent persistent high-threat false states.
- **Scream Detection:** Sound level monitoring via the microphone to trigger alerts.

### 🚨 GPS Location Tracking & Instant SOS SMS
- One-click SOS trigger that gathers highly accurate real-time GPS coordinates.
- Multi-recipient SMS engine to instantly broadcast a Google Maps link to all pre-configured emergency contacts.

### 🏥 Live Safe Spots Directory
Quick-access modules to instantly map and contact nearby support networks:
- 🚓 Police Stations
- 🏥 Hospitals
- 💊 Pharmacies
- 🚌 Bus Stations

---

## ⚒️ Technology Stack & Libraries

- **Framework:** [Flutter](https://flutter.dev/) (cross-platform Android, iOS, and Web compatibility).
- **Language:** [Dart](https://dart.dev/).
- **Backend:** Firebase (Firestore, Cloud Functions, and Firebase Authentication).
- **Speech Recognition:** `speech_to_text` (with continuous confirmation modes).
- **Location Services:** `location` (precision GPS mapping).
- **Local Persistence:** `shared_preferences` (secure local PIN, caching, and configuration states).
- **Hardware Integration:** `vibration` and `sms_advanced`.

---

## ⚙️ Getting Started

### 📋 Prerequisites
Ensure you have Flutter installed and configured on your machine:
- Flutter SDK (>= 3.0.0)
- Android Studio / Xcode (for device compilation)

### 📥 Installation & Running
1. Clone the repository:
   ```bash
   git clone https://github.com/Shweta-Tech-creator/WeSafe.git
   cd WeSafe
   ```
2. Install the dependencies:
   ```bash
   flutter pub get
   ```
3. Run the development server or build the application:
   ```bash
   flutter run
   ```

### 🔒 Permissions Required
For full functionality, the application requests the following device permissions:
- **Microphone:** For panic word monitoring and sound decibel level (scream) checks.
- **Location:** For sending coordinates during SOS triggers.
- **SMS & Phone:** To dispatch emergency SMS messages and place quick calls to helpline numbers.
- **Contacts:** To register local contacts as emergency guardians.
