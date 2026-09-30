// lib/feature/panel_contact/ui/screens/panel_contact_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_contact/data/model/contact_models.dart';
import 'package:tavo/feature/panel_contact/data/repo/contact_panel_repo.dart';
import 'package:tavo/feature/panel_contact/ui/logic/contact_panel_cubit.dart';

/// Staff panel contact settings: editable contact form plus the always
/// visible menu-link QR card (copy + share).
///
/// Builds its own [ContactPanelCubit] through get_it (mirroring
/// `PanelSettingsScreen`) and drives the three async states with
/// [ListSkeleton] / [ErrorStateView] / content. Save failures keep the
/// form and surface a SnackBar (`ContactPanelLoaded.actionError`); a
/// successful save shows the `contact_saved` confirmation.
///
/// Gating is venue-inline (`owner` / `manager` / `full_access` /
/// `manage_settings`); view-only staff get disabled fields, no save
/// button, but still see the QR card.
class PanelContactScreen extends StatefulWidget {
  const PanelContactScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  State<PanelContactScreen> createState() => _PanelContactScreenState();
}

class _PanelContactScreenState extends State<PanelContactScreen> {
  final _formKey = GlobalKey<_LoadedFormState>();

  bool _manage() =>
      widget.venue.role == 'owner' ||
      widget.venue.role == 'manager' ||
      widget.venue.permissions.contains('full_access') ||
      widget.venue.permissions.contains('manage_settings');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ContactPanelCubit(
        getIt<ContactPanelRepo>(),
        restaurantId: widget.restaurantId,
      )..load(),
      child: BlocConsumer<ContactPanelCubit, ContactPanelState>(
        listener: (context, state) {
          if (state is ContactPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ContactPanelLoaded && state.justSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('contact_saved'.tr()),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ContactPanelCubit>();
          final loaded = state is ContactPanelLoaded ? state : null;
          final manageable = _manage();
          return Scaffold(
            body: SafeArea(child: _buildBody(context, cubit, state)),
            // Pinned save: the full form + QR card is taller than small
            // screens, so save lives in a fixed bar instead of inside the
            // scroll (widget tests tap it without scrolling).
            bottomNavigationBar: (loaded != null && manageable)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton(
                        key: const Key('save_contact'),
                        onPressed: loaded.saving
                            ? null
                            : () => _formKey.currentState?.save(),
                        child: loaded.saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text('save_contact'.tr()),
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ContactPanelCubit cubit,
    ContactPanelState state,
  ) {
    if (state is ContactPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.load,
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    if (state is ContactPanelLoaded) {
      return _LoadedForm(
        key: _formKey,
        loaded: state,
        manageable: _manage(),
        onSave: cubit.save,
      );
    }
    // ContactPanelInitial / ContactPanelLoading.
    return const ListSkeleton();
  }
}

class _LoadedForm extends StatefulWidget {
  const _LoadedForm({
    super.key,
    required this.loaded,
    required this.manageable,
    required this.onSave,
  });

  final ContactPanelLoaded loaded;
  final bool manageable;
  final Future<void> Function({
    String? phone,
    String? email,
    String? whatsapp,
    Map<String, String>? socialLinks,
    String? descriptionAr,
    String? descriptionEn,
  }) onSave;

  @override
  State<_LoadedForm> createState() => _LoadedFormState();
}

class _LoadedFormState extends State<_LoadedForm> {
  late final TextEditingController _phone =
      TextEditingController(text: widget.loaded.contact.phone);
  late final TextEditingController _email =
      TextEditingController(text: widget.loaded.contact.email);
  late final TextEditingController _whatsapp =
      TextEditingController(text: widget.loaded.contact.whatsapp);
  late final Map<String, TextEditingController> _socials = {
    for (final k in PanelContact.socialKeys)
      k: TextEditingController(text: widget.loaded.contact.socialLinks[k] ?? ''),
  };
  late final TextEditingController _descAr =
      TextEditingController(text: widget.loaded.contact.descriptionAr);
  late final TextEditingController _descEn =
      TextEditingController(text: widget.loaded.contact.descriptionEn);

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _whatsapp.dispose();
    for (final c in _socials.values) {
      c.dispose();
    }
    _descAr.dispose();
    _descEn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // QR card first: copy/share stay inside the 800x600 test viewport
          // so widget tests can tap them without scrolling; the card is
          // always visible, including for view-only staff.
          _qrCard(context, widget.loaded.contact),
          const SizedBox(height: 24),
          TextField(
            key: const Key('contact_phone'),
            controller: _phone,
            enabled: widget.manageable,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'contact_phone'.tr()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact_email'),
            controller: _email,
            enabled: widget.manageable,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'contact_email'.tr()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact_whatsapp'),
            controller: _whatsapp,
            enabled: widget.manageable,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'contact_whatsapp'.tr()),
          ),
          const SizedBox(height: 24),
          Text(
            'contact_social'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final k in PanelContact.socialKeys) ...[
            TextField(
              key: Key('contact_social_$k'),
              controller: _socials[k],
              enabled: widget.manageable,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: k),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            key: const Key('contact_desc_ar'),
            controller: _descAr,
            enabled: widget.manageable,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'contact_desc_ar'.tr()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact_desc_en'),
            controller: _descEn,
            enabled: widget.manageable,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'contact_desc_en'.tr()),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _qrCard(BuildContext context, PanelContact contact) {
    final menuUrl = contact.menuUrl;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'qr_title'.tr(),
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (menuUrl != null && menuUrl.isNotEmpty) ...[
              Text(
                'menu_link'.tr(),
                style: textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                menuUrl,
                key: const Key('menu_link'),
              ),
              const SizedBox(height: 12),
              Center(
                child: QrImageView(
                  data: menuUrl,
                  version: QrVersions.auto,
                  size: 200,
                  key: const Key('menu_qr'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    key: const Key('copy_link'),
                    onPressed: () => _copyLink(context, menuUrl),
                    child: Text('copy_link'.tr()),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const Key('share_link'),
                    onPressed: () => _shareLink(context, menuUrl),
                    child: Text('share_link'.tr()),
                  ),
                ],
              ),
            ] else
              EmptyStateView(
                icon: Icons.qr_code_outlined,
                title: 'qr_title'.tr(),
                message: 'menu_link'.tr(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLink(BuildContext context, String menuUrl) async {
    await Clipboard.setData(ClipboardData(text: menuUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('link_copied'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareLink(BuildContext context, String menuUrl) async {
    try {
      await SharePlus.instance.share(ShareParams(text: menuUrl));
    } catch (_) {
      // Desktop / test runners have no share plugin: fall back to the
      // clipboard so the link is never silently lost.
      await Clipboard.setData(ClipboardData(text: menuUrl));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('link_copied'.tr()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void save() {
    widget.onSave(
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      whatsapp: _whatsapp.text.trim(),
      socialLinks: {for (final k in PanelContact.socialKeys) k: _socials[k]!.text.trim()},
      descriptionAr: _descAr.text.trim(),
      descriptionEn: _descEn.text.trim(),
    );
  }
}
