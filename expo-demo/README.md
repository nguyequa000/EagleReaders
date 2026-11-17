# Story Sprout — Expo Go demo

A React Native (Expo) port of the Flutter app in this repository, so Story Sprout
can be opened on an iPhone with **Expo Go** for a demo. It lives only on the
`demo-test` branch; the Flutter app is unchanged.

## Run it

1. Install [Node.js](https://nodejs.org) (LTS).
2. Install **Expo Go** from the App Store on the iPhone.
3. In this folder:
   ```
   npm install
   npx expo start --tunnel
   ```
4. Scan the QR code with the iPhone's Camera app; it opens in Expo Go.

`--tunnel` works even when the phone and computer are on different networks.
On the same Wi-Fi, `npx expo start` (no tunnel) is faster.

## Data

It uses the same Firebase project as the Flutter app (logins, Firestore and
Gemini through Firebase AI Logic), with the same Firestore paths and fields.

To keep the main app's families safe, the demo only signs in to accounts that
were **registered in the demo**: registration tags the parent document with
`createdBy: "expo-demo"`, and sign-in refuses any account without that tag
(see `src/services/demoAccount.ts`). Everything an account stores lives under
`parents/{uid}`, so a demo account can never read or change anyone else's
children, stories, coins or rewards.

Books, reading positions and reader settings stay on the phone, as in the
Flutter app.

## What's where

| Folder | What |
|---|---|
| `src/screens` | Every screen: sign-in, family, parent side, child dashboard, story flow, reader, quiz |
| `src/services` | Firestore stores, Gemini story writer, safety filters, EPUB reader, book shelf |
| `src/story` | Hero catalog, scenes and story-flow pieces |
| `src/components` | The sticker-book design kit |
| `src/generated` | Asset tables generated from `assets/story` |

## Differences from the Flutter app

- Text books are shown a page at a time, one section per page view; picture
  books a picture at a time. Chapter quizzes, resume and "% read" work the same.
- Reading settings use + / − buttons for font size and line spacing.
- The child dashboard's search button (which did nothing yet) is left out.
