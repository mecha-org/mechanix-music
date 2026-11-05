import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_bloc.dart';
import 'package:mechanix_music/features/music/bloc/playlist/playlist_bloc.dart';
import 'package:mechanix_music/features/music/bloc/song_event.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository_impl.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository.dart';
import 'package:mechanix_music/features/music/data/repository/playlist_repository_impl.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository.dart';
import 'package:mechanix_music/features/music/data/repository/playback_repository_impl.dart';
import 'package:mechanix_music/features/music/data/services/favourites_store.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository_impl.dart';
import 'package:mechanix_music/features/music/presentation/screens/music_screen.dart';
import 'package:widgets/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The library lives in a Tantivy index; playlists and favourites are
  // .m3u8 files. Playlists read song info from the library for #EXTINF.
  // One favourites store: the song repository (favourite flag) and the
  // playlist repository (the fixed Favourites playlist) share it.
  final favouritesStore = FavouritesStore();
  final songRepository = SongRepositoryImpl(favouritesStore: favouritesStore);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SongRepository>.value(value: songRepository),
        RepositoryProvider<PlaylistRepository>(
          create: (_) => PlaylistRepositoryImpl(
            songRepository: songRepository,
            favouritesStore: favouritesStore,
          ),
        ),
        RepositoryProvider<PlaybackRepository>(
          create: (_) => PlaybackRepositoryImpl(),
        ),
        RepositoryProvider<RecentSearchRepository>(
          create: (_) => RecentSearchRepositoryImpl(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            lazy: false,
            create: (context) =>
                SongBloc(songRepository: context.read<SongRepository>())
                  ..add(const SongInitialized()),
          ),
          BlocProvider(
            create: (context) =>
                PlaylistBloc(repository: context.read<PlaylistRepository>())
                  ..add(const PlaylistsRequested()),
          ),
          BlocProvider(
            create: (context) => PlaybackBloc(
              context.read<PlaybackRepository>(),
              context.read<SongBloc>(),
            ),
          ),
        ],
        child: const MusicApp(),
      ),
    ),
  );
}

class MusicApp extends StatelessWidget {
  const MusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MechanixTheme(
      builder: (context, theme, child) {
        final darkTheme = theme.dark;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: darkTheme,
          darkTheme: darkTheme,
          themeMode: theme.mode,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MusicScreen(),
        );
      },
    );
  }
}
