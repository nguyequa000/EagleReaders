import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/child_profiles.dart';
import '../services/family_settings.dart';
import 'child_rules_screen.dart';
import 'live_refresh.dart';
import 'login_screen.dart';

class ParentSettingsScreen extends StatefulWidget {
  const ParentSettingsScreen({super.key, this.auth, this.settings, this.store});

  /// Injectable for tests; defaults to [FirebaseAuth.instance].
  final FirebaseAuth? auth;

  /// Defaults to [FamilySettings.instance].
  final FamilySettings? settings;

  /// The children for Age Restrictions / Time Limit; defaults to a
  /// [ChildProfileStore] on the real Firebase.
  final ChildProfileStore? store;

  @override
  State<ParentSettingsScreen> createState() => _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends State<ParentSettingsScreen>
    with LiveRefresh {
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  FamilySettings get _settings => widget.settings ?? FamilySettings.instance;

  AiSettings _ai = const AiSettings();
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Another device flipping a switch shows up here too.
    refreshOn(() => [_settings.changes()], _load);
  }

  Future<void> _load() async {
    AiSettings ai;
    String? name;
    try {
      ai = await _settings.load();
      name = await _settings.loadGreetingName();
    } catch (_) {
      // Firebase unreachable (or not set up, in some tests): show defaults.
      ai = const AiSettings();
      name = _auth.currentUser?.email?.split('@').first;
    }
    if (!mounted) return;
    setState(() {
      _ai = ai;
      _name = name;
      _loading = false;
    });
  }

