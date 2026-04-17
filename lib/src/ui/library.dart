part of '../ui.dart';

class _LibraryScreen extends StatelessWidget {
  const _LibraryScreen({
    super.key,
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
  });

  final OuterTuneController controller;
  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final List<UserPlaylist> playlists = controller.playlists;

    return DecoratedBox(
      decoration: _kineticPageDecoration(),
      child: ListView(
        padding: _kScreenContentPadding,
        children: <Widget>[
          const _LibraryHeader(),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _LibraryFeatureCard(
                  title: 'Liked\nSongs',
                  subtitle: '${controller.likedSongs.length} tracks',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFFF8A3D),
                  secondary: const Color(0xFFFF7D2F),
                  watermark: Icons.favorite_rounded,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            _KineticPlaylistScreen(
                              controller: controller,
                              title: 'Liked Songs',
                              songs: controller.likedSongs,
                            ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _LibraryFeatureCard(
                  title: 'Offline',
                  subtitle: 'Synced locally',
                  icon: Icons.download_rounded,
                  accent: const Color(0xFF4A1D06),
                  secondary: const Color(0xFF512007),
                  watermark: Icons.download_rounded,
                  darkText: false,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            _KineticPlaylistScreen(
                              controller: controller,
                              title: 'Offline',
                              songs: controller.songs,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Playlists',
                  style: GoogleFonts.splineSans(
                    color: const Color(0xFFFFE2D2),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showCreatePlaylistDialog(context, controller),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF9B54),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Create New +',
                  style: GoogleFonts.splineSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (playlists.isEmpty)
            _LibraryEmptyPlaylistCard(
              onCreate: () => _showCreatePlaylistDialog(context, controller),
            )
          else
            ...playlists.map(
              (UserPlaylist playlist) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _LibraryPlaylistRow(
                  controller: controller,
                  playlist: playlist,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
