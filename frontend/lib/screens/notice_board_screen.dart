import 'package:flutter/material.dart';
import '../services/notice_service.dart';

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen>
    with SingleTickerProviderStateMixin {
  final _service = NoticeService();
  List<Notice> _notices = [];
  bool _loading = true;
  String? _error;
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _load();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchNotices();
      if (mounted) {
        setState(() { _notices = data; _loading = false; });
        _fabAnim.forward();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ─── Priority helpers ──────────────────────────────────────────────────────
  Color _pColor(String p) {
    switch (p) {
      case 'high':   return const Color(0xFFEF5350);
      case 'medium': return const Color(0xFFFF9800);
      default:       return const Color(0xFF7C3AED);
    }
  }

  IconData _pIcon(String p) {
    switch (p) {
      case 'high':   return Icons.error_outline_rounded;
      case 'medium': return Icons.info_outline_rounded;
      default:       return Icons.notifications_none_rounded;
    }
  }

  String _pLabel(String p) => p[0].toUpperCase() + p.substring(1);

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours   < 24) return '${d.inHours}h ago';
    if (d.inDays    < 7)  return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }

  // ─── Add notice sheet ──────────────────────────────────────────────────────
  void _showAddSheet() {
    final titleCtrl    = TextEditingController();
    final bodyCtrl     = TextEditingController();
    String priority    = 'medium';
    bool posting       = false;
    String? sheetError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
                const SizedBox(height: 20),
                Text('Post a Notice',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  )),
                const SizedBox(height: 16),

                // Title field
                _Field(controller: titleCtrl, label: 'Title', icon: Icons.title_rounded),
                const SizedBox(height: 12),

                // Body field
                _Field(controller: bodyCtrl, label: 'Message (optional)', icon: Icons.notes_rounded, maxLines: 3),
                const SizedBox(height: 16),

                // Priority chips
                Text('Priority',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurface,
                  )),
                const SizedBox(height: 8),
                Row(
                  children: ['low', 'medium', 'high'].map((p) {
                    final sel = priority == p;
                    final c = _pColor(p);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setModal(() => priority = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? c : c.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: sel ? c : c.withValues(alpha: 0.2)),
                            ),
                            alignment: Alignment.center,
                            child: Text(_pLabel(p),
                              style: TextStyle(
                                color: sel ? Colors.white : c,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(sheetError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: posting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                    label: Text(posting ? 'Posting…' : 'Post Notice'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: posting ? null : () async {
                      final t = titleCtrl.text.trim();
                      if (t.isEmpty) {
                        setModal(() => sheetError = 'Title is required');
                        return;
                      }
                      setModal(() { posting = true; sheetError = null; });
                      try {
                        final n = await _service.createNotice(
                          title: t,
                          body: bodyCtrl.text.trim(),
                          priority: priority,
                        );
                        if (mounted) {
                          setState(() => _notices.insert(0, n));
                          Navigator.pop(ctx);
                        }
                      } catch (e) {
                        setModal(() { posting = false; sheetError = 'Failed: $e'; });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Delete ────────────────────────────────────────────────────────────────
  Future<void> _delete(Notice n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Notice', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete "${n.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _service.deleteNotice(n.id);
      setState(() => _notices.removeWhere((x) => x.id == n.id));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: cs.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: cs.onSurface),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notice Board',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                      letterSpacing: -0.5,
                    )),
                ],
              ),
              background: Container(color: cs.surface),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF7C3AED)),
                onPressed: _load,
              ),
              const SizedBox(width: 4),
            ],
          ),

          // ── Content ───────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: _load))
          else if (_notices.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final n = _notices[i];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(n.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 280 + i * 40),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, child) => Opacity(
                        opacity: v,
                        child: Transform.translate(offset: Offset(0, (1-v)*20), child: child),
                      ),
                      child: _NoticeCard(
                        notice: n,
                        pColor: _pColor(n.priority),
                        pIcon: _pIcon(n.priority),
                        pLabel: _pLabel(n.priority),
                        timeAgo: _timeAgo(n.postedAt),
                        onDelete: () => _delete(n),
                      ),
                    );
                  },
                  childCount: _notices.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.easeOutBack),
        child: FloatingActionButton.extended(
          onPressed: _showAddSheet,
          backgroundColor: const Color(0xFF7C3AED),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Post Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          elevation: 4,
        ),
      ),
    );
  }
}

// ─── Notice Card ──────────────────────────────────────────────────────────────
class _NoticeCard extends StatefulWidget {
  final Notice notice;
  final Color pColor;
  final IconData pIcon;
  final String pLabel;
  final String timeAgo;
  final VoidCallback onDelete;

  const _NoticeCard({
    required this.notice,
    required this.pColor,
    required this.pIcon,
    required this.pLabel,
    required this.timeAgo,
    required this.onDelete,
  });

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: widget.pColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: widget.onDelete,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Priority badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.pColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.pIcon, color: widget.pColor, size: 13),
                          const SizedBox(width: 4),
                          Text(widget.pLabel,
                            style: TextStyle(color: widget.pColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(widget.timeAgo,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(widget.notice.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onSurface,
                  )),
                // Expandable body
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: widget.notice.body.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(widget.notice.body,
                          style: TextStyle(color: cs.onSurfaceVariant, height: 1.5, fontSize: 14)),
                      )
                    : const SizedBox.shrink(),
                  crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 220),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: widget.pColor.withValues(alpha: 0.12),
                      child: Text(
                        widget.notice.postedBy.isNotEmpty ? widget.notice.postedBy[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 10, color: widget.pColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(widget.notice.postedBy,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: Icon(Icons.delete_outline_rounded, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none_rounded,
                size: 48, color: cs.primary),
            ),
            const SizedBox(height: 24),
            Text('No notices yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Tap the button below to post\nthe first announcement',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Could not load notices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable text field ──────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _Field({required this.controller, required this.label, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: cs.onSurfaceVariant),
        prefixIcon: Icon(icon, size: 20, color: cs.primary),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
