// lib/feature/restaurant_panel/ui/screens/restaurant_profile_screen.dart
//
// The owner-editable half of the venue profile: identity (name, description,
// address in both languages) and the two images guests see everywhere — the
// logo and the cover. Phone, email and social links stay on the existing
// contact screen, which already edits them.
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tavo/core/network/api_service.dart';

import '../../data/model/restaurant_profile.dart';
import '../../data/repo/restaurant_profile_repo.dart';

class RestaurantProfileScreen extends StatefulWidget {
  const RestaurantProfileScreen({
    super.key,
    required this.restaurantId,
    this.repo,
  });

  final String restaurantId;

  /// Injected by tests; when null the screen owns a real repository.
  final RestaurantProfileRepo? repo;

  @override
  State<RestaurantProfileScreen> createState() =>
      _RestaurantProfileScreenState();
}

class _RestaurantProfileScreenState extends State<RestaurantProfileScreen> {
  late final RestaurantProfileRepo _repo;

  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descriptionAr = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _addressAr = TextEditingController();
  final _addressEn = TextEditingController();

  RestaurantProfile? _saved;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingLogo = false;
  bool _uploadingCover = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RestaurantProfileRepo(ApiService());
    _load();
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _descriptionAr.dispose();
    _descriptionEn.dispose();
    _addressAr.dispose();
    _addressEn.dispose();
    super.dispose();
  }

  String _l(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repo.getProfile(widget.restaurantId);
      if (!mounted) return;
      _saved = profile;
      _nameAr.text = profile.nameAr;
      _nameEn.text = profile.nameEn;
      _descriptionAr.text = profile.descriptionAr;
      _descriptionEn.text = profile.descriptionEn;
      _addressAr.text = profile.addressAr;
      _addressEn.text = profile.addressEn;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  RestaurantProfile get _draft => (_saved ?? const RestaurantProfile()).copyWith(
    nameAr: _nameAr.text,
    nameEn: _nameEn.text,
    descriptionAr: _descriptionAr.text,
    descriptionEn: _descriptionEn.text,
    addressAr: _addressAr.text,
    addressEn: _addressEn.text,
  );

  Future<void> _save() async {
    final base = _saved;
    if (base == null) return;

    final body = _draft.diffFrom(base);
    if (body.isEmpty) {
      _toast(_l('لا توجد تغييرات', 'No changes to save'));
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await _repo.updateProfile(widget.restaurantId, body);
      if (!mounted) return;
      setState(() {
        _saved = updated;
        _saving = false;
      });
      _toast(_l('تم حفظ بيانات المطعم', 'Restaurant saved'));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('$error');
    }
  }

  Future<void> _pickImage({required bool logo}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => logo ? _uploadingLogo = true : _uploadingCover = true);

    try {
      final updated = await _repo.uploadImage(
        restaurantId: widget.restaurantId,
        kind: logo ? 'logo' : 'cover',
        bytes: bytes,
        filename: picked.name,
      );
      if (!mounted) return;
      setState(() {
        _saved = updated;
        _uploadingLogo = false;
        _uploadingCover = false;
      });
      _toast(
        logo
            ? _l('تم تحديث الشعار', 'Logo updated')
            : _l('تم تحديث الغلاف', 'Cover updated'),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingLogo = false;
        _uploadingCover = false;
      });
      _toast('$error');
    }
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_l('ملف المطعم', 'Restaurant profile')),
        actions: [
          IconButton(
            tooltip: _l('إعادة المحاولة', 'Reload'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Iconsax.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _failure()
          : _form(),
      bottomNavigationBar: _loading || _error != null ? null : _saveBar(),
    );
  }

  Widget _failure() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.warning_2, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Iconsax.refresh),
            label: Text(_l('إعادة المحاولة', 'Try again')),
          ),
        ],
      ),
    ),
  );

  Widget _form() {
    final profile = _saved ?? const RestaurantProfile();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _mediaHeader(profile),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(_l('الهوية', 'Identity')),
              _field(_nameAr, _l('الاسم (عربي)', 'Name (Arabic)'), rtl: true),
              _field(_nameEn, _l('الاسم (إنجليزي)', 'Name (English)')),
              _field(
                _descriptionAr,
                _l('الوصف (عربي)', 'Description (Arabic)'),
                rtl: true,
                lines: 3,
              ),
              _field(
                _descriptionEn,
                _l('الوصف (إنجليزي)', 'Description (English)'),
                lines: 3,
              ),
              const SizedBox(height: 8),
              _sectionTitle(_l('العنوان', 'Address')),
              _field(_addressAr, _l('العنوان (عربي)', 'Address (Arabic)'), rtl: true),
              _field(_addressEn, _l('العنوان (إنجليزي)', 'Address (English)')),
              if (profile.hasRating)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Iconsax.star_1, color: Colors.amber, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${profile.ratingsAverage.toStringAsFixed(1)} '
                        '(${profile.ratingsQuantity})',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mediaHeader(RestaurantProfile profile) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: _uploadingCover ? null : () => _pickImage(logo: false),
          child: Container(
            height: 180,
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            child: profile.coverUrl.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.gallery_add, size: 32),
                        const SizedBox(height: 6),
                        Text(_l('أضف صورة الغلاف', 'Add a cover photo')),
                      ],
                    ),
                  )
                : Image.network(
                    profile.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Iconsax.gallery_slash, size: 32)),
                  ),
          ),
        ),
        if (_uploadingCover)
          const Positioned.fill(child: Center(child: CircularProgressIndicator())),
        Positioned(
          left: 16,
          bottom: -36,
          child: GestureDetector(
            onTap: _uploadingLogo ? null : () => _pickImage(logo: true),
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant, width: 2),
                image: profile.logoUrl.isEmpty
                    ? null
                    : DecorationImage(
                        image: NetworkImage(profile.logoUrl),
                        fit: BoxFit.cover,
                      ),
              ),
              child: profile.logoUrl.isEmpty
                  ? const Icon(Iconsax.camera, size: 26)
                  : (_uploadingLogo
                        ? const Padding(
                            padding: EdgeInsets.all(26),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool rtl = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      minLines: lines,
      maxLines: lines,
      textDirection: rtl ? TextDirection.rtl : null,
      maxLength: lines > 1 ? 500 : 50,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
    ),
  );

  Widget _saveBar() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Iconsax.tick_circle),
          label: Text(_l('حفظ التغييرات', 'Save changes')),
        ),
      ),
    ),
  );
}
