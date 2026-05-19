import 'package:flutter/foundation.dart';
import 'package:brainduel/shared/models/topic_model.dart';

class AppConstants {
  // Update the production URL after deploying to Render (e.g. https://brainduel-server.onrender.com)
  static const String _prodUrl = 'https://brainduel-server.onrender.com';
  static const String _devUrl = 'http://localhost:3001';
  static String get serverUrl => kReleaseMode ? _prodUrl : _devUrl;
  static const int totalRounds = 7;
  static const int normalRoundTime = 10; // seconds
  static const int bonusRoundTime = 15; // seconds
  static const int maxPointsPerRound = 20;
  static const int bonusRoundMultiplier = 2;
}

const List<TopicModel> kTopics = [
  TopicModel(
    id: 'general_knowledge',
    nameRo: 'Cultură Generală',
    nameEn: 'General Knowledge',
    emoji: '💡',
  ),
  TopicModel(
    id: 'history',
    nameRo: 'Istorie',
    nameEn: 'History',
    emoji: '⚔️',
  ),
  TopicModel(
    id: 'geography',
    nameRo: 'Geografie',
    nameEn: 'Geography',
    emoji: '🌍',
  ),
  TopicModel(
    id: 'gaming',
    nameRo: 'Jocuri Video',
    nameEn: 'Video Games',
    emoji: '🎮',
  ),
  TopicModel(
    id: 'music',
    nameRo: 'Muzică',
    nameEn: 'Music',
    emoji: '🎵',
  ),
  TopicModel(
    id: 'technology',
    nameRo: 'Tehnologie',
    nameEn: 'Technology',
    emoji: '💻',
  ),
  TopicModel(
    id: 'tv_series',
    nameRo: 'Seriale',
    nameEn: 'TV Series',
    emoji: '📺',
  ),
  TopicModel(
    id: 'football',
    nameRo: 'Fotbal',
    nameEn: 'Football',
    emoji: '⚽',
  ),
  TopicModel(
    id: 'tennis',
    nameRo: 'Tenis',
    nameEn: 'Tennis',
    emoji: '🎾',
  ),
  TopicModel(
    id: 'basketball',
    nameRo: 'Baschet',
    nameEn: 'Basketball',
    emoji: '🏀',
  ),
];
