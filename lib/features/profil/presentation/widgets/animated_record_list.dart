import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [AnimatedList] that diffs its `items` (by id) whenever the parent rebuilds:
/// inserted items slide + fade in, removed items collapse + fade out, edited
/// items are rebuilt in place. Every row is wrapped in a swipe-to-delete
/// [Dismissible] (red background, trash icon, haptic feedback).
///
/// When a row is swiped away it is removed from the list synchronously (as
/// [Dismissible] requires) and [onDismissed] is invoked, so the parent can
/// offer an "Undo" before committing the deletion. Re-supplying the item
/// afterwards re-inserts it with an animation.
class AnimatedRecordList<T> extends StatefulWidget {
  const AnimatedRecordList({
    super.key,
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    required this.onDismissed,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 112),
  });

  final List<T> items;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final void Function(T item) onDismissed;
  final EdgeInsets padding;

  @override
  State<AnimatedRecordList<T>> createState() => _AnimatedRecordListState<T>();
}

class _AnimatedRecordListState<T> extends State<AnimatedRecordList<T>> {
  final _listKey = GlobalKey<AnimatedListState>();
  late List<T> _items;

  @override
  void initState() {
    super.initState();
    _items = List<T>.of(widget.items);
  }

  @override
  void didUpdateWidget(covariant AnimatedRecordList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(widget.items);
  }

  void _sync(List<T> next) {
    final list = _listKey.currentState;
    if (list == null) {
      _items = List<T>.of(next);
      return;
    }
    final nextIds = next.map(widget.idOf).toSet();

    // 1. Removals (from the end so indices stay valid).
    for (var i = _items.length - 1; i >= 0; i--) {
      if (!nextIds.contains(widget.idOf(_items[i]))) {
        final removed = _items.removeAt(i);
        list.removeItem(
          i,
          (context, animation) => _animated(animation, widget.itemBuilder(context, removed)),
          duration: const Duration(milliseconds: 280),
        );
      }
    }

    // 2. Insertions at their target positions.
    final currentIds = _items.map(widget.idOf).toSet();
    for (var i = 0; i < next.length; i++) {
      if (!currentIds.contains(widget.idOf(next[i]))) {
        final at = i.clamp(0, _items.length);
        _items.insert(at, next[i]);
        list.insertItem(at, duration: const Duration(milliseconds: 340));
      }
    }

    // 3. Adopt the new order / edited values (same ids, same length).
    _items = List<T>.of(next);
  }

  Widget _animated(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return SizeTransition(
      sizeFactor: curved,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.25, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      ),
    );
  }

  void _handleDismissed(int index) {
    if (index < 0 || index >= _items.length) return;
    final item = _items.removeAt(index);
    // Dismissible must leave the tree in this very frame.
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => const SizedBox.shrink(),
      duration: Duration.zero,
    );
    widget.onDismissed(item);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      padding: widget.padding,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index, animation) {
        if (index >= _items.length) return const SizedBox.shrink();
        final item = _items[index];
        final id = widget.idOf(item);
        return _animated(
          animation,
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('dismiss_$id'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                HapticFeedback.mediumImpact();
                return true;
              },
              onDismissed: (_) => _handleDismissed(_items.indexWhere((e) => widget.idOf(e) == id)),
              background: const _DeleteBackground(),
              child: widget.itemBuilder(context, item),
            ),
          ),
        );
      },
    );
  }
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
    );
  }
}
