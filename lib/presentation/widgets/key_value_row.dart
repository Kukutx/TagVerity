import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    required this.label,
    required this.value,
    super.key,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '—' : value)),
          if (copyable && value.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '复制',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
