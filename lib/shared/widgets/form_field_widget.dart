import 'package:flutter/material.dart';
import 'package:cockado_enrollapp/core/theme/app_colors.dart';

class FormFieldWidget extends StatefulWidget {
  const FormFieldWidget({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.leadingIcon,
    this.trailing,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.validator,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? leadingIcon;
  final Widget? trailing;
  final TextInputType keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  State<FormFieldWidget> createState() => _FormFieldWidgetState();
}

class _FormFieldWidgetState extends State<FormFieldWidget> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: AppColors.blue, width: 1)
                : const Border.fromBorderSide(BorderSide.none),
          ),
          child: Row(
            children: [
              if (widget.leadingIcon != null) ...[
                const SizedBox(width: 14),
                Icon(
                  widget.leadingIcon,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 14),
              Expanded(
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: widget.keyboardType,
                  readOnly: widget.readOnly,
                  onTap: widget.onTap,
                  onChanged: widget.onChanged,
                  validator: widget.validator,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: true,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  cursorColor: AppColors.blue,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }
}
