package com.example.music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

class MediaNotificationService : Service() {
    private lateinit var mediaSession: MediaSessionCompat
    private val artExecutor = Executors.newSingleThreadExecutor()
    private lateinit var audioManager: AudioManager
    private var focusRequest: AudioFocusRequest? = null

    private var currentTitle: String = "Unknown title"
    private var currentArtist: String = "Unknown artist"
    private var currentAlbum: String = "Unknown album"
    private var currentArtUri: String? = null
    private var isPlaying: Boolean = false
    private var currentPositionMs: Long = 0L
    private var currentDurationMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        mediaSession = MediaSessionCompat(this, SESSION_TAG).apply {
            isActive = true
            setCallback(
                object : MediaSessionCompat.Callback() {
                    override fun onPlay() = emitMediaCommand(COMMAND_PLAY)
                    override fun onPause() = emitMediaCommand(COMMAND_PAUSE)
                    override fun onSkipToNext() = emitMediaCommand(COMMAND_NEXT)
                    override fun onSkipToPrevious() = emitMediaCommand(COMMAND_PREVIOUS)
                }
            )
        }
        updatePlaybackState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE_NOTIFICATION -> {
                applyUpdate(intent)
                updatePlaybackState()
                loadArtworkAndNotify()
            }
            ACTION_STOP_NOTIFICATION -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_PLAY -> emitMediaCommand(COMMAND_PLAY_PAUSE)
            ACTION_PAUSE -> emitMediaCommand(COMMAND_PLAY_PAUSE)
            ACTION_NEXT -> emitMediaCommand(COMMAND_NEXT)
            ACTION_PREVIOUS -> emitMediaCommand(COMMAND_PREVIOUS)
        }
        return START_NOT_STICKY
    }

    private fun applyUpdate(intent: Intent) {
        val wasPlaying = isPlaying
        currentTitle = intent.getStringExtra(EXTRA_TITLE)?.ifBlank { "Unknown title" } ?: "Unknown title"
        currentArtist = intent.getStringExtra(EXTRA_ARTIST)?.ifBlank { "Unknown artist" } ?: "Unknown artist"
        currentAlbum = intent.getStringExtra(EXTRA_ALBUM)?.ifBlank { "Unknown album" } ?: "Unknown album"
        currentArtUri = intent.getStringExtra(EXTRA_ART_URI)
        isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
        currentPositionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L).coerceAtLeast(0L)
        currentDurationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L).coerceAtLeast(0L)
        if (isPlaying && !wasPlaying) {
            requestAudioFocus()
        } else if (!isPlaying && wasPlaying) {
            abandonAudioFocus()
        }
    }

    private fun loadArtworkAndNotify() {
        val artUri = currentArtUri
        if (artUri.isNullOrBlank()) {
            val notification = buildNotification(null)
            startForeground(NOTIFICATION_ID, notification)
            return
        }

        artExecutor.execute {
            val bitmap = loadBitmapFromUri(artUri)
            val notification = buildNotification(bitmap)
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(largeIcon: Bitmap?): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            REQUEST_CONTENT,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val previousIntent = servicePendingIntent(ACTION_PREVIOUS, REQUEST_PREVIOUS)
        val playPauseIntent = servicePendingIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY, REQUEST_PLAY_PAUSE)
        val nextIntent = servicePendingIntent(ACTION_NEXT, REQUEST_NEXT)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setSubText(currentAlbum)
            .setLargeIcon(largeIcon)
            .setSmallIcon(R.drawable.ic_stat_music)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(contentIntent)
            .addAction(R.drawable.ic_media_previous, "Previous", previousIntent)
            .addAction(
                if (isPlaying) R.drawable.ic_media_pause else R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                playPauseIntent
            )
            .addAction(R.drawable.ic_media_next, "Next", nextIntent)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(this, MediaNotificationService::class.java).setAction(action)
        return PendingIntent.getService(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun emitMediaCommand(command: String) {
        val intent = Intent(ACTION_MEDIA_COMMAND_BROADCAST).apply {
            setPackage(packageName)
            putExtra(EXTRA_COMMAND, command)
        }
        sendBroadcast(intent)
    }

    private fun updatePlaybackState() {
        val state =
            if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions =
            PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_PLAY_PAUSE

        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(state, currentPositionMs, 1.0f)
                .build()
        )

        mediaSession.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, currentAlbum)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs)
                .build()
        )
    }

    private fun loadBitmapFromUri(raw: String): Bitmap? {
        return try {
            val uri = Uri.parse(raw)
            when (uri.scheme?.lowercase()) {
                "content", "file" -> {
                    contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it) }
                }
                "http", "https" -> {
                    val connection = URL(raw).openConnection() as HttpURLConnection
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    connection.instanceFollowRedirects = true
                    connection.inputStream.use { BitmapFactory.decodeStream(it) }
                }
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Playback controls for music player"
                setShowBadge(false)
            }
        manager.createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        abandonAudioFocus()
        mediaSession.release()
        artExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun requestAudioFocus() {
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_LOSS,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> emitMediaCommand(COMMAND_PAUSE)
            }
        }

        focusRequest =
            AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setOnAudioFocusChangeListener(listener)
                .build()
        focusRequest?.let { audioManager.requestAudioFocus(it) }
    }

    private fun abandonAudioFocus() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    companion object {
        const val ACTION_UPDATE_NOTIFICATION = "com.example.music.action.UPDATE_NOTIFICATION"
        const val ACTION_STOP_NOTIFICATION = "com.example.music.action.STOP_NOTIFICATION"
        const val ACTION_PLAY = "com.example.music.action.PLAY"
        const val ACTION_PAUSE = "com.example.music.action.PAUSE"
        const val ACTION_NEXT = "com.example.music.action.NEXT"
        const val ACTION_PREVIOUS = "com.example.music.action.PREVIOUS"

        const val ACTION_MEDIA_COMMAND_BROADCAST = "com.example.music.action.MEDIA_COMMAND"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_ALBUM = "extra_album"
        const val EXTRA_ART_URI = "extra_art_uri"
        const val EXTRA_IS_PLAYING = "extra_is_playing"
        const val EXTRA_POSITION_MS = "extra_position_ms"
        const val EXTRA_DURATION_MS = "extra_duration_ms"
        const val EXTRA_COMMAND = "extra_command"

        const val COMMAND_PLAY_PAUSE = "play_pause"
        const val COMMAND_PLAY = "play"
        const val COMMAND_PAUSE = "pause"
        const val COMMAND_NEXT = "next"
        const val COMMAND_PREVIOUS = "previous"

        private const val CHANNEL_ID = "com.example.music.playback"
        private const val SESSION_TAG = "music_media_session"
        private const val NOTIFICATION_ID = 1001

        private const val REQUEST_CONTENT = 11
        private const val REQUEST_PREVIOUS = 12
        private const val REQUEST_PLAY_PAUSE = 13
        private const val REQUEST_NEXT = 14
    }
}
