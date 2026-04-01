/// App categorization for Feature 3: Productive vs. Distracting analysis.
enum AppCategory { productive, distracting, neutral }

/// Hardcoded categorization of common Android packages.
/// Unknown packages default to [AppCategory.neutral].
const Map<String, AppCategory> kAppCategoryMap = {
  // Social media = distracting
  'com.instagram.android': AppCategory.distracting,
  'com.facebook.katana': AppCategory.distracting,
  'com.facebook.orca': AppCategory.distracting,
  'com.twitter.android': AppCategory.distracting,
  'com.zhiliaoapp.musically': AppCategory.distracting, // TikTok
  'com.snapchat.android': AppCategory.distracting,
  'com.reddit.frontpage': AppCategory.distracting,
  'com.pinterest': AppCategory.distracting,
  'com.tumblr': AppCategory.distracting,

  // Streaming = distracting
  'com.google.android.youtube': AppCategory.distracting,
  'com.netflix.mediaclient': AppCategory.distracting,
  'tv.twitch.android.app': AppCategory.distracting,
  'com.disney.disneyplus': AppCategory.distracting,

  // Messaging (neutral - could be work or personal)
  'com.whatsapp': AppCategory.neutral,
  'org.telegram.messenger': AppCategory.neutral,
  'com.discord': AppCategory.neutral,
  'com.viber.voip': AppCategory.neutral,
  'com.spotify.music': AppCategory.neutral,

  // Games = distracting
  'com.supercell.clashofclans': AppCategory.distracting,
  'com.supercell.clashroyale': AppCategory.distracting,
  'com.kiloo.subwaysurf': AppCategory.distracting,

  // Productivity = productive
  'com.google.android.gm': AppCategory.productive,
  'com.google.android.apps.docs': AppCategory.productive,
  'com.google.android.calendar': AppCategory.productive,
  'com.google.android.apps.classroom': AppCategory.productive,
  'com.google.android.apps.docs.editors.sheets': AppCategory.productive,
  'com.google.android.apps.docs.editors.slides': AppCategory.productive,
  'com.google.android.keep': AppCategory.productive,
  'com.microsoft.teams': AppCategory.productive,
  'com.microsoft.office.outlook': AppCategory.productive,
  'com.microsoft.office.word': AppCategory.productive,
  'com.microsoft.office.excel': AppCategory.productive,
  'com.slack': AppCategory.productive,
  'com.notion.id': AppCategory.productive,
  'com.todoist': AppCategory.productive,
  'com.ticktick.task': AppCategory.productive,

  // This app itself
  'com.example.focus_mate': AppCategory.productive,
};

/// Returns the category for a given package name, defaulting to neutral.
AppCategory categorizeApp(String packageName) {
  return kAppCategoryMap[packageName] ?? AppCategory.neutral;
}
