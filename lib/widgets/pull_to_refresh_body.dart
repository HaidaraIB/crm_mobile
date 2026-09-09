import 'package:flutter/material.dart';

/// Shared pull-to-refresh wrapper that works for short content (loading / empty / error)
/// and for list data without nested scrollables.
class PullToRefreshBody extends StatelessWidget {
  const PullToRefreshBody({
    super.key,
    required this.onRefresh,
    required this.child,
    this.padding,
    this.centerChild = true,
  })  : itemCount = null,
        itemBuilder = null,
        separatorBuilder = null,
        listPadding = null,
        _mode = _PullToRefreshMode.viewport;

  /// Centered spinner without [RefreshIndicator].
  ///
  /// Wrapping a [CircularProgressIndicator] in the viewport constructor stacks
  /// Material's refresh spinner on top of the child spinner.
  const PullToRefreshBody.loading({
    super.key,
    this.child = const CircularProgressIndicator(),
  })  : onRefresh = _noopRefresh,
        padding = null,
        centerChild = true,
        itemCount = null,
        itemBuilder = null,
        separatorBuilder = null,
        listPadding = null,
        _mode = _PullToRefreshMode.loading;

  /// Single scroll view list under [RefreshIndicator].
  const PullToRefreshBody.list({
    super.key,
    required this.onRefresh,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.separatorBuilder,
    this.listPadding,
  })  : child = null,
        padding = null,
        centerChild = false,
        _mode = _PullToRefreshMode.list;

  static Future<void> _noopRefresh() async {}

  final Future<void> Function() onRefresh;
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final bool centerChild;

  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final EdgeInsetsGeometry? listPadding;

  final _PullToRefreshMode _mode;

  @override
  Widget build(BuildContext context) {
    if (_mode == _PullToRefreshMode.loading) {
      return Center(child: child ?? const CircularProgressIndicator());
    }

    if (_mode == _PullToRefreshMode.list) {
      final count = itemCount!;
      final builder = itemBuilder!;
      final sep = separatorBuilder;

      return RefreshIndicator(
        onRefresh: onRefresh,
        child: sep != null
            ? ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: listPadding,
                itemCount: count,
                itemBuilder: builder,
                separatorBuilder: sep,
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: listPadding,
                itemCount: count,
                itemBuilder: builder,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: centerChild
                  ? Center(child: child)
                  : child,
            ),
          );
        },
      ),
    );
  }
}

enum _PullToRefreshMode { viewport, list, loading }
