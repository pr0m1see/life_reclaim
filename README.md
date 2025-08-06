# Life Reclaim 🕒

**Reclaim Your Life. Treat Time as a Friend.**

A privacy-first, AI-powered time management application built with Flutter, featuring local Gemma 3n integration for intelligent task management without compromising your privacy.

## ✨ Key Features

- 🤖 **Local AI Integration**: Powered by Gemma 3n model via Ollama for intelligent task suggestions and decomposition
- 🔒 **Privacy First**: 100% local data processing - your data never leaves your device
- 📱 **Cross-Platform**: Native performance on iOS, Android, Windows, macOS, and Linux
- ⚡ **Smart Task Management**: AI-powered task creation, prioritization, and decomposition
- 🎯 **Intelligent Suggestions**: Context-aware tag suggestions and time estimation
- 📊 **Time Analytics**: Comprehensive insights into your productivity patterns
- 🔐 **Encrypted Storage**: Military-grade SQLCipher encryption for all data

## 🏗️ Architecture

- **Frontend**: Flutter 3.x with Dart
- **AI Engine**: Ollama + Gemma 3n (3B parameters)
- **Database**: SQLite with SQLCipher encryption
- **State Management**: GetX with reactive programming
- **Architecture**: Clean Architecture with Repository pattern

## 🚀 Quick Start

### Prerequisites

1. **Flutter SDK** (3.16.0+)
2. **Ollama** installed with Gemma model:
   ```bash
   # Install Ollama
   curl -fsSL https://ollama.com/install.sh | sh
   
   # Pull Gemma 3n model
   ollama pull gemma3n
   ```

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-repo/life_reclaim.git
   cd life_reclaim
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## 🤖 AI Setup

1. Start Ollama service:
   ```bash
   ollama serve
   ```

2. In the app, navigate to **Models** page
3. Click the settings icon to configure your Ollama server IP
4. Test the connection and enjoy AI-powered task management!

## 🎯 Core Features

### Smart Task Creation
- AI-powered task analysis and categorization
- Automatic tag suggestions based on task content
- Intelligent priority and time estimation

### Task Decomposition
- Complex tasks automatically broken into manageable subtasks
- Context-aware suggestions for optimal workflow
- SMART criteria-based task structuring

### Privacy-First Design
- All AI processing happens locally on your device
- Zero data transmission to external servers
- Encrypted local storage with SQLCipher

### Project Structure
```
lib/
├── controllers/         # Business logic controllers
├── models/             # Data models and entities
├── pages/              # UI screens and widgets
├── services/           # Core services (AI, Database, Network)
├── repositories/       # Data access layer
└── widgets/           # Reusable UI components
```

### Key Dependencies
- `get: ^4.6.6` - State management
- `drift: ^2.14.1` - Database ORM
- `http: ^1.1.2` - Network requests
- `flutter_hooks: ^0.20.3` - UI state management