import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../core/tokens.dart';
import '../widgets/settings_row.dart';

/// Help Center: FAQ and Contact us behind one underlined tab bar. The kit's
/// third FAQ category is "Service"; DocFlow's service is conversion, so that
/// chip becomes Convert.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        title: Text('Help Center', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SettingsTabs(
                labels: const ['FAQ', 'Contact us'],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
            Expanded(
              child: _tab == 0 ? const _FaqTab() : const _ContactTab(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One question and its answer. Answers are only written for the entries the
/// kit expands; the rest carry the same copy shape.
class _Faq {
  const _Faq(this.category, this.question, this.answer);

  final String category;
  final String question;
  final String answer;
}

const _faqs = [
  _Faq('General', 'What is DocFlow?',
      'DocFlow converts documents between formats — PDF, Word, Excel and '
          'images — and scans paper into files. Everything runs on your device.'),
  _Faq('General', 'Is the DocFlow App free?',
      'Yes. Every conversion tool is free and unlimited, with no watermark '
          'and no account tier to upgrade to.'),
  _Faq('General', 'How do I export to PDF?',
      'Pick Word to PDF, Excel to PDF or Image to PDF on the Convert tab, '
          'choose a file, and the PDF lands in your library.'),
  _Faq('Account', 'How can I log out from DocFlow?',
      'Open the Account tab and tap Logout at the bottom of the list, then '
          'confirm.'),
  _Faq('Account', 'How to close DocFlow account?',
      'Contact us from the Help Center and we will close the account and '
          'remove anything stored against it.'),
  _Faq('Account', 'Why does the DocFlow app force close?',
      'Update to the latest version first. If it keeps happening, send us '
          'the device model from Contact us.'),
  _Faq('Convert', "Why can't I export to PDF?",
      'Check the source file opens in the viewer. A file still downloading '
          'from cloud storage cannot be read yet.'),
  _Faq('Convert', 'Does converting change the original file?',
      'No. The original stays in your library unless you turn off Keep '
          'Original After Converting in Preferences.'),
  _Faq('Convert', 'How many files can I merge at once?',
      'Merge PDF takes as many files as you can select. They combine in the '
          'order you pick them.'),
  _Faq('Scan', "Why can't I scan documents?",
      'DocFlow needs camera permission. Grant it in your device settings '
          'and reopen the scanner.'),
  _Faq('Scan', 'Can I scan more than one page?',
      'Yes. Keep tapping the shutter — the page counter on the thumbnail '
          'tracks the batch, and they save as one PDF.'),
];

class _FaqTab extends StatefulWidget {
  const _FaqTab();

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  static const _categories = ['General', 'Account', 'Convert', 'Scan'];

  final _search = TextEditingController();
  final _focus = FocusNode();
  String _category = 'General';
  int? _expanded = 0;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Faq> get _visible =>
      _faqs.where((f) => f.category == _category).toList();

  /// Type-ahead runs across every category, not just the active chip.
  List<_Faq> get _suggestions {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _faqs
        .where((f) => f.question.toLowerCase().contains(query))
        .take(4)
        .toList();
  }

  void _openSuggestion(_Faq faq) {
    _focus.unfocus();
    _search.clear();
    setState(() {
      _category = faq.category;
      _expanded = _visible.indexOf(faq);
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;

    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              for (final category in _categories)
                FilterChipPill(
                  label: category,
                  selected: category == _category,
                  onTap: () => setState(() {
                    _category = category;
                    _expanded = null;
                  }),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _SearchField(controller: _search, focusNode: _focus),
        ),
        const SizedBox(height: 12),
        Expanded(
          // The suggestion card sits over the list rather than pushing it, as
          // in the kit's search state.
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                children: [
                  for (final (i, faq) in _visible.indexed)
                    _FaqCard(
                      faq: faq,
                      expanded: i == _expanded,
                      onTap: () =>
                          setState(() => _expanded = i == _expanded ? null : i),
                    ),
                ],
              ),
              if (suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _SuggestionCard(
                    suggestions: suggestions,
                    onPick: _openSuggestion,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Muted pill that turns primary-tinted with a primary border on focus.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final active = focusNode.hasFocus;

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: active ? AppColors.primaryTint : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: active ? Border.all(color: AppColors.primary) : null,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search,
              size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const Icon(LucideIcons.slidersHorizontal,
              size: 20, color: AppColors.primary),
        ],
      ),
    );
  }
}

/// Type-ahead results, hairline-separated on a raised white card.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestions, required this.onPick});

  final List<_Faq> suggestions;
  final ValueChanged<_Faq> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, faq) in suggestions.indexed) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1),
              ),
            InkWell(
              onTap: () => onPick(faq),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Text(
                  faq.question,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Outlined card; the answer appears under a hairline when expanded and the
/// chevron flips.
class _FaqCard extends StatelessWidget {
  const _FaqCard({
    required this.faq,
    required this.expanded,
    required this.onTap,
  });

  final _Faq faq;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        faq.question,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(LucideIcons.chevronDown,
                          size: 20, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: expanded
                  ? Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(height: 1),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              faq.answer,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Support channels, one outlined card each.
class _ContactTab extends StatelessWidget {
  const _ContactTab();

  static const _channels = [
    (LucideIcons.headphones, 'Contact us'),
    (LucideIcons.messageCircle, 'WhatsApp'),
    (LucideIcons.instagram, 'Instagram'),
    (LucideIcons.facebook, 'Facebook'),
    (LucideIcons.twitter, 'Twitter'),
    (LucideIcons.globe, 'Website'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        for (final (icon, label) in _channels)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening $label')),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Row(
                    children: [
                      Icon(icon, size: 26, color: AppColors.primary),
                      const SizedBox(width: 20),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
