import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// File scelto per l'upload (bytes in memoria: funziona anche senza path).
final class PickedDocumentFile {
  const PickedDocumentFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Astrazione sul selettore di file: nei test si sostituisce con un fake.
abstract interface class DocumentFilePicker {
  Future<PickedDocumentFile?> pick();
}

final class SystemDocumentFilePicker implements DocumentFilePicker {
  @override
  Future<PickedDocumentFile?> pick() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    final file = files.first;
    return PickedDocumentFile(name: file.name, bytes: await file.readAsBytes());
  }
}

final documentFilePickerProvider = Provider<DocumentFilePicker>(
  (ref) => SystemDocumentFilePicker(),
);
