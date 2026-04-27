import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musix/services/firestore_user_data_service.dart';

void main() {
  test(
    'buildUserDocumentSeedData preserves existing liked and disliked lists',
    () {
      final Map<String, dynamic> data =
          FirestoreUserDataService.buildUserDocumentSeedData(
            email: '  hello.sachinthalakshan@gmail.com  ',
            existingLikedSongs: <String>['song-a'],
            existingDislikedSongs: <String>['song-b'],
          );

      expect(data['email'], 'hello.sachinthalakshan@gmail.com');
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data.containsKey('likedSongs'), isFalse);
      expect(data.containsKey('dislikedSongs'), isFalse);
    },
  );

  test(
    'buildUserDocumentSeedData seeds empty arrays for a new user document',
    () {
      final Map<String, dynamic> data =
          FirestoreUserDataService.buildUserDocumentSeedData(
            email: 'listener@example.com',
            existingLikedSongs: null,
            existingDislikedSongs: null,
          );

      expect(data['email'], 'listener@example.com');
      expect(data['updatedAt'], isA<FieldValue>());
      expect(data['likedSongs'], isEmpty);
      expect(data['dislikedSongs'], isEmpty);
    },
  );

  test('buildUserDocumentSeedData only repairs missing array fields', () {
    final Map<String, dynamic> data =
        FirestoreUserDataService.buildUserDocumentSeedData(
          email: 'listener@example.com',
          existingLikedSongs: const <String>['song-a'],
          existingDislikedSongs: 'invalid',
        );

    expect(data.containsKey('likedSongs'), isFalse);
    expect(data['dislikedSongs'], isEmpty);
  });
}
