import 'package:flutter/material.dart';
import '../services/parent_pin.dart';
import '../services/pin_attempts.dart';
import 'change_parent_pin_dialog.dart';
import 'parent_dashboard_screen.dart';
import 'pin_lockout.dart';
import 'sticker_kit.dart';
import 'story/paper_background.dart';
import 'story/story_theme.dart';

/// The parent's way in: the PIN they chose at registration.
///
/// An account made before registration asked for one has no PIN at all, so
/// rather than a lock with no key it asks the parent to create one here, typed
/// twice.
class ParentPinScreen extends StatefulWidget {
  const ParentPinScreen({super.key});

  @override
  State<ParentPinScreen> createState() => _ParentPinScreenState();
}

enum _Mode { loading, enter, create, confirm }

class _ParentPinScreenState extends State<ParentPinScreen>
    with PinLockout<ParentPinScreen> {
  final TextEditingController _pin = TextEditingController();
  _Mode _mode = _Mode.loading;
  String? _error;

  /// The first entry while creating a PIN, waiting for its confirmation.
  String? _firstEntry;

  bool _busy = false;

  @override
  String get pinAttemptsKey => PinAttempts.parent;

  @override
  void initState() {
    super.initState();
    _checkForPin();
  }

  Future<void> _checkForPin() async {
    bool isSet;
    try {
      isSet = await ParentPin.instance.isSet();
    } catch (_) {
      // Can't tell; ask for the PIN; a wrong guess just says so.
      isSet = true;
    }
    if (!mounted) return;
    setState(() => _mode = isSet ? _Mode.enter : _Mode.create);
  }

  void _openDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ParentDashboardScreen()),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pin = _pin.text;
    switch (_mode) {
      case _Mode.loading:
        return;
      case _Mode.enter:
        setState(() => _busy = true);
        if (await checkLock()) {
          if (mounted) setState(() => _busy = false);
          return;
        }
        bool ok;
        try {
          ok = await ParentPin.instance.verify(pin);
        } catch (_) {
          ok = false;
        }
        if (ok) {
          await pinSucceeded();
          if (!mounted) return;
          setState(() => _busy = false);
          _openDashboard();
        } else {
          final locked = await pinFailed();
          if (!mounted) return;
          _pin.clear();
          setState(() {
            _busy = false;
            _error = locked ? null : 'Incorrect PIN. Try again.';
          });
        }
      case _Mode.create:
        if (!ParentPin.isValid(pin)) {
          setState(() => _error = 'Choose 4 digits.');
          return;
        }
        _pin.clear();
        setState(() {
          _firstEntry = pin;
          _mode = _Mode.confirm;
          _error = null;
        });
      case _Mode.confirm:
        if (pin != _firstEntry) {
          _pin.clear();
          setState(() {
            _firstEntry = null;
            _mode = _Mode.create;
            _error = "Those didn't match. Start again.";
          });
          return;
        }
        setState(() => _busy = true);
        try {
          await ParentPin.instance.set(pin);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = "Couldn't save your PIN. Check your connection.";
          });
          return;
        }
        if (!mounted) return;
        _openDashboard();
    }
  }

  /// "Forgot PIN?": the account password sets a new one, which also lifts a
  /// lock-out.
  Future<void> _forgotPin() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const ChangeParentPinDialog(forgot: true),
    );
    if (changed != true || !mounted) return;
    await checkLock();
    if (!mounted) return;
    _pin.clear();
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN changed. Enter your new PIN.')),
    );
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = StoryTheme.of(context);
    if (_mode == _Mode.loading) {
      return Scaffold(
        backgroundColor: palette.ground,
        body: PaperBackground(
          child: Column(
            children: [
              const StickerHeader(
                title: 'Parent Login',
                showBack: true,
                forParent: true,
                trailing: [ThemeSticker()],
              ),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: palette.action),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final (prompt, button) = switch (_mode) {
      _Mode.create => ('Create a parent PIN', 'Next'),
      _Mode.confirm => ('Type it again', 'Save PIN'),
      _ => ('Enter your PIN', 'Enter'),
    };
    return StickerPinPage(
      title: 'Parent Login',
      emoji: '👨‍👩‍👧',
      emojiTint: palette.tintBlue,
      prompt: prompt,
      controller: _pin,
      // The lock only applies to entering a PIN, not to creating one.
      error: _mode == _Mode.enter ? lockMessage ?? _error : _error,
      enabled: _mode != _Mode.enter || !isLocked,
      footer: _mode == _Mode.enter
          ? TextButton(
              key: const Key('forgot-parent-pin'),
              onPressed: _forgotPin,
              child: Text(
                'Forgot PIN?',
                style: StoryTheme.body(color: palette.ink, weight: 700),
              ),
            )
          : null,
      buttonLabel: button,
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      onSubmit: _submit,
      forParent: true,
    );
  }
}
