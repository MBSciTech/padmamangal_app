import 'package:flutter/material.dart';
import '../services/event_service.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  final _service = EventService();
  List<FamilyEvent> _events = [];
  bool _loading = true;
  String? _error;
  late TabController _tabs;

  // Calendar state
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchEvents();
      if (mounted) setState(() { _events = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Color _catColor(String cat) => Color(EventColors.colorFor(cat));

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'birthday':    return Icons.cake_rounded;
      case 'anniversary': return Icons.favorite_rounded;
      case 'festival':    return Icons.celebration_rounded;
      case 'meeting':     return Icons.groups_rounded;
      case 'reminder':    return Icons.alarm_rounded;
      default:            return Icons.event_rounded;
    }
  }

  String _catLabel(String cat) =>
    cat[0].toUpperCase() + cat.substring(1);

  String _countdown(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Past';
    if (diff.inDays == 0) return 'Today!';
    if (diff.inDays == 1) return 'Tomorrow';
    return 'In ${diff.inDays} days';
  }

  Color _countdownColor(DateTime dt) {
    final d = dt.difference(DateTime.now()).inDays;
    if (d <= 1) return const Color(0xFFEF5350);
    if (d <= 7) return const Color(0xFFFF9800);
    return const Color(0xFF4CAF50);
  }

  List<FamilyEvent> get _upcoming {
    final now = DateTime.now().subtract(const Duration(seconds: 1));
    return _events.where((e) => e.dateTime.isAfter(now)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<FamilyEvent> get _reminders =>
    _events.where((e) => e.category == 'reminder').toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  Set<int> _daysWithEvents(DateTime month) {
    return _events
        .where((e) => e.dateTime.year == month.year && e.dateTime.month == month.month)
        .map((e) => e.dateTime.day)
        .toSet();
  }

  List<FamilyEvent> _eventsOnDay(DateTime day) =>
    _events.where((e) =>
      e.dateTime.year == day.year &&
      e.dateTime.month == day.month &&
      e.dateTime.day == day.day).toList();

  // ─── Delete ───────────────────────────────────────────────────────────────
  Future<void> _delete(FamilyEvent ev) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Delete "${ev.title}"?'),
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
    if (ok == true) {
      await _service.deleteEvent(ev.id);
      setState(() => _events.removeWhere((x) => x.id == ev.id));
    }
  }

  // ─── Add event sheet ──────────────────────────────────────────────────────
  void _showAddSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    String category  = 'other';
    // Use ValueNotifier so the date display updates correctly across widget rebuilds
    final selDateNotifier = ValueNotifier<DateTime>(DateTime.now().add(const Duration(days: 1)));
    bool recurring   = false;
    bool posting     = false;
    String? err;
    final cats = ['birthday','anniversary','festival','meeting','reminder','other'];
    // Capture outer context NOW — needed for showDatePicker to find the Navigator
    final outerContext = context;

    showModalBottomSheet(
      context: outerContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: SingleChildScrollView(
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
                  Text('Add Event / Reminder',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    )),
                  const SizedBox(height: 16),

                  _SheetField(controller: titleCtrl, label: 'Title *', icon: Icons.title_rounded),
                  const SizedBox(height: 12),
                  _SheetField(controller: descCtrl, label: 'Description', icon: Icons.notes_rounded, maxLines: 2),
                  const SizedBox(height: 12),

                  // Date picker row — uses ValueListenableBuilder so display always reflects
                  // the real selected date even after the picker closes
                  ValueListenableBuilder<DateTime>(
                    valueListenable: selDateNotifier,
                    builder: (_, selDate, __) => GestureDetector(
                      onTap: () async {
                        // Use outerContext so the date picker Navigator works correctly
                        // even when called from inside a bottom sheet
                        final p = await showDatePicker(
                          context: outerContext,
                          initialDate: selDateNotifier.value,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                          builder: (_, child) => Theme(
                            data: Theme.of(outerContext).copyWith(
                              colorScheme: Theme.of(outerContext).colorScheme.copyWith(
                                primary: const Color(0xFF7C3AED),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (p != null) selDateNotifier.value = p;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.calendar_month_rounded,
                                color: Color(0xFF7C3AED), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Selected Date',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                    )),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selDate.day} ${_monthName(selDate.month)} ${selDate.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar_rounded, size: 18,
                              color: Color(0xFF7C3AED)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category chips
                  Text('Category',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    )),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: cats.map((c) {
                      final sel = category == c;
                      final col = Color(EventColors.colorFor(c));
                      return GestureDetector(
                        onTap: () => setM(() => category = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 130),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? col : col.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? col : col.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_catIconFor(c), size: 14, color: sel ? Colors.white : col),
                              const SizedBox(width: 5),
                              Text(_catLabel(c),
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: sel ? Colors.white : col,
                                )),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Recurring toggle
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 18,
                        color: Theme.of(ctx).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Repeat every year',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(ctx).colorScheme.onSurface,
                          ))),
                      Switch(
                        value: recurring,
                        onChanged: (v) => setM(() => recurring = v),
                        activeColor: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),

                  if (err != null) ...[
                    const SizedBox(height: 8),
                    Text(err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: posting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded),
                      label: Text(posting ? 'Adding…' : 'Add Event'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: posting ? null : () async {
                        final t = titleCtrl.text.trim();
                        if (t.isEmpty) { setM(() => err = 'Title is required'); return; }
                        setM(() { posting = true; err = null; });
                        try {
                          final ev = await _service.createEvent(
                            title: t,
                            description: descCtrl.text.trim(),
                            dateTime: selDateNotifier.value,   // use ValueNotifier's current value
                            category: category,
                            isRecurringYearly: recurring,
                          );
                          if (mounted) {
                            setState(() => _events.add(ev));
                            Navigator.pop(ctx);
                          }
                        } catch (e) {
                          setM(() { posting = false; err = 'Failed: $e'; });
                        }
                      },
                    ),

                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _catIconFor(String c) {
    switch (c) {
      case 'birthday':    return Icons.cake_rounded;
      case 'anniversary': return Icons.favorite_rounded;
      case 'festival':    return Icons.celebration_rounded;
      case 'meeting':     return Icons.groups_rounded;
      case 'reminder':    return Icons.alarm_rounded;
      default:            return Icons.event_rounded;
    }
  }

  String _monthName(int m) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[m - 1];
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: cs.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: cs.onSurface),
            title: Text(
              'Events & Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: cs.primary),
                onPressed: _load,
              ),
              const SizedBox(width: 4),
            ],
            bottom: TabBar(
              controller: _tabs,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.event_rounded, size: 20), text: 'Upcoming'),
                Tab(icon: Icon(Icons.alarm_rounded, size: 20), text: 'Reminders'),
              ],
            ),
          ),


          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: _load))
          else
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildUpcomingTab(),
                  _buildRemindersTab(),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFF7C3AED),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }

  Widget _buildUpcomingTab() {
    final list = _upcoming;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // ── Mini Calendar ─────────────────────────────────────────────────
        _MiniCalendar(
          month: _calendarMonth,
          selectedDay: _selectedDay,
          markedDays: _daysWithEvents(_calendarMonth),
          onMonthChanged: (m) => setState(() => _calendarMonth = m),
          onDayTapped: (d) => setState(() => _selectedDay = _selectedDay == d ? null : d),
        ),
        const SizedBox(height: 16),

        // Filtered by selected day or show all
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Text('${_selectedDay!.day} ${_monthName(_selectedDay!.month)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                    color: Theme.of(context).colorScheme.primary)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedDay = null),
                  child: Icon(Icons.close_rounded, size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          ..._eventsOnDay(_selectedDay!).map((e) => _EventCard(
            event: e,
            catColor: _catColor(e.category),
            catIcon: _catIcon(e.category),
            countdown: _countdown(e.dateTime),
            countdownColor: _countdownColor(e.dateTime),
            monthName: _monthName(e.dateTime.month),
            onDelete: () => _delete(e),
          )),
          if (_eventsOnDay(_selectedDay!).isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No events on this day',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
        ] else if (list.isEmpty)
          const _EmptyEventsState(isReminders: false)
        else ...[
          const _SectionLabel('Upcoming Events'),
          ...list.asMap().entries.map((e) => _EventCard(
            event: e.value,
            index: e.key,
            catColor: _catColor(e.value.category),
            catIcon: _catIcon(e.value.category),
            countdown: _countdown(e.value.dateTime),
            countdownColor: _countdownColor(e.value.dateTime),
            monthName: _monthName(e.value.dateTime.month),
            onDelete: () => _delete(e.value),
          )),
        ],
      ],
    );
  }

  Widget _buildRemindersTab() {
    final list = _reminders;
    if (list.isEmpty) return const _EmptyEventsState(isReminders: true);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const _SectionLabel('Reminders'),
        ...list.asMap().entries.map((e) => _EventCard(
          event: e.value,
          index: e.key,
          catColor: _catColor(e.value.category),
          catIcon: _catIcon(e.value.category),
          countdown: _countdown(e.value.dateTime),
          countdownColor: _countdownColor(e.value.dateTime),
          monthName: _monthName(e.value.dateTime.month),
          onDelete: () => _delete(e.value),
        )),
      ],
    );
  }
}

