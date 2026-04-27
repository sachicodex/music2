import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../src/models.dart';

class FirestoreUserDataService {
  FirestoreUserDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  bool get supportsCloudSync => true;

  bool get _useRestApiOnWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  String? get currentUserId => _firebaseAuth.currentUser?.uid;

  @visibleForTesting
  static Map<String, dynamic> buildUserDocumentSeedData({
    required String email,
    Object? existingLikedSongs,
    Object? existingDislikedSongs,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'email': email.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existingLikedSongs is! List<dynamic>) {
      data['likedSongs'] = const <String>[];
    }
    if (existingDislikedSongs is! List<dynamic>) {
      data['dislikedSongs'] = const <String>[];
    }
    return data;
  }

  Stream<FirestoreUserData> watchCurrentUserData({
    Duration windowsPollInterval = const Duration(seconds: 3),
  }) async* {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      yield const FirestoreUserData.empty();
      return;
    }

    if (_useRestApiOnWindows) {
      yield await loadCurrentUserData();
      while (_firebaseAuth.currentUser?.uid == user.uid) {
        await Future<void>.delayed(windowsPollInterval);
        if (_firebaseAuth.currentUser?.uid != user.uid) {
          break;
        }
        yield await loadCurrentUserData();
      }
      return;
    }

    await ensureCurrentUserDocument();
    yield* _watchCurrentUserDataFirestore(user);
  }

  Future<void> ensureCurrentUserDocument() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    if (_useRestApiOnWindows) {
      try {
        final _FirestoreRestUserDocument existing = await _loadUserDocumentRest(
          user,
        );
        await _writeUserDocumentRest(
          user: user,
          likedSongIds: existing.likedSongIds,
          dislikedSongIds: existing.dislikedSongIds,
        );
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not prepare your Firestore profile.',
        );
      }
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> userDoc = _userDocument(
        user.uid,
      );
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await userDoc
          .get();
      final Map<String, dynamic> existingData =
          snapshot.data() ?? <String, dynamic>{};

      await userDoc.set(
        buildUserDocumentSeedData(
          email: user.email?.trim() ?? '',
          existingLikedSongs: existingData['likedSongs'],
          existingDislikedSongs: existingData['dislikedSongs'],
        ),
        SetOptions(merge: true),
      );
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not prepare your Firestore profile.',
      );
    }
  }

  Future<FirestoreUserData> loadCurrentUserData() async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return const FirestoreUserData.empty();
    }

    if (_useRestApiOnWindows) {
      try {
        final _FirestoreRestUserDocument userData = await _loadUserDocumentRest(
          user,
        );
        final List<UserPlaylist> playlists = await _loadPlaylistsRest(user);
        return FirestoreUserData(
          email: userData.email.trim(),
          likedSongIds: userData.likedSongIds,
          dislikedSongIds: userData.dislikedSongIds,
          playlists: playlists,
        );
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not load your Firestore library.',
        );
      }
    }

    await ensureCurrentUserDocument();

    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await _userDocument(user.uid).get();
      final QuerySnapshot<Map<String, dynamic>> playlistsSnapshot =
          await _playlistsCollection(user.uid).get();

      final Map<String, dynamic> userData =
          userSnapshot.data() ?? <String, dynamic>{};
      final List<UserPlaylist> playlists =
          playlistsSnapshot.docs
              .map(_playlistFromSnapshot)
              .toList(growable: false)
            ..sort(_sortPlaylists);

      return FirestoreUserData(
        email: (userData['email'] as String? ?? user.email ?? '').trim(),
        likedSongIds: _readSongIds(userData['likedSongs']),
        dislikedSongIds: _readSongIds(userData['dislikedSongs']),
        playlists: playlists,
      );
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not load your Firestore library.',
      );
    }
  }

  Future<void> setLikedSong({
    required String songId,
    required bool isLiked,
  }) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    if (_useRestApiOnWindows) {
      try {
        final _FirestoreRestUserDocument existing = await _loadUserDocumentRest(
          user,
        );
        final Set<String> likedSongIds = Set<String>.from(
          existing.likedSongIds,
        );
        final Set<String> dislikedSongIds = Set<String>.from(
          existing.dislikedSongIds,
        );
        if (isLiked) {
          likedSongIds.add(songId);
        } else {
          likedSongIds.remove(songId);
        }
        dislikedSongIds.remove(songId);
        await _writeUserDocumentRest(
          user: user,
          likedSongIds: likedSongIds,
          dislikedSongIds: dislikedSongIds,
        );
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not update liked songs in Firestore.',
        );
      }
      return;
    }

    await ensureCurrentUserDocument();

    try {
      final WriteBatch batch = _firestore.batch();
      final DocumentReference<Map<String, dynamic>> userDoc = _userDocument(
        user.uid,
      );

      batch.set(userDoc, <String, dynamic>{
        'email': user.email?.trim() ?? '',
      }, SetOptions(merge: true));
      batch.update(userDoc, <String, dynamic>{
        'likedSongs': isLiked
            ? FieldValue.arrayUnion(<String>[songId])
            : FieldValue.arrayRemove(<String>[songId]),
        'dislikedSongs': FieldValue.arrayRemove(<String>[songId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not update liked songs in Firestore.',
      );
    }
  }

  Future<void> setDislikedSong({
    required String songId,
    required bool isDisliked,
  }) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    if (_useRestApiOnWindows) {
      try {
        final _FirestoreRestUserDocument existing = await _loadUserDocumentRest(
          user,
        );
        final Set<String> likedSongIds = Set<String>.from(
          existing.likedSongIds,
        );
        final Set<String> dislikedSongIds = Set<String>.from(
          existing.dislikedSongIds,
        );
        likedSongIds.remove(songId);
        if (isDisliked) {
          dislikedSongIds.add(songId);
        } else {
          dislikedSongIds.remove(songId);
        }
        await _writeUserDocumentRest(
          user: user,
          likedSongIds: likedSongIds,
          dislikedSongIds: dislikedSongIds,
        );
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not update disliked songs in Firestore.',
        );
      }
      return;
    }

    await ensureCurrentUserDocument();

    try {
      final WriteBatch batch = _firestore.batch();
      final DocumentReference<Map<String, dynamic>> userDoc = _userDocument(
        user.uid,
      );

      batch.set(userDoc, <String, dynamic>{
        'email': user.email?.trim() ?? '',
      }, SetOptions(merge: true));
      batch.update(userDoc, <String, dynamic>{
        'dislikedSongs': isDisliked
            ? FieldValue.arrayUnion(<String>[songId])
            : FieldValue.arrayRemove(<String>[songId]),
        'likedSongs': FieldValue.arrayRemove(<String>[songId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not update disliked songs in Firestore.',
      );
    }
  }

  Future<void> upsertPlaylist(UserPlaylist playlist) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    final List<String> sanitizedSongIds = playlist.songIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (_useRestApiOnWindows) {
      try {
        await _setRestDocument(
          _playlistDocumentPath(user.uid, playlist.id),
          fields: <String, dynamic>{
            'name': _stringField(playlist.name.trim()),
            'songIds': _stringArrayField(sanitizedSongIds),
            'createdAt': _timestampField(playlist.createdAt),
            'updatedAt': _timestampField(playlist.updatedAt),
          },
          updateMaskFieldPaths: const <String>[
            'name',
            'songIds',
            'createdAt',
            'updatedAt',
          ],
        );
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not save the playlist to Firestore.',
        );
      }
      return;
    }

    await ensureCurrentUserDocument();

    try {
      await _playlistsCollection(
        user.uid,
      ).doc(playlist.id).set(<String, dynamic>{
        'name': playlist.name.trim(),
        'songIds': sanitizedSongIds,
        'createdAt': Timestamp.fromDate(playlist.createdAt),
        'updatedAt': Timestamp.fromDate(playlist.updatedAt),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not save the playlist to Firestore.',
      );
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final User? user = _firebaseAuth.currentUser;
    if (user == null) {
      return;
    }

    if (_useRestApiOnWindows) {
      try {
        await _deleteRestDocument(_playlistDocumentPath(user.uid, playlistId));
      } on FirestoreUserDataException {
        rethrow;
      } catch (_) {
        throw const FirestoreUserDataException(
          'Could not delete the playlist from Firestore.',
        );
      }
      return;
    }

    try {
      await _playlistsCollection(user.uid).doc(playlistId).delete();
    } on FirebaseException catch (error) {
      throw FirestoreUserDataException(_friendlyMessage(error));
    } catch (_) {
      throw const FirestoreUserDataException(
        'Could not delete the playlist from Firestore.',
      );
    }
  }

  Future<_FirestoreRestUserDocument> _loadUserDocumentRest(User user) async {
    final Map<String, dynamic>? document = await _getRestDocument(
      _userDocumentPath(user.uid),
    );
    if (document == null) {
      return _FirestoreRestUserDocument(
        email: user.email?.trim() ?? '',
        likedSongIds: <String>{},
        dislikedSongIds: <String>{},
      );
    }
    final Map<String, dynamic> fields =
        (document['fields'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return _FirestoreRestUserDocument(
      email: _readRestStringField(fields['email']) ?? user.email?.trim() ?? '',
      likedSongIds: _readRestStringArrayField(fields['likedSongs']),
      dislikedSongIds: _readRestStringArrayField(fields['dislikedSongs']),
    );
  }

  Future<List<UserPlaylist>> _loadPlaylistsRest(User user) async {
    final List<Map<String, dynamic>> documents = await _listRestDocuments(
      _playlistsCollectionPath(user.uid),
    );
    final List<UserPlaylist> playlists =
        documents.map(_playlistFromRestDocument).toList(growable: false)
          ..sort(_sortPlaylists);
    return playlists;
  }

  Future<void> _writeUserDocumentRest({
    required User user,
    required Set<String> likedSongIds,
    required Set<String> dislikedSongIds,
  }) async {
    await _setRestDocument(
      _userDocumentPath(user.uid),
      fields: <String, dynamic>{
        'email': _stringField(user.email?.trim() ?? ''),
        'likedSongs': _stringArrayField(likedSongIds.toList(growable: false)),
        'dislikedSongs': _stringArrayField(
          dislikedSongIds.toList(growable: false),
        ),
        'updatedAt': _timestampField(DateTime.now().toUtc()),
      },
      updateMaskFieldPaths: const <String>[
        'email',
        'likedSongs',
        'dislikedSongs',
        'updatedAt',
      ],
    );
  }

  Stream<FirestoreUserData> _watchCurrentUserDataFirestore(User user) {
    final StreamController<FirestoreUserData> controller =
        StreamController<FirestoreUserData>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    userSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    playlistsSubscription;
    Map<String, dynamic> currentUserData = <String, dynamic>{};
    List<UserPlaylist> currentPlaylists = <UserPlaylist>[];
    bool hasUserSnapshot = false;
    bool hasPlaylistsSnapshot = false;

    void emitIfReady() {
      if (!hasUserSnapshot || !hasPlaylistsSnapshot || controller.isClosed) {
        return;
      }
      controller.add(
        FirestoreUserData(
          email: (currentUserData['email'] as String? ?? user.email ?? '')
              .trim(),
          likedSongIds: _readSongIds(currentUserData['likedSongs']),
          dislikedSongIds: _readSongIds(currentUserData['dislikedSongs']),
          playlists: currentPlaylists,
        ),
      );
    }

    FirestoreUserDataException toFirestoreException(Object error) {
      if (error is FirestoreUserDataException) {
        return error;
      }
      if (error is FirebaseException) {
        return FirestoreUserDataException(_friendlyMessage(error));
      }
      return const FirestoreUserDataException(
        'Could not load your Firestore library.',
      );
    }

    userSubscription = _userDocument(user.uid).snapshots().listen(
      (DocumentSnapshot<Map<String, dynamic>> snapshot) {
        currentUserData = snapshot.data() ?? <String, dynamic>{};
        hasUserSnapshot = true;
        emitIfReady();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(toFirestoreException(error), stackTrace);
        }
      },
    );

    playlistsSubscription = _playlistsCollection(user.uid).snapshots().listen(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        currentPlaylists =
            snapshot.docs.map(_playlistFromSnapshot).toList(growable: false)
              ..sort(_sortPlaylists);
        hasPlaylistsSnapshot = true;
        emitIfReady();
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(toFirestoreException(error), stackTrace);
        }
      },
    );

    controller.onCancel = () async {
      await userSubscription?.cancel();
      await playlistsSubscription?.cancel();
    };

    return controller.stream;
  }

  Future<Map<String, dynamic>?> _getRestDocument(String path) async {
    final _RestResponse response = await _sendRestRequest(
      'GET',
      _documentUri(path),
    );
    if (response.statusCode == HttpStatus.notFound) {
      return null;
    }
    _throwIfRestError(
      response,
      fallbackMessage: 'Could not load your Firestore library.',
    );
    final Object? decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<List<Map<String, dynamic>>> _listRestDocuments(String path) async {
    final _RestResponse response = await _sendRestRequest(
      'GET',
      _documentUri(path),
    );
    if (response.statusCode == HttpStatus.notFound) {
      return <Map<String, dynamic>>[];
    }
    _throwIfRestError(
      response,
      fallbackMessage: 'Could not load your Firestore library.',
    );
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }
    final List<dynamic> rawDocuments =
        decoded['documents'] as List<dynamic>? ?? <dynamic>[];
    return rawDocuments.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );
  }

  Future<void> _setRestDocument(
    String path, {
    required Map<String, dynamic> fields,
    List<String>? updateMaskFieldPaths,
  }) async {
    final _RestResponse response = await _sendRestRequest(
      'PATCH',
      _documentUri(path, updateMaskFieldPaths: updateMaskFieldPaths),
      body: jsonEncode(<String, dynamic>{'fields': fields}),
      contentType: 'application/json',
    );
    _throwIfRestError(
      response,
      fallbackMessage: 'Could not save the playlist to Firestore.',
    );
  }

  Future<void> _deleteRestDocument(String path) async {
    final _RestResponse response = await _sendRestRequest(
      'DELETE',
      _documentUri(path),
    );
    if (response.statusCode == HttpStatus.notFound) {
      return;
    }
    _throwIfRestError(
      response,
      fallbackMessage: 'Could not delete the playlist from Firestore.',
    );
  }

  Future<_RestResponse> _sendRestRequest(
    String method,
    Uri uri, {
    String? body,
    String? contentType,
  }) async {
    final User? user = _firebaseAuth.currentUser;
    final String? token = await user?.getIdToken();
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (contentType != null) {
        request.headers.set(HttpHeaders.contentTypeHeader, contentType);
      }
      if (body != null && body.isNotEmpty) {
        request.write(body);
      }
      final HttpClientResponse response = await request.close();
      final String responseBody = await utf8.decoder.bind(response).join();
      return _RestResponse(statusCode: response.statusCode, body: responseBody);
    } on SocketException {
      throw const FirestoreUserDataException(
        'Firestore is temporarily unavailable. Please try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  void _throwIfRestError(
    _RestResponse response, {
    required String fallbackMessage,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    final String? message = _extractRestErrorMessage(response.body);
    throw FirestoreUserDataException(message ?? fallbackMessage);
  }

  String? _extractRestErrorMessage(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final Map<String, dynamic>? error =
          decoded['error'] as Map<String, dynamic>?;
      if (error == null) {
        return null;
      }
      final String status = (error['status'] as String? ?? '').trim();
      final String message = (error['message'] as String? ?? '').trim();
      switch (status) {
        case 'PERMISSION_DENIED':
          return 'Permission denied. Check your Firestore security rules.';
        case 'UNAVAILABLE':
          return 'Firestore is temporarily unavailable. Please try again.';
        case 'NOT_FOUND':
          return 'Requested Firestore data was not found.';
        case 'FAILED_PRECONDITION':
          return 'Firestore setup is incomplete. Check indexes and rules.';
        default:
          return message.isEmpty ? null : message;
      }
    } catch (_) {
      return null;
    }
  }

  UserPlaylist _playlistFromRestDocument(Map<String, dynamic> document) {
    final String namePath = (document['name'] as String? ?? '').trim();
    final String id = namePath.isEmpty ? '' : namePath.split('/').last;
    final Map<String, dynamic> fields =
        (document['fields'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return UserPlaylist(
      id: id,
      name: _readRestStringField(fields['name']) ?? 'Untitled Playlist',
      songIds: _readRestStringArrayField(
        fields['songIds'],
      ).toList(growable: false),
      createdAt: _readRestDateTimeField(fields['createdAt']),
      updatedAt: _readRestDateTimeField(fields['updatedAt']),
    );
  }

  String? _readRestStringField(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }
    final Object? stringValue = value['stringValue'];
    if (stringValue is String) {
      return stringValue;
    }
    return null;
  }

  Set<String> _readRestStringArrayField(Object? value) {
    if (value is! Map<String, dynamic>) {
      return <String>{};
    }
    final Map<String, dynamic>? arrayValue =
        value['arrayValue'] as Map<String, dynamic>?;
    final List<dynamic> values =
        arrayValue?['values'] as List<dynamic>? ?? <dynamic>[];
    return values
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> item) => item['stringValue'] as String? ?? '',
        )
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
  }

  DateTime _readRestDateTimeField(Object? value) {
    if (value is! Map<String, dynamic>) {
      return DateTime.now();
    }
    final String raw =
        (value['timestampValue'] as String? ??
                value['stringValue'] as String? ??
                '')
            .trim();
    return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
  }

  Map<String, dynamic> _stringField(String value) {
    return <String, dynamic>{'stringValue': value};
  }

  Map<String, dynamic> _stringArrayField(List<String> values) {
    if (values.isEmpty) {
      return <String, dynamic>{'arrayValue': <String, dynamic>{}};
    }
    return <String, dynamic>{
      'arrayValue': <String, dynamic>{
        'values': values
            .map((String value) => <String, dynamic>{'stringValue': value})
            .toList(growable: false),
      },
    };
  }

  Map<String, dynamic> _timestampField(DateTime value) {
    return <String, dynamic>{'timestampValue': value.toUtc().toIso8601String()};
  }

  Uri _documentUri(String path, {List<String>? updateMaskFieldPaths}) {
    final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
    final StringBuffer buffer = StringBuffer(
      'https://firestore.googleapis.com'
      '/v1/projects/${options.projectId}/databases/(default)/documents/$path',
    );
    if (updateMaskFieldPaths != null && updateMaskFieldPaths.isNotEmpty) {
      buffer.write('?');
      for (int index = 0; index < updateMaskFieldPaths.length; index++) {
        if (index > 0) {
          buffer.write('&');
        }
        buffer.write(
          'updateMask.fieldPaths='
          '${Uri.encodeQueryComponent(updateMaskFieldPaths[index])}',
        );
      }
    }
    return Uri.parse(buffer.toString());
  }

  String _userDocumentPath(String userId) => 'users/$userId';

  String _playlistsCollectionPath(String userId) => 'users/$userId/playlists';

  String _playlistDocumentPath(String userId, String playlistId) =>
      'users/$userId/playlists/$playlistId';

  int _sortPlaylists(UserPlaylist a, UserPlaylist b) {
    final int updatedCompare = b.updatedAt.compareTo(a.updatedAt);
    if (updatedCompare != 0) {
      return updatedCompare;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  DocumentReference<Map<String, dynamic>> _userDocument(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  CollectionReference<Map<String, dynamic>> _playlistsCollection(
    String userId,
  ) {
    return _userDocument(userId).collection('playlists');
  }

  Set<String> _readSongIds(Object? value) {
    if (value is! List<dynamic>) {
      return <String>{};
    }

    return value
        .map((dynamic item) => item.toString().trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  UserPlaylist _playlistFromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data();
    return UserPlaylist(
      id: snapshot.id,
      name: (data['name'] as String? ?? 'Untitled Playlist').trim(),
      songIds: _readSongIds(data['songIds']).toList(growable: false),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  DateTime _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _friendlyMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permission denied. Check your Firestore security rules.';
      case 'unavailable':
        return 'Firestore is temporarily unavailable. Please try again.';
      case 'not-found':
        return 'Requested Firestore data was not found.';
      case 'failed-precondition':
        return 'Firestore setup is incomplete. Check indexes and rules.';
      default:
        return error.message ?? 'A Firestore error occurred.';
    }
  }
}

class FirestoreUserData {
  const FirestoreUserData({
    required this.email,
    required this.likedSongIds,
    required this.dislikedSongIds,
    required this.playlists,
  });

  const FirestoreUserData.empty()
    : email = '',
      likedSongIds = const <String>{},
      dislikedSongIds = const <String>{},
      playlists = const <UserPlaylist>[];

  final String email;
  final Set<String> likedSongIds;
  final Set<String> dislikedSongIds;
  final List<UserPlaylist> playlists;
}

class FirestoreUserDataException implements Exception {
  const FirestoreUserDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _FirestoreRestUserDocument {
  const _FirestoreRestUserDocument({
    required this.email,
    required this.likedSongIds,
    required this.dislikedSongIds,
  });

  final String email;
  final Set<String> likedSongIds;
  final Set<String> dislikedSongIds;
}

class _RestResponse {
  const _RestResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}
