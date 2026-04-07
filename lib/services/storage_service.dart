import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an ID card image [file] for the given [uid].
  ///
  /// The file is stored at `/id_cards/{uid}/id_card.jpg` in Firebase Storage.
  /// Returns the publicly accessible download URL on success.
  Future<String> uploadIdCardImage(String uid, File file) async {
    // ignore: avoid_print
    print("=== STORAGE: uploadIdCardImage called for UID: $uid ===");
    // ignore: avoid_print
    print("=== STORAGE: File path: ${file.path} ===");
    try {
      final Reference ref = _storage.ref().child('id_cards/$uid/id_card.jpg');
      // ignore: avoid_print
      print("=== STORAGE: Storage ref created. Bucket: ${_storage.bucket} ===");

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      // ignore: avoid_print
      print("=== STORAGE: Upload task started, awaiting completion... ===");

      final TaskSnapshot snapshot = await uploadTask;
      // ignore: avoid_print
      print("=== STORAGE: Upload complete. Bytes transferred: ${snapshot.bytesTransferred} ===");

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      // ignore: avoid_print
      print("=== STORAGE: Download URL obtained: $downloadUrl ===");

      return downloadUrl;
    } on FirebaseException catch (e) {
      // ignore: avoid_print
      print("=== STORAGE FirebaseException ===");
      // ignore: avoid_print
      print("Code: ${e.code}");
      // ignore: avoid_print
      print("Message: ${e.message}");
      // ignore: avoid_print
      print("Plugin: ${e.plugin}");
      // ignore: avoid_print
      print("=== END STORAGE FirebaseException ===");
      throw 'Failed to upload ID card image: [${e.code}] ${e.message}';
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print("=== STORAGE unexpected error ===");
      // ignore: avoid_print
      print("Error: $e");
      // ignore: avoid_print
      print("Type: ${e.runtimeType}");
      // ignore: avoid_print
      print("Stack: $stackTrace");
      // ignore: avoid_print
      print("=== END STORAGE unexpected error ===");
      throw 'An unexpected error occurred while uploading: $e';
    }
  }
}