  /// Flips a switch straight away and saves it; puts it back if the save
  /// fails.
  Future<void> _update(AiSettings next) async {
    final previous = _ai;
    setState(() => _ai = next);
    try {
      await _settings.save(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _ai = previous);
      _snack("We couldn't save that setting. Check your connection.");
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _name ?? ''),
    );
    if (name == null || !mounted) return;
    try {
      await _settings.saveDisplayName(name);
      if (!mounted) return;
      setState(() => _name = name.trim());
    } catch (_) {
      if (mounted) _snack("We couldn't save your name. Try again.");
    }
  }

  Future<void> _changeEmail() async {
    final sentTo = await showDialog<String>(
      context: context,
      builder: (_) => _ChangeEmailDialog(auth: _auth),
    );
    if (sentTo != null && mounted) {
      _snack('Check $sentTo for a link to finish changing your email.');
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(auth: _auth),
    );
    if (changed == true && mounted) _snack('Your password has been changed.');
  }

  void _openChildRules() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ChildRulesScreen(store: widget.store, settings: widget.settings),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Parent Settings'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            _buildProfileHeader(context),
            const SizedBox(height: 24),

            // Security Settings
            _buildSectionLabel('Security Settings'),
            _buildTappableItem('Change Email', onTap: _changeEmail),
            const SizedBox(height: 8),
            _buildTappableItem('Change Password', onTap: _changePassword),
            const SizedBox(height: 24),

            // Laid out straight away (disabled until loaded) rather than
            // behind a spinner, so nothing below jumps when the load lands.
            // AI Settings
            _buildSectionLabel('AI Settings'),
            _buildToggleItem(
              'AI story writing',
              'Sprout writes stories from your child\'s picks',
              _ai.aiStories,
              (val) => _update(_ai.copyWith(aiStories: val)),
            ),
            const SizedBox(height: 8),
            _buildToggleItem(
              'AI reading quizzes',
              'Short quizzes after chapters, books and stories',
              _ai.aiQuizzes,
              (val) => _update(_ai.copyWith(aiQuizzes: val)),
            ),
            const SizedBox(height: 8),
            _buildToggleItem(
              "Sprout's writing ideas",
              'Idea questions while your child writes a story',
              _ai.sproutIdeas,
              (val) => _update(_ai.copyWith(sproutIdeas: val)),
            ),
            const SizedBox(height: 24),

            // App Preferences
            _buildSectionLabel('App Preferences'),
            _buildToggleItem(
              'Read Aloud',
              'Stories can be read out loud',
              _ai.readAloud,
              (val) => _update(_ai.copyWith(readAloud: val)),
            ),
            const SizedBox(height: 8),
            _buildToggleItem(
              'Reading Reminders',
              "A nudge on your child's home screen if they haven't read today",
              _ai.readingReminder,
              (val) => _update(_ai.copyWith(readingReminder: val)),
            ),
            const SizedBox(height: 24),

            // Content Settings
            _buildSectionLabel('Content Settings'),
            _buildTappableItem(
              'Age Restrictions',
              trailing: const Text(
                'Edit',
                style: TextStyle(color: Colors.green),
              ),
              onTap: _openChildRules,
            ),
            const SizedBox(height: 8),
            _buildTappableItem(
              'Time Limit',
              trailing: const Text(
                'Edit',
                style: TextStyle(color: Colors.green),
              ),
              onTap: _openChildRules,
            ),
            const SizedBox(height: 24),

            // Sign Out
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await _auth.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign Out', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name == null ? 'Hello!' : 'Hello, $_name',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Parent Account',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _editName,
            child: const Text('Edit', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTappableItem(
    String label, {
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            const Spacer(),
            trailing ??
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem(
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: _loading ? null : onChanged,
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }
}

/// Firebase error codes, in the words the login screen uses.
String _authMessage(FirebaseAuthException e) => switch (e.code) {
  'wrong-password' ||
  'invalid-credential' ||
  'user-mismatch' => 'Your current password is incorrect.',
  'invalid-email' => "That doesn't look like a valid email.",
  'email-already-in-use' => 'Another account already uses that email.',
  'weak-password' => 'Use at least 6 characters for the new password.',
  'requires-recent-login' => 'Please sign out, sign back in, and try again.',
  'network-request-failed' =>
    'No connection. Check your network and try again.',
  'too-many-requests' => 'Too many attempts. Please wait and try again.',
  _ => 'Something went wrong. Please try again.',
};

/// Proves it's still the parent before an account change: Firebase asks for
/// a recent sign-in, and a child holding an unlocked phone doesn't know it.
Future<void> _reauthenticate(FirebaseAuth auth, String password) async {
  final user = auth.currentUser;
  final email = user?.email;
  if (user == null || email == null) {
    throw FirebaseAuthException(code: 'requires-recent-login');
  }
  await user.reauthenticateWithCredential(
    EmailAuthProvider.credential(email: email, password: password),
  );
}

class _NameDialog extends StatefulWidget {
  final String initial;

  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 30,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Name'),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: valid ? () => Navigator.pop(context, _name.text) : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ChangeEmailDialog extends StatefulWidget {
  final FirebaseAuth auth;

  const _ChangeEmailDialog({required this.auth});

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter the new email and your password.');
      return;
    }
    if (email == widget.auth.currentUser?.email) {
      setState(() => _error = "That's already your email.");
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauthenticate(widget.auth, _password.text);
      // Firebase only switches the email once the link sent to it is
      // opened, so a typo can't lock the parent out.
      await widget.auth.currentUser!.verifyBeforeUpdateEmail(email);
      if (mounted) Navigator.pop(context, email);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _authMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('new-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'New email'),
          ),
          TextField(
            key: const Key('current-password'),
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final FirebaseAuth auth;

  const _ChangePasswordDialog({required this.auth});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      setState(() => _error = 'Fill in every field.');
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = "The new passwords don't match.");
      return;
    }
    if (_next.text.length < 6) {
      setState(
        () => _error = 'Use at least 6 characters for the new password.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _reauthenticate(widget.auth, _current.text);
      await widget.auth.currentUser!.updatePassword(_next.text);
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _authMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('current-password'),
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          TextField(
            key: const Key('new-password'),
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
          TextField(
            key: const Key('confirm-password'),
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
