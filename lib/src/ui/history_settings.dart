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
                      'Played songs stay cached until you clear them. Pick how many upcoming songs to keep ready offline.',
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

    if (_isDesktopPlatform()) {
      return _DesktopSettingsScreen(
        controller: controller,
        onPickNextChanceSongCount: pickNextChanceSongCount,
        onPickRegion: pickRegion,
      );
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
            _ProfileDataUsageCard(
              controller: controller,
              card: card,
              cardEdge: cardEdge,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              accent: accent,
            ),
            const SizedBox(height: 14),
            _ProfileCurrentStreamCard(
              controller: controller,
              card: card,
              cardEdge: cardEdge,
              titleColor: titleColor,
              subtitleColor: subtitleColor,
              accent: accent,
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

class _ProfileDataUsageCard extends StatelessWidget {
  const _ProfileDataUsageCard({
    required this.controller,
    required this.card,
    required this.cardEdge,
    required this.titleColor,
    required this.subtitleColor,
    required this.accent,
  });

  final OuterTuneController controller;
  final Color card;
  final Color cardEdge;
  final Color titleColor;
  final Color subtitleColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppDataUsageStats>(
      valueListenable: controller.dataUsageState,
      builder: (BuildContext context, AppDataUsageStats usage, Widget? child) {
        Future<void> clearCache() async {
          final bool confirmed = await _showProfileActionConfirmationDialog(
            context,
            title: 'Clear offline cache?',
            message:
                'This removes cached songs saved for offline replay. Streaming will use data again until the songs are cached another time.',
            confirmLabel: 'Clear Cache',
            confirmColor: const Color(0xFFDE6B48),
          );
          if (!confirmed || !context.mounted) {
            return;
          }
          await controller.clearOfflinePlaybackCacheAndNotify();
          if (context.mounted) {
            _showKineticSnackBar(context, 'Offline cache cleared');
          }
        }

        Future<void> resetUsage() async {
          final bool confirmed = await _showProfileActionConfirmationDialog(
            context,
            title: 'Reset data usage?',
            message:
                'This clears streaming, cache, search, discovery, artwork, and metadata totals shown on your profile.',
            confirmLabel: 'Reset Usage',
            confirmColor: accent,
          );
          if (!confirmed || !context.mounted) {
            return;
          }
          await controller.resetDataUsageStats();
          if (context.mounted) {
            _showKineticSnackBar(context, 'Data usage reset');
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardEdge),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.data_usage_rounded,
                    color: Color(0xFFC89373),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Network Usage',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Live playback counts once while you listen. Future-song warmups are tracked separately.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: subtitleColor),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _UsageChip(
                    label: 'Total',
                    value: usage.totalLabel,
                    accent: accent,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                  _UsageChip(
                    label: 'Streaming',
                    value: usage.streamLabel,
                    accent: accent,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                  _UsageChip(
                    label: 'Offline Cache',
                    value: usage.cacheLabel,
                    accent: accent,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                  _UsageChip(
                    label: 'Other',
                    value: usage.otherLabel,
                    accent: accent,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                  _UsageChip(
                    label: 'Current Song',
                    value: usage.currentSongLabel,
                    accent: accent,
                    titleColor: titleColor,
                    subtitleColor: subtitleColor,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C0904),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3A170C)),
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFFC89373),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Other',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Searches, discovery loads, artwork lookups, and metadata requests are grouped here.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      title: 'Searches',
                      value: usage.searchLabel,
                      titleColor: titleColor,
                      valueColor: accent,
                    ),
                    _ProfileDetailRow(
                      title: 'Loads',
                      value: usage.loadLabel,
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    _ProfileDetailRow(
                      title: 'Artwork',
                      value: usage.artworkLabel,
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    _ProfileDetailRow(
                      title: 'Metadata',
                      value: usage.metadataLabel,
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    _ProfileDetailRow(
                      title: 'Total',
                      value: usage.otherLabel,
                      titleColor: titleColor,
                      valueColor: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: controller.offlinePlaybackCacheSongCount == 0
                        ? null
                        : clearCache,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFB18C),
                      side: BorderSide(color: cardEdge.withValues(alpha: 0.95)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text(
                      controller.offlinePlaybackCacheSongCount == 0
                          ? 'Cache Empty'
                          : 'Clear Cache',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: usage.totalBytes <= 0 ? null : resetUsage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: cardEdge.withValues(alpha: 0.95)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: const Text('Reset Data Usage'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<bool> _showProfileActionConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color confirmColor,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C0904),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF3A170C)),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFFFFE6D5),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFFC89373)),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

class _ProfileCurrentStreamCard extends StatelessWidget {
  const _ProfileCurrentStreamCard({
    required this.controller,
    required this.card,
    required this.cardEdge,
    required this.titleColor,
    required this.subtitleColor,
    required this.accent,
  });

  final OuterTuneController controller;
  final Color card;
  final Color cardEdge;
  final Color titleColor;
  final Color subtitleColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NowPlayingState>(
      valueListenable: controller.nowPlayingState,
      builder: (BuildContext context, NowPlayingState nowPlaying, Widget? child) {
        return ValueListenableBuilder<AppDataUsageStats>(
          valueListenable: controller.dataUsageState,
          builder: (BuildContext context, AppDataUsageStats usage, Widget? child) {
            final LibrarySong? song = nowPlaying.song;
            final PlaybackStreamInfo? info = nowPlaying.streamInfo;

            return Container(
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardEdge),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFFC89373),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Current Stream',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (song == null || info == null)
                    Text(
                      'Start playback to inspect transport, source, bitrate, codecs, and live bytes.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    )
                  else ...<Widget>[
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _songArtistLabel(song),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                    ),
                    const SizedBox(height: 14),
                    _ProfileDetailRow(
                      title: 'Source',
                      value: info.sourceLabel,
                      titleColor: titleColor,
                      valueColor: accent,
                    ),
                    _ProfileDetailRow(
                      title: 'Transport',
                      value: info.transport.label,
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    _ProfileDetailRow(
                      title: 'Bitrate',
                      value: '${info.bitrateLabel} • ${info.bitrateTier}',
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    _ProfileDetailRow(
                      title: 'Policy',
                      value: info.selectionPolicyLabel,
                      titleColor: titleColor,
                      valueColor: titleColor,
                    ),
                    if ((info.qualityLabel ?? '').trim().isNotEmpty)
                      _ProfileDetailRow(
                        title: 'Quality',
                        value: info.qualityLabel!,
                        titleColor: titleColor,
                        valueColor: titleColor,
                      ),
                    if ((info.containerName ?? '').trim().isNotEmpty)
                      _ProfileDetailRow(
                        title: 'Container',
                        value: info.containerName!,
                        titleColor: titleColor,
                        valueColor: titleColor,
                      ),
                    if ((info.audioCodec ?? '').trim().isNotEmpty)
                      _ProfileDetailRow(
                        title: 'Audio Codec',
                        value: info.audioCodec!,
                        titleColor: titleColor,
                        valueColor: titleColor,
                      ),
                    if ((info.videoCodec ?? '').trim().isNotEmpty)
                      _ProfileDetailRow(
                        title: 'Video Codec',
                        value: info.videoCodec!,
                        titleColor: titleColor,
                        valueColor: titleColor,
                      ),
                    _ProfileDetailRow(
                      title: 'Song Data',
                      value: usage.currentSongLabel,
                      titleColor: titleColor,
                      valueColor: accent,
                    ),
                    _ProfileDetailRow(
                      title: 'Available',
                      value:
                          'A ${info.availableAudioOnlyCount} • HA ${info.availableHlsAudioOnlyCount} • M ${info.availableMuxedCount} • HM ${info.availableHlsMuxedCount} • HV ${info.availableHlsVideoOnlyCount}',
                      titleColor: titleColor,
                      valueColor: subtitleColor,
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({
    required this.label,
    required this.value,
    required this.accent,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String label;
  final String value;
  final Color accent;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0904),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A170C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: subtitleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color:
                  label == 'Total' || label == 'Streaming' || label == 'Other'
                  ? accent
                  : titleColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.title,
    required this.value,
    required this.titleColor,
    required this.valueColor,
  });

  final String title;
  final String value;
  final Color titleColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: titleColor.withValues(alpha: 0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
