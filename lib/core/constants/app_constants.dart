class AppConstants {
  AppConstants._();

  // App
  static const String appName = 'Reelio';

  // Supabase
  static const String supabaseUrl = 'https://fgjwrvzdszyawefanjsr.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_pd7HUMy0ZwoWzQE6-yQAFQ_ba8O0azi';

  // Tables
  static const String videosTable = 'videos';
  static const String likesTable = 'likes';
  static const String commentsTable = 'comments';
  static const String profilesTable = 'profiles';
  static const String followsTable = 'follows';

  // Storage
  static const String videoBucket = 'videos';
  static const String avatarBucket = 'avatars';

  // Animations
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration heartAnimationDuration = Duration(milliseconds: 400);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // UI
  static const double defaultPadding = 16.0;
  static const double actionIconSize = 32.0;
  static const double profileImageSize = 48.0;
  static const double smallProfileSize = 36.0;

  // Video
  static const int videosPerPage = 10;
  static const int preloadCount = 2;

  // Fake user profiles for display
  static const List<Map<String, String>> fakeProfiles = [
    {
      'username': '@alexrivera',
      'displayName': 'Alex Rivera',
      'bio': '🎬 Video creator | Travel & Lifestyle | LA based ✈️',
      'avatar': 'https://i.pravatar.cc/150?img=1',
    },
    {
      'username': '@mariasanchez',
      'displayName': 'Maria Sanchez',
      'bio': '💃 Dance teacher | Choreographer | NYC 🗽 collabs open!',
      'avatar': 'https://i.pravatar.cc/150?img=5',
    },
    {
      'username': '@mikejohnson',
      'displayName': 'Mike Johnson',
      'bio': '🍕 Foodie & Chef vibes | trying every restaurant 🔥',
      'avatar': 'https://i.pravatar.cc/150?img=3',
    },
    {
      'username': '@emmawilson',
      'displayName': 'Emma Wilson',
      'bio': '🌿 Wellness | Mindfulness | Yoga | Be kind always 🙏',
      'avatar': 'https://i.pravatar.cc/150?img=9',
    },
    {
      'username': '@jaketurner',
      'displayName': 'Jake Turner',
      'bio': '🎮 Gamer | Streamer | Level 99 in real life lol',
      'avatar': 'https://i.pravatar.cc/150?img=7',
    },
  ];
}