// ─── Mini Calendar ────────────────────────────────────────────────────────────
class _MiniCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDay;
  final Set<int> markedDays;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTapped;

  const _MiniCalendar({
    required this.month,
    required this.selectedDay,
    required this.markedDays,
    required this.onMonthChanged,
    required this.onDayTapped,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = (firstDay.weekday - 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded, color: cs.primary),
                onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)),
              ),
              Expanded(
                child: Text(
                  '${_months[month.month - 1]} ${month.year}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: cs.primary),
                onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)),
              ),
            ],
          ),
          // Weekday headers
          Row(
            children: _weekdays.map((d) => Expanded(
              child: Center(
                child: Text(d,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: cs.onSurfaceVariant)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (_, i) {
              if (i < startOffset) return const SizedBox.shrink();
              final day = i - startOffset + 1;
              final date = DateTime(month.year, month.month, day);
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
              final isSelected = selectedDay != null && date.year == selectedDay!.year &&
                  date.month == selectedDay!.month && date.day == selectedDay!.day;
              final hasEvent = markedDays.contains(day);

              return GestureDetector(
                onTap: () => onDayTapped(date),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : isToday
                                ? cs.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? cs.primary
                                    : cs.onSurface,
                          )),
                      ),
                    ),
                    if (hasEvent && !isSelected)
                      Positioned(
                        bottom: 2,
                        child: Container(
                          width: 4, height: 4,
                          decoration: const BoxDecoration(color: Color(0xFFFF9800), shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Event Card ───────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final FamilyEvent event;
  final int index;
  final Color catColor;
  final IconData catIcon;
  final String countdown;
  final Color countdownColor;
  final String monthName;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    this.index = 0,
    required this.catColor,
    required this.catIcon,
    required this.countdown,
    required this.countdownColor,
    required this.monthName,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(event.id),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1-v)*18), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: catColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onLongPress: onDelete,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Date box
                  Container(
                    width: 50, height: 58,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${event.dateTime.day}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: catColor)),
                        Text(monthName,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: catColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(catIcon, size: 13, color: catColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(event.title,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (event.description.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(event.description,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: countdownColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(countdown,
                                style: TextStyle(fontSize: 11, color: countdownColor, fontWeight: FontWeight.bold)),
                            ),
                            if (event.isRecurringYearly) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.repeat_rounded, size: 12, color: cs.onSurfaceVariant),
                            ],
                            const Spacer(),
                            GestureDetector(
                              onTap: onDelete,
                              child: Icon(Icons.delete_outline_rounded, size: 16,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
    child: Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1,
        color: Theme.of(context).colorScheme.primary)),
  );
}

// ─── Empty states ─────────────────────────────────────────────────────────────
class _EmptyEventsState extends StatelessWidget {
  final bool isReminders;
  const _EmptyEventsState({required this.isReminders});

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
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(isReminders ? Icons.alarm_off_rounded : Icons.event_available_rounded,
                size: 44, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(isReminders ? 'No reminders yet' : 'No upcoming events',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(isReminders ? 'Add a reminder using the button below' : 'Add an event using the button below',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────
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
            Text('Could not load events',
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

// ─── Reusable sheet text field ────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;
  const _SheetField({required this.controller, required this.label, required this.icon, this.maxLines = 1});

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
