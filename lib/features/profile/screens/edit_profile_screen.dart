import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/video_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseService _service = SupabaseService();

  late TextEditingController _displayNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  File? _newAvatarFile;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.profile.displayName ?? '');
    _usernameController =
        TextEditingController(text: widget.profile.username);
    _bioController =
        TextEditingController(text: widget.profile.bio ?? '');

    // Track changes
    _displayNameController.addListener(_onChanged);
    _usernameController.addListener(_onChanged);
    _bioController.addListener(_onChanged);
  }

  void _onChanged() {
    final changed = _displayNameController.text !=
        (widget.profile.displayName ?? '') ||
        _usernameController.text != widget.profile.username ||
        _bioController.text != (widget.profile.bio ?? '') ||
        _newAvatarFile != null;

    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ─────────────── PICK PHOTO ───────────────

  Future<void> _pickPhoto() async {
    final action = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: AppTheme.dividerColor, height: 1),
              _sheetOption(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Library',
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              _sheetOption(
                icon: Icons.camera_alt_rounded,
                label: 'Take a Photo',
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              if (widget.profile.avatarUrl != null ||
                  _newAvatarFile != null)
                _sheetOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Current Photo',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _newAvatarFile = null;
                      _hasChanges = true;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (action == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: action,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null && mounted) {
      setState(() {
        _newAvatarFile = File(picked.path);
        _hasChanges = true;
      });
    }
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textPrimary),
      title: Text(
        label,
        style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: 15),
      ),
      onTap: onTap,
    );
  }

  // ─────────────── SAVE ───────────────

  Future<void> _save() async {
    final name = _displayNameController.text.trim();
    final username = _usernameController.text.trim();
    final bio = _bioController.text.trim();

    if (username.length < 3) {
      _showError('Username must be at least 3 characters.');
      return;
    }
    if (name.isEmpty) {
      _showError('Display name cannot be empty.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _service.updateProfile(
        displayName: name,
        username: username,
        bio: bio,
        avatarFile: _newAvatarFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Profile updated!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Pop and signal that profile was updated
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('Failed to save: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────── BUILD ───────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmDiscard(),
        ),
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: (_hasChanges && !_isSaving) ? _save : null,
              child: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              )
                  : Text(
                'Save',
                style: TextStyle(
                  color: _hasChanges
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarSection(),
              const SizedBox(height: 32),
              _buildFieldsSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── AVATAR ───────────────

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                // Avatar circle
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                  ),
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(child: _buildAvatarImage()),
                ),
                // Camera badge
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.backgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickPhoto,
            child: const Text(
              'Change Profile Photo',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    // Priority: new local file > existing network URL > placeholder
    if (_newAvatarFile != null) {
      return Image.file(_newAvatarFile!, fit: BoxFit.cover);
    }
    if (widget.profile.avatarUrl != null) {
      return Image.network(
        widget.profile.avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _avatarPlaceholder(),
      );
    }
    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: AppTheme.surfaceColor,
      child: const Icon(Icons.person_rounded,
          color: AppTheme.textSecondary, size: 52),
    );
  }

  // ─────────────── FIELDS ───────────────

  Widget _buildFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Personal Info'),
        const SizedBox(height: 16),
        _buildField(
          label: 'Display Name',
          controller: _displayNameController,
          hint: 'Your name shown on profile',
          icon: Icons.badge_outlined,
          maxLength: 50,
        ),
        const SizedBox(height: 16),
        _buildField(
          label: 'Username',
          controller: _usernameController,
          hint: 'Your @handle',
          icon: Icons.alternate_email_rounded,
          maxLength: 30,
          prefix: '@',
        ),
        const SizedBox(height: 24),
        _sectionLabel('About'),
        const SizedBox(height: 16),
        _buildField(
          label: 'Bio',
          controller: _bioController,
          hint: 'Tell people a little about yourself...',
          icon: Icons.notes_rounded,
          maxLines: 4,
          maxLength: 150,
        ),
        const SizedBox(height: 8),
        const Text(
          '💡 Emojis make your bio pop! Try: 🎬 🌍 🔥',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    String? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
            prefixText: prefix,
            prefixStyle: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 15),
            counterStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              const BorderSide(color: AppTheme.primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  // ─────────────── SAVE BUTTON ───────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_hasChanges && !_isSaving) ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          disabledBackgroundColor: AppTheme.surfaceColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isSaving
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 10),
            Text('Saving...',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        )
            : const Text(
          'Save Changes',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
      ),
    );
  }

  // ─────────────── DISCARD DIALOG ───────────────

  Future<void> _confirmDiscard() async {
    if (!_hasChanges) {
      Navigator.of(context).pop();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard Changes?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) Navigator.of(context).pop();
  }
}
