part of '../ui.dart';

// ignore: unused_element
class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen({required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.history.isEmpty) {
      return const Center(child: Text('Playback history will appear here.'));
    }

    return SafeArea(
      bottom: false,
      child: ListView.builder(
        padding: _rootScreenContentPadding(
          context,
          hasMiniPlayer: controller.miniPlayerSong != null,
        ),
        itemCount: controller.history.length,
        itemBuilder: (BuildContext context, int index) {
          final PlaybackEntry entry = controller.history[index];
          final LibrarySong? song = controller.songById(entry.songId);
          if (song == null) {
            return const SizedBox.shrink();
          }
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 4,
            ),
            leading: _Artwork(
              seed: song.id,
              title: song.title,
              size: 52,
              imageUrl: song.artworkUrl,
            ),
            title: Text(song.title),
            subtitle: Text(_songArtistLabel(song)),
            trailing: IconButton(
              onPressed: () => controller.playSong(song, label: 'History'),
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsScreen extends StatelessWidget {
  const _SettingsScreen({super.key, required this.controller});

  final OuterTuneController controller;

  @override
  Widget build(BuildContext context) {
    const Color pageTop = Color(0xFF210A03);
    const Color pageBottom = Color(0xFF100402);
    const Color card = Color(0xFF2A1007);
    const Color cardEdge = Color(0xFF3A170C);
    const Color titleColor = Color(0xFFFFE6D5);
    const Color subtitleColor = Color(0xFFC89373);
    const Color accent = Color(0xFFFF8A2A);

    final bool gapless = controller.settings.gaplessPlayback;
    final int nextChanceSongCount = controller.settings.nextChanceSongCount;
    final String preferredRegion = controller.preferredRegionLabel;

    Future<void> pickNextChanceSongCount() async {
      const List<int> options = <int>[0, 1, 2, 3, 4, 5];
      final int? selected = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: const Color(0xFF1C0904),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.72,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Choose upcoming offline songs',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The last 10 songs stay available. Pick how many upcoming songs to keep ready offline.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: options.map((int option) {
                          final bool active = option == nextChanceSongCount;
                          final String label = option == 0 ? 'Off' : '$option';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onTap: () => Navigator.of(context).pop(option),
                            title: Text(
                              label,
                              style: TextStyle(
                                color: active ? accent : titleColor,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            trailing: active
                                ? const Icon(Icons.check_rounded, color: accent)
                                : null,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selected != null) {
        await controller.setNextChanceSongCount(selected);
      }
    }

    Future<void> pickRegion() async {
      final String? selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1C0904),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) {
          final List<AppRegion> regions = controller.availableRegions;
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Choose region',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Regional trending and charts will follow this region.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: regions.length,
                        itemBuilder: (BuildContext context, int index) {
                          final AppRegion region = regions[index];
                          final bool active =
                              region.countryCode ==
                              controller.preferredCountryCode;
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onTap: () =>
                                Navigator.of(context).pop(region.countryCode),
                            title: Text(
                              region.label,
                              style: TextStyle(
                                color: active ? accent : titleColor,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              region.countryCode,
                              style: const TextStyle(color: subtitleColor),
                            ),
                            trailing: active
                                ? const Icon(Icons.check_rounded, color: accent)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (selected != null) {
        await controller.setPreferredRegion(selected);
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[pageTop, pageBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: _rootScreenContentPadding(
            context,
            hasMiniPlayer: controller.miniPlayerSong != null,
          ),
          children: <Widget>[
            const _HomeStyleHeader(
              title: 'SETTINGS',
              leading: _HomeStyleProfileBadge(),
              trailing: _HomeStyleNotificationIcon(),
            ),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A1D0E),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.account_circle_rounded,
                      color: Color(0xFFFFC8A1),
                      size: 66,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'SACHICODEX',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'alex.rivers@pulse.audio',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.person_outline_rounded,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Account',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ProfileRow(
                    title: 'Subscription Plan',
                    subtitle: 'Your current billing cycle ends Oct 12',
                    trailing: 'Ultra High-Fi',
                  ),
                  const Divider(color: cardEdge, height: 20),
                  _ProfileRow(
                    title: 'Payment Method',
                    subtitle: 'Default card for renewals',
                    trailing: '• • • •  4421',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.slow_motion_video_rounded,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Playback',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Gapless Playback',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Remove silence between album tracks',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    trailing: Switch(
                      value: gapless,
                      activeThumbColor: accent,
                      activeTrackColor: const Color(0xFF9D4D18),
                      inactiveThumbColor: const Color(0xFFD8A98A),
                      inactiveTrackColor: const Color(0xFF5C2A17),
                      onChanged: controller.setGaplessPlayback,
                    ),
                  ),
                  const Divider(color: cardEdge, height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: pickNextChanceSongCount,
                    title: Text(
                      'Upcoming Offline Songs',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      nextChanceSongCount == 0
                          ? 'Off'
                          : 'Keep the next $nextChanceSongCount song${nextChanceSongCount == 1 ? '' : 's'} ready offline',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          nextChanceSongCount == 0
                              ? 'Off'
                              : '$nextChanceSongCount',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: subtitleColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.public_rounded, color: subtitleColor),
                      const SizedBox(width: 10),
                      Text(
                        'Discovery Region',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Region',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Controls Trending Now and regional chart shelves',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    trailing: GestureDetector(
                      onTap: pickRegion,
                      child: Text(
                        preferredRegion,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    onTap: pickRegion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Pulse Audio v4.2.1-stable',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Proudly built for music enthusiasts.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subtitleColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PRIVACY      TERMS      CREDITS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: subtitleColor,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(220, 42),
                  side: const BorderSide(color: cardEdge),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  foregroundColor: accent,
                ),
                child: const Text('SIGN OUT OF PULSE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    const Color titleColor = Color(0xFFFFE6D5);
    const Color subtitleColor = Color(0xFFC89373);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            trailing,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
