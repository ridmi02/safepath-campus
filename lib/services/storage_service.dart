import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an ID card image [file] for the given [uid].
  ///
  /// The file is stored at `/id_cards/{uid}/id_card.jpg` in Firebase Storage.
  /// Returns the publicly accessible download URL on success.
  Future<String> uploadIdCardImage(String uid, File file) async {
    try {
      final Reference ref = _storage.ref().child('id_cards/$uid/id_card.jpg');

      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } on FirebaseException catch (e) {
      throw 'Failed to upload ID card image: ${e.message}';
    } catch (e) {
      throw 'An unexpected error occurred while uploading. Please try again.';
    }
  }
}
