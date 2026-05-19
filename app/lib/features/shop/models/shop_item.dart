class ShopItem {
  final String id;
  final String name;
  final String description;
  final int price;
  final ShopItemCategory category;
  final String colorHex; // used as a colored placeholder
  final bool isPurchased;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.colorHex,
    this.isPurchased = false,
  });

  ShopItem copyWith({bool? isPurchased}) {
    return ShopItem(
      id: id,
      name: name,
      description: description,
      price: price,
      category: category,
      colorHex: colorHex,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }
}

enum ShopItemCategory {
  avatarFrame,
  background,
  abilitySkin,
}

const List<ShopItem> kShopItems = [
  // Avatar Frames
  ShopItem(
    id: 'frame_gold',
    name: 'Ramă Aurie',
    description: 'O ramă strălucitoare de aur',
    price: 500,
    category: ShopItemCategory.avatarFrame,
    colorHex: '#F59E0B',
  ),
  ShopItem(
    id: 'frame_neon',
    name: 'Ramă Neon',
    description: 'Ramă cu efect neon electric',
    price: 350,
    category: ShopItemCategory.avatarFrame,
    colorHex: '#06B6D4',
  ),
  ShopItem(
    id: 'frame_fire',
    name: 'Ramă de Foc',
    description: 'Ramă cu flăcări animate',
    price: 600,
    category: ShopItemCategory.avatarFrame,
    colorHex: '#EF4444',
  ),
  // Backgrounds
  ShopItem(
    id: 'bg_galaxy',
    name: 'Fundal Galaxie',
    description: 'Fundal cu stele și nebuloase',
    price: 400,
    category: ShopItemCategory.background,
    colorHex: '#4C1D95',
  ),
  ShopItem(
    id: 'bg_ocean',
    name: 'Fundal Ocean',
    description: 'Valuri calme de ocean',
    price: 300,
    category: ShopItemCategory.background,
    colorHex: '#0369A1',
  ),
  ShopItem(
    id: 'bg_matrix',
    name: 'Fundal Matrix',
    description: 'Cod care curge pe ecran',
    price: 450,
    category: ShopItemCategory.background,
    colorHex: '#065F46',
  ),
  // Ability Skins
  ShopItem(
    id: 'skin_golden_fifty',
    name: 'Golden 50/50',
    description: 'Skin auriu pentru abilitatea 50/50',
    price: 200,
    category: ShopItemCategory.abilitySkin,
    colorHex: '#F59E0B',
  ),
  ShopItem(
    id: 'skin_neon_shield',
    name: 'Neon Shield',
    description: 'Skin neon pentru scut',
    price: 200,
    category: ShopItemCategory.abilitySkin,
    colorHex: '#7C3AED',
  ),
];
