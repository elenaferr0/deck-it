<div align="center">

<img width="" src="assets/screenshots/icon.png"  width=160 height=160  align="center">

# DeckIt - FlashCards App  [![Flutter CI](https://github.com/nuanv/DeckIt/actions/workflows/flutter-ci.yml/badge.svg)](https://github.com/nuanv/DeckIt/actions/workflows/flutter-ci.yml)
   </br>
   <div>
      <img src="assets/screenshots/1.jpg" width="30%" />
      <img src="assets/screenshots/2.jpg" width="30%" />
      <img src="assets/screenshots/3.jpg" width="30%" />
      <img src="assets/screenshots/4.jpg" width="30%" />
      <img src="assets/screenshots/5.jpg" width="30%" />
      <img src="assets/screenshots/6.jpg" width="30%" />
   </div>
</div>

<br>

## Getting Started

### Prerequisites

Ensure you have the following installed on your development machine:

- Flutter SDK
- Dart SDK
- A suitable IDE such as Visual Studio Code or Android Studio
- An emulator or physical device for testing

### Installation

1. Clone the repository from GitHub:

   ```sh
   git clone https://github.com/nuanv/DeckIt.git
   ```

2. Navigate to the project directory:

   ```sh
   cd DeckIt
   ```

3. Install the necessary dependencies:

   ```sh
   flutter pub get
   ```

4. Run the application:

   ```sh
   flutter run
   ```

## Features

- Locally stores the data.

- Easy to use and user-friendly.

- [Material Design 3](https://m3.material.io/) style UI, with dynamic color theme.

- CSV/TSV import for words and deck structures.

- Anki-compatible sync payload support with configurable server URL (default: `https://ankiweb.net`).

## CSV Import Format

The app accepts CSV and TSV files with either headers or raw rows.

- Header-based supported columns:
  - Deck: `deck`, `deck_name`, or `name`
  - Front/Question: `front`, `question`, `word`, or `term`
  - Back/Answer: `back`, `answer`, `meaning`, or `definition`
- Headerless rows are interpreted as:
  - `front,back,deck` (deck optional, defaults to `Imported`)

This makes exports from Anki-style front/back datasets compatible.

## Sync API Compatibility

DeckIt sync uses a simple Anki-compatible JSON payload:

- Push endpoint: `POST {SERVER_URL}/api/v1/decks/import`
- Pull endpoint: `GET {SERVER_URL}/api/v1/decks/export`
- Default server URL: `https://ankiweb.net`

Payload structure:

- `format`: `anki-json`
- `version`: `1`
- `decks`: array of decks with `name` and `cards`
- each card includes `front`, `back`, and `fields.Front`/`fields.Back`

Any server that exposes these endpoints and consumes/produces this Anki-compatible payload can sync with DeckIt.
