/// Lightweight liked-music state shared by music and favorites screens.
class MusicFavoritesBridge {
  static final Set<String> _likedTracks = <String>{};
  static final Set<String> _likedAlbums = <String>{};
  static final Set<String> _likedPlaylists = <String>{};
  static List<String> likedTracks() => _likedTracks.toList()..sort();
  static List<String> likedAlbums() => _likedAlbums.toList()..sort();
  static List<String> likedPlaylists() => _likedPlaylists.toList()..sort();
  static void toggleTrack(String title) => _likedTracks.contains(title) ? _likedTracks.remove(title) : _likedTracks.add(title);
  static void toggleAlbum(String title) => _likedAlbums.contains(title) ? _likedAlbums.remove(title) : _likedAlbums.add(title);
  static void togglePlaylist(String title) => _likedPlaylists.contains(title) ? _likedPlaylists.remove(title) : _likedPlaylists.add(title);
}
