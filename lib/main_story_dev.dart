import 'package:flutter/material.dart';
import 'screens/story_flow_screen.dart';

// Story feature only, no Firebase/Firestore: skips login and child profiles.
// Start the model (tool/local_llm.ps1) or put a Gemini key in secrets.json, then:
// flutter run -t lib/main_story_dev.dart --dart-define-from-file=secrets.json
// If neither is reachable, stories use the offline fallback.
void main() {
  runApp(
    MaterialApp(
      title: 'Story Sprout (dev)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const StoryFlowScreen(childName: 'Dev Kid'),
    ),
  );
}
