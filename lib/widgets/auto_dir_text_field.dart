import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/utils/input_text_direction.dart';

InputDecoration? _decorationFor(InputDecoration? decoration, TextDirection dir) {
  if (decoration == null || dir != TextDirection.ltr) return decoration;
  final hint = decoration.hintText;
  if (hint == null) return decoration;
  final pinned = ltrAnchoredHint(hint);
  if (identical(pinned, hint)) return decoration;
  return decoration.copyWith(hintText: pinned);
}

class AutoDirTextField extends StatefulWidget {
  const AutoDirTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.style,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
    this.cursorColor,
    this.scrollController,
    this.scrollPhysics,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onTap,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final Color? cursorColor;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final bool autocorrect;
  final bool enableSuggestions;
  final GestureTapCallback? onTap;

  @override
  State<AutoDirTextField> createState() => _AutoDirTextFieldState();
}

class _AutoDirTextFieldState extends State<AutoDirTextField> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.controller?.text ?? '';
    widget.controller?.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant AutoDirTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromController);
      _text = widget.controller?.text ?? _text;
      widget.controller?.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final next = widget.controller?.text ?? '';
    if (next != _text) setState(() => _text = next);
  }

  @override
  Widget build(BuildContext context) {
    final dir = resolveInputTextDirection(
      context,
      text: _text,
      textDirection: widget.textDirection,
      keyboardType: widget.keyboardType,
    );
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      decoration: _decorationFor(widget.decoration, dir),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      textDirection: dir,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      style: widget.style,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: (value) {
        if (widget.controller == null) setState(() => _text = value);
        widget.onChanged?.call(value);
      },
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      cursorColor: widget.cursorColor,
      scrollController: widget.scrollController,
      scrollPhysics: widget.scrollPhysics,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      onTap: widget.onTap,
    );
  }
}

class AutoDirTextFormField extends StatefulWidget {
  const AutoDirTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.decoration,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.style,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.enabled,
    this.validator,
    this.autovalidateMode,
    this.onSaved,
    this.onTap,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final FormFieldSetter<String>? onSaved;
  final GestureTapCallback? onTap;

  @override
  State<AutoDirTextFormField> createState() => _AutoDirTextFormFieldState();
}

class _AutoDirTextFormFieldState extends State<AutoDirTextFormField> {
  String _text = '';

  @override
  void initState() {
    super.initState();
    _text = widget.controller?.text ?? widget.initialValue ?? '';
    widget.controller?.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant AutoDirTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_syncFromController);
      _text = widget.controller?.text ?? widget.initialValue ?? _text;
      widget.controller?.addListener(_syncFromController);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final next = widget.controller?.text ?? '';
    if (next != _text) setState(() => _text = next);
  }

  @override
  Widget build(BuildContext context) {
    final dir = resolveInputTextDirection(
      context,
      text: _text,
      textDirection: widget.textDirection,
      keyboardType: widget.keyboardType,
    );
    return TextFormField(
      controller: widget.controller,
      initialValue: widget.initialValue,
      focusNode: widget.focusNode,
      decoration: _decorationFor(widget.decoration, dir),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      textDirection: dir,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      style: widget.style,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      onChanged: (value) {
        if (widget.controller == null) setState(() => _text = value);
        widget.onChanged?.call(value);
      },
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: widget.inputFormatters,
      enabled: widget.enabled,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      onSaved: widget.onSaved,
      onTap: widget.onTap,
    );
  }
}
