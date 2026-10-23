# Teacher Corner Flutter App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.11%2B-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.11%2B-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Android-ready-3DDC84?logo=android" alt="Android" />
  <img src="https://github.com/dvya207/teacher-corner-fluttr/actions/workflows/release.yml/badge.svg" alt="CI" />
</p>

A simple Flutter app for the Teacher Corner workflow, built for classroom and teacher use.
It includes the core UI, localization, Firebase integration, and feature screens for
learning content, evidence, and reporting.

## Features

- Teacher dashboard and classroom views
- Learning unit display
- Evidence and submission flow
- Firebase-backed data access
- Multi-language support
- Android app setup with Flutter

## Getting started

### Prerequisites

- Flutter 3.11+
- Dart 3.11+
- Android Studio / Android SDK
- Java 17

### Install

```bash
flutter pub get
flutter analyze
flutter test
```

### Run the app

```bash
flutter run
```

## Release workflow

Use release branches to keep `main` stable:

```bash
git checkout -b release/v1.0.0
git push -u origin release/v1.0.0
```

The GitHub Actions workflow runs checks on `main`, `release/**`, and pull requests.

## Project structure

```text
lib/
assets/
android/
test/
.github/
```

## License

This project is for educational and internal app development use.

<p align="center">
  Developed by Divya Jain
</p>
