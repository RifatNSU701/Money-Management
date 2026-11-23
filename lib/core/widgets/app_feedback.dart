import 'package:flutter/material.dart';

class AppFeedback {
  AppFeedback._();

  /// High-contrast floating error banner (white text on crimson red).
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: const Color(0xFFC62828),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  /// Floating success / undo banner.
  static void showInfo(
      BuildContext context,
      String message, {
        VoidCallback? onUndo,
      }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          action: onUndo != null
              ? SnackBarAction(
            label: 'UNDO',
            textColor: const Color(0xFF38BDF8),
            onPressed: onUndo,
          )
              : null,
        ),
      );
  }

  /// Standard confirmation dialog for deleting records, bills, categories, or members.
  static Future<bool> confirmDelete(
      BuildContext context, {
        required String title,
        required String message,
        String confirmLabel = 'Delete',
      }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// High-friction confirmation requiring typed "DELETE" for permanent account wipe.
  static Future<bool> confirmTypedDelete(
      BuildContext context, {
        required String title,
        required String message,
        String requiredWord = 'DELETE',
      }) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final matches = controller.text.trim() == requiredWord;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                Text(
                  'Type $requiredWord to confirm:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: requiredWord,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                ),
                onPressed: matches ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Delete Permanently'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    return result ?? false;
  }
}