import 'package:flutter/material.dart';
import '../services/story_generator.dart';
import 'story_character_screen.dart';

class StoryReaderScreen extends StatefulWidget {
  final StoryConfig config;

  /// Injectable for tests; defaults to the Gemini-backed generator.
  final StoryGenerator? generator;

  const StoryReaderScreen({super.key, required this.config, this.generator});

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  static const Color _forestGreen = Color(0xFF3D6B1A);

  late final StoryGenerator _generator;
  late Future<String> _story;

  @override
  void initState() {
    super.initState();
    _generator = widget.generator ?? const StoryGenerator();
    _story = _generate();
  }

  // Runs once per open (or per retry), never from build().
  Future<String> _generate() async {
    final config = widget.config;
    final text = await _generator.generateStory(
      character: config.character ?? 'a curious friend',
      mood: config.mood ?? 'wonderful',
      setting: config.setting ?? 'a magical place',
    );
    if (text.trim().isEmpty) {
      throw const StoryGenerationException(
        'The story came back empty. Please try again.',
      );
    }
    return text;
  }

  void _retry() {
    setState(() {
      _story = _generate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Story'),
        backgroundColor: _forestGreen,
      ),
      body: Container(
        color: const Color(0xFFF5F0DC),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDetailBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<String>(
                future: _story,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return _buildLoading();
                  }
                  if (snapshot.hasError) {
                    return _buildError(snapshot.error!);
                  }
                  return _buildStory(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _forestGreen),
          SizedBox(height: 16),
          Text(
            'Sprout is writing your story…',
            style: TextStyle(fontSize: 16, color: Color(0xFF2E2E2E)),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    final message = error is StoryGenerationException
        ? error.message
        : 'Sprout could not write your story right now. '
            'Check your connection and try again.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Color(0xFF2E2E2E),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildStory(String text) {
    return SingleChildScrollView(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          height: 1.6,
          color: Color(0xFF2E2E2E),
        ),
      ),
    );
  }

  Widget _buildDetailBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Story Preview',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D6B1A),
            ),
          ),
          const SizedBox(height: 8),
          Text('Character: ${widget.config.character ?? 'unknown'}'),
          Text('Mood: ${widget.config.mood ?? 'unknown'}'),
          Text('Setting: ${widget.config.setting ?? 'unknown'}'),
        ],
      ),
    );
  }
}
