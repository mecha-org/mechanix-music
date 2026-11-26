import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_bloc.dart';
import 'package:mechanix_music/features/music/bloc/player/player_event.dart';
import 'package:mechanix_music/features/music/bloc/search/search_bloc.dart';
import 'package:mechanix_music/features/music/data/models/song_model.dart';
import 'package:mechanix_music/features/music/data/repository/recent_search_repository.dart';
import 'package:mechanix_music/features/music/data/repository/song_repository.dart';
import 'package:mechanix_music/features/music/presentation/widgets/search/search_header.dart';
import 'package:mechanix_music/features/music/presentation/widgets/search/search_recent_header.dart';
import 'package:mechanix_music/features/music/presentation/widgets/search/search_track_tile.dart';
import 'package:mechanix_music/l10n/music_localizations.dart';

/// Search, opened from the search icon in the app bar.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchBloc(
        songRepository: context.read<SongRepository>(),
        recentSearchRepository: context.read<RecentSearchRepository>(),
      )..add(const SearchStarted()),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onClose() {
    if (_controller.text.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.clear();
    context.read<SearchBloc>().add(const SearchQueryChanged(''));
  }

  /// Plays [song] with [list] as the queue and remembers it as a recent
  /// search.
  void _open(SongModel song, List<SongModel> list) {
    _focusNode.unfocus();
    context.read<PlaybackBloc>()
      ..add(PlaybackListUpdated(list, followsLibrary: false))
      ..add(PlaybackPlay(song));
    context.read<SearchBloc>().add(SearchSongOpened(song));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SearchHeader(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: (query) =>
                  context.read<SearchBloc>().add(SearchQueryChanged(query)),
              onClose: _onClose,
            ),
            Expanded(
              child: BlocBuilder<SearchBloc, SearchState>(
                builder: (context, state) => _buildBody(context, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    final bloc = context.read<SearchBloc>();
    final noResults =
        state.hasQuery && !state.isSearching && state.results.isEmpty;
    final nothingYet = !state.hasQuery && state.recents.isEmpty;

    return ListView(
      key: const ValueKey('search_list'),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (state.hasQuery)
          for (final song in state.results)
            SearchTrackTile(
              key: ValueKey('search_result_${song.path}'),
              song: song,
              onTap: () => _open(song, state.results),
            ),
        if (noResults || nothingYet) const _NoTracks(),
        if (state.recents.isNotEmpty) ...[
          SearchRecentHeader(
            onClear: () => bloc.add(const SearchRecentsCleared()),
          ),
          for (final song in state.recents)
            SearchTrackTile(
              key: ValueKey('search_recent_${song.path}'),
              song: song,
              onTap: () => _open(song, state.recents),
              onRemove: () => bloc.add(SearchRecentRemoved(song.path)),
            ),
        ],
      ],
    );
  }
}

class _NoTracks extends StatelessWidget {
  const _NoTracks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('search_no_tracks'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Text(
        AppLocalizations.of(context)!.noTracksFound,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
