class S {
  static bool isRomanian = true;

  static String get appName => 'BrainDuel';
  static String get login => isRomanian ? 'Autentificare' : 'Login';
  static String get continueWithGoogle =>
      isRomanian ? 'Continuă cu Google' : 'Continue with Google';
  static String get continueWithEmail =>
      isRomanian ? 'Continuă cu Email' : 'Continue with Email';
  static String get findOpponent =>
      isRomanian ? 'Caută adversar...' : 'Finding opponent...';
  static String get quickMatch => isRomanian ? 'Meci Rapid' : 'Quick Match';
  static String get round => isRomanian ? 'Runda' : 'Round';
  static String get bonusRound => isRomanian ? 'Runda Bonus' : 'Bonus Round';
  static String get youWin => isRomanian ? 'Ai câștigat!' : 'You Win!';
  static String get youLose => isRomanian ? 'Ai pierdut!' : 'You Lose!';
  static String get draw => isRomanian ? 'Egal!' : 'Draw!';
  static String get playAgain => isRomanian ? 'Joacă din nou' : 'Play Again';
  static String get backToHome => isRomanian ? 'Acasă' : 'Home';
  static String get profile => isRomanian ? 'Profil' : 'Profile';
  static String get shop => isRomanian ? 'Magazin' : 'Shop';
  static String get leaderboard => isRomanian ? 'Clasament' : 'Leaderboard';
  static String get topics => isRomanian ? 'Subiecte' : 'Topics';
  static String get level => isRomanian ? 'Nivel' : 'Level';
  static String get coins => isRomanian ? 'Monede' : 'Coins';
  static String get xpGained => isRomanian ? 'XP câștigat' : 'XP Gained';
  static String get coinsGained =>
      isRomanian ? 'Monede câștigate' : 'Coins Earned';
  static String get cancel => isRomanian ? 'Anulează' : 'Cancel';
  static String get wins => isRomanian ? 'Victorii' : 'Wins';
  static String get losses => isRomanian ? 'Înfrângeri' : 'Losses';
  static String get draws => isRomanian ? 'Egaluri' : 'Draws';
  static String get opponentDisconnected =>
      isRomanian ? 'Adversarul s-a deconectat!' : 'Opponent disconnected!';
  static String get chooseATopic =>
      isRomanian ? 'Alege subiectul' : 'Choose a topic';
  static String get heyUser => isRomanian ? 'Salut' : 'Hey';
  static String get queuePosition =>
      isRomanian ? 'Poziție în coadă' : 'Queue position';
  static String get vs => 'VS';
  static String get totalGames =>
      isRomanian ? 'Total Meciuri' : 'Total Games';
  static String get selectedAbilities =>
      isRomanian ? 'Abilități selectate' : 'Selected Abilities';
  static String get buy => isRomanian ? 'Cumpără' : 'Buy';
  static String get owned => isRomanian ? 'Deținut' : 'Owned';
  static String get global => isRomanian ? 'Global' : 'Global';
  static String get friends => isRomanian ? 'Prieteni' : 'Friends';
  static String get comingSoon =>
      isRomanian ? 'În curând...' : 'Coming soon...';
  static String get editProfile =>
      isRomanian ? 'Editează profilul' : 'Edit Profile';
  static String get signOut =>
      isRomanian ? 'Deconectare' : 'Sign Out';
  static String get email => isRomanian ? 'Email' : 'Email';
  static String get password => isRomanian ? 'Parolă' : 'Password';
  static String get displayName => isRomanian ? 'Nume afișat' : 'Display name';
  static String get register => isRomanian ? 'Creează cont' : 'Create account';
  static String get alreadyHaveAccount => isRomanian ? 'Ai deja cont? Autentifică-te' : 'Already have an account? Sign in';
  static String get noAccount => isRomanian ? 'Nu ai cont? Creează unul' : 'No account? Create one';
  static String get tagline =>
      isRomanian ? 'Testează-ți creierul' : 'Test your brain';
  static String get pointsThisRound =>
      isRomanian ? 'Puncte în această rundă' : 'Points this round';
  static String get opponentAnswered =>
      isRomanian ? 'Adversarul a răspuns' : 'Opponent answered';
  static String get avatarFrames =>
      isRomanian ? 'Rame Avatar' : 'Avatar Frames';
  static String get backgrounds => isRomanian ? 'Fundaluri' : 'Backgrounds';
  static String get abilitySkins =>
      isRomanian ? 'Skin Abilități' : 'Ability Skins';
  static String roundOf(int current, int total) =>
      isRomanian ? 'Runda $current/$total' : 'Round $current/$total';
  static String get bonusRoundLabel =>
      isRomanian ? 'RUNDA BONUS ⭐' : 'BONUS ROUND ⭐';
  static String levelLabel(int lvl) =>
      isRomanian ? 'Nivel $lvl' : 'Level $lvl';
  static String xpProgress(int xp, int next) => '$xp / $next XP';
}
