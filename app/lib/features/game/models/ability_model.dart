import 'package:flutter/material.dart';
import 'package:brainduel/core/theme/app_theme.dart';

enum AbilityType {
  fiftyFifty,
  timeBoost,
  sabotage,
  doubleDown,
  shield,
  reveal,
}

class AbilityModel {
  final AbilityType type;
  final String name;
  final String description;
  final String emoji;
  final Color color;

  const AbilityModel({
    required this.type,
    required this.name,
    required this.description,
    required this.emoji,
    required this.color,
  });

  static AbilityModel fromType(AbilityType type) {
    switch (type) {
      case AbilityType.fiftyFifty:
        return AbilityModel(
          type: type,
          name: '50/50',
          description: 'Elimină 2 răspunsuri greșite',
          emoji: '½',
          color: AppColors.secondary,
        );
      case AbilityType.timeBoost:
        return AbilityModel(
          type: type,
          name: '+Timp',
          description: 'Adaugă 5 secunde la timer',
          emoji: '⏱',
          color: AppColors.correct,
        );
      case AbilityType.sabotage:
        return AbilityModel(
          type: type,
          name: 'Sabotaj',
          description: 'Reduce timpul adversarului',
          emoji: '💀',
          color: AppColors.wrong,
        );
      case AbilityType.doubleDown:
        return AbilityModel(
          type: type,
          name: 'x2',
          description: 'Dublează punctele pentru această rundă',
          emoji: '2×',
          color: AppColors.gold,
        );
      case AbilityType.shield:
        return AbilityModel(
          type: type,
          name: 'Scut',
          description: 'Blochează abilitățile adversarului',
          emoji: '🛡',
          color: const Color(0xFF818CF8),
        );
      case AbilityType.reveal:
        return AbilityModel(
          type: type,
          name: 'Dezvăluie',
          description: 'Arată răspunsul corect',
          emoji: '👁',
          color: const Color(0xFFF97316),
        );
    }
  }

  static AbilityType fromString(String value) {
    switch (value) {
      case 'fiftyFifty':
        return AbilityType.fiftyFifty;
      case 'timeBoost':
        return AbilityType.timeBoost;
      case 'sabotage':
        return AbilityType.sabotage;
      case 'doubleDown':
        return AbilityType.doubleDown;
      case 'shield':
        return AbilityType.shield;
      case 'reveal':
        return AbilityType.reveal;
      default:
        return AbilityType.fiftyFifty;
    }
  }

  String toTypeString() {
    switch (type) {
      case AbilityType.fiftyFifty:
        return 'fiftyFifty';
      case AbilityType.timeBoost:
        return 'timeBoost';
      case AbilityType.sabotage:
        return 'sabotage';
      case AbilityType.doubleDown:
        return 'doubleDown';
      case AbilityType.shield:
        return 'shield';
      case AbilityType.reveal:
        return 'reveal';
    }
  }
}
