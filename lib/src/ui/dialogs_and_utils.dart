part of '../ui.dart';

Future<void> _showCreatePlaylistDialog(
  BuildContext context,
  OuterTuneController controller,
) async {
  final TextEditingController input = TextEditingController();
  final String? name = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: _kSurface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    final bool canCreate = input.text.trim().isNotEmpty;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Create playlist',
                          style: GoogleFonts.splineSans(
                            color: _kTextPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 26),
                        TextField(
                          controller: input,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (String value) {
                            final String trimmed = value.trim();
                            if (trimmed.isNotEmpty) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(trimmed);
                            }
                          },
                          style: GoogleFonts.splineSans(
                            color: _kTextPrimary,
                            fontSize: 18,
                          ),
                          cursorColor: _kAccent,
                          decoration: InputDecoration(
                            hintText: 'New playlist',
                            hintStyle: GoogleFonts.splineSans(
                              color: _kTextSecondary.withValues(alpha: 0.72),
                              fontSize: 18,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.only(bottom: 14),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: _kSurfaceEdge,
                                width: 2,
                              ),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: _kAccent, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                                rootNavigator: true,
                              ).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: _kTextSecondary,
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.splineSans(fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton(
                              onPressed: canCreate
                                  ? () => Navigator.of(
                                      context,
                                      rootNavigator: true,
                                    ).pop(input.text.trim())
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _kAccent,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: _kAccent.withValues(
                                  alpha: 0.38,
                                ),
                                disabledForegroundColor: Colors.black54,
                                minimumSize: const Size(112, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: Text(
                                'Create',
                                style: GoogleFonts.splineSans(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  input.dispose();

  if (name != null && name.trim().isNotEmpty) {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!context.mounted) {
      return;
    }
    await controller.createPlaylist(name);
  }
}

Future<void> _showAddToPlaylistDialog(
  BuildContext context,
  OuterTuneController controller,
  LibrarySong song,
) async {
  if (controller.playlists.isEmpty) {
    await _showCreatePlaylistDialog(context, controller);
  }

  if (!context.mounted || controller.playlists.isEmpty) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _kSurfaceEdge),
        ),
        title: Text(
          'Add "${song.title}"',
          style: GoogleFonts.splineSans(
            color: _kTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 380,
          child: ListView(
            shrinkWrap: true,
            children: controller.playlists
                .map(
                  (UserPlaylist playlist) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      playlist.name,
                      style: GoogleFonts.splineSans(
                        color: _kTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${playlist.songIds.length} tracks',
                      style: GoogleFonts.splineSans(color: _kTextSecondary),
                    ),
                    onTap: () async {
                      await controller.addSongToPlaylist(playlist.id, song.id);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        _showKineticSnackBar(
                          context,
                          'Added to ${playlist.name}',
                        );
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    },
  );
}

List<Color> _gradientFor(String seed, ColorScheme scheme) {
  final int hash = seed.hashCode;
  final double hue = (hash % 360).toDouble();
  return <Color>[
    HSLColor.fromAHSL(
      1,
      hue,
      0.58,
      scheme.brightness == Brightness.dark ? 0.34 : 0.68,
    ).toColor(),
    HSLColor.fromAHSL(
      1,
      (hue + 40) % 360,
      0.54,
      scheme.brightness == Brightness.dark ? 0.2 : 0.84,
    ).toColor(),
  ];
}

String _initials(String text) {
  final List<String> words = text
      .split(RegExp(r'\s+'))
      .where((String item) => item.trim().isNotEmpty)
      .take(2)
      .toList();
  if (words.isEmpty) {
    return 'OT';
  }
  return words.map((String item) => item.characters.first.toUpperCase()).join();
}

String _formatClock(Duration duration) {
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  final int hours = duration.inHours;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  return '${duration.inMinutes}m';
}

IconData _repeatIcon(PlaylistMode mode) {
  return switch (mode) {
    PlaylistMode.none => Icons.repeat_rounded,
    PlaylistMode.loop => Icons.repeat_on_rounded,
    PlaylistMode.single => Icons.repeat_one_on_rounded,
  };
}
