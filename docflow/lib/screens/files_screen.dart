import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';

import '../core/tokens.dart';
import '../services/file_store.dart';
import '../widgets/file_actions.dart';
import '../widgets/file_row.dart';
import '../widgets/share_sheet.dart';

/// The Files tab — the user's converted documents, read from the local SQLite
/// log rather than a hardcoded list.
///
/// Tap opens a file with the platform's own viewer; swipe deletes it from the
/// phone. Nothing here is fetched over the network: the backend keeps no copy
/// of a converted file, so this device's disk is the only source.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _store = FileStore.instance;
  final _search = TextEditingController();

  List<StoredFile> _files = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Clearing app storage or restoring a backup can leave rows whose file is
    // gone; drop those first so tapping one cannot fail confusingly.
    await _store.pruneMissing();
    final files = await _store.all();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  List<StoredFile> get _visible {
    if (_query.isEmpty) return _files;
    final needle = _query.toLowerCase();
    return _files.where((f) => f.name.toLowerCase().contains(needle)).toList();
  }

  Future<void> _open(StoredFile file) async {
    final result = await OpenFilex.open(file.path);
    if (result.type == ResultType.done || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.type == ResultType.noAppToOpen
              ? 'No app on this phone can open a '
                  '${file.extension.toUpperCase()} file'
              : 'Could not open ${file.name}',
        ),
      ),
    );
  }

  Future<void> _delete(StoredFile file) async {
    await _store.delete(file);
    if (!mounted) return;
    setState(() => _files = _files.where((f) => f.id != file.id).toList());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${file.name}')),
    );
  }

  Future<void> _rename(StoredFile file) async {
    final name = await showRenameSheet(context, name: file.name);
    if (name == null || name.isEmpty) return;

    final renamed = await _store.rename(file, name);
    if (renamed == null || !mounted) return;
    setState(() {
      _files = [
        for (final f in _files)
          if (f.id == renamed.id) renamed else f,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visible;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Text('My Files', style: theme.textTheme.displayMedium),
                const Spacer(),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: 'Refresh',
                  icon: const Icon(LucideIcons.refreshCw,
                      size: 20, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search your files',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                _loading
                    ? 'Loading…'
                    : '${visible.length} '
                        '${visible.length == 1 ? 'file' : 'files'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(child: _buildBody(visible)),
        ],
      ),
    );
  }

  Widget _buildBody(List<StoredFile> visible) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (visible.isEmpty) {
      return _EmptyState(searching: _query.isNotEmpty);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final file = visible[index];
          return Dismissible(
            key: ValueKey(file.id),
            direction: DismissDirection.endToStart,
            background: const _DeleteBackground(),
            // Confirm before the row leaves the list — a mis-swipe would
            // otherwise destroy the user's only copy of a document.
            confirmDismiss: (_) =>
                showDeleteSheet(context, file: file.toDocumentFile()),
            onDismissed: (_) => _delete(file),
            child: FileRow(
              file: file.toDocumentFile(),
              onTap: () => _open(file),
              onShare: () => showShareSheet(context, title: file.name),
              onMore: () => _showActions(file),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showActions(StoredFile file) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(name: file.name),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'open':
        await _open(file);
      case 'rename':
        await _rename(file);
      case 'share':
        await showShareSheet(context, title: file.name);
      case 'delete':
        final confirmed =
            await showDeleteSheet(context, file: file.toDocumentFile());
        if (confirmed) await _delete(file);
    }
  }
}

/// Shown when the library is empty, or when a search matches nothing.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                searching ? LucideIcons.searchX : LucideIcons.folderOpen,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searching ? 'No matches' : 'No files yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Try a different search term.'
                  : 'Convert a document and it will appear here, saved on '
                      'this device.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The coral panel revealed behind a row as it is swiped away.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(right: 24),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppColors.coral,
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: const Icon(LucideIcons.trash2, color: Colors.white, size: 22),
    );
  }
}

/// Overflow menu for one stored file. Returns an action id, so the caller owns
/// the navigation and this stays a pure picker.
class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.name});

  final String name;

  static const _items = [
    ('open', LucideIcons.externalLink, 'Open', AppColors.primary),
    ('share', LucideIcons.share2, 'Share', AppColors.primary),
    ('rename', LucideIcons.edit2, 'Rename', AppColors.primary),
    ('delete', LucideIcons.trash2, 'Delete', AppColors.coral),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            for (final (id, icon, label, color) in _items)
              ListTile(
                onTap: () => Navigator.of(context).pop(id),
                leading: Icon(icon, size: 20, color: color),
                title: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
