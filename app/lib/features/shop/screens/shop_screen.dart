// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/l10n/strings.dart';
import 'package:brainduel/features/profile/providers/profile_provider.dart';
import 'package:brainduel/features/shop/models/shop_item.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _ownedItems = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<ShopItem> _itemsForCategory(ShopItemCategory category) {
    return kShopItems
        .where((item) => item.category == category)
        .map((item) => item.copyWith(isPurchased: _ownedItems.contains(item.id)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Container(
      decoration: AppTheme.backgroundGradient,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(profileState.coins),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildItemGrid(_itemsForCategory(ShopItemCategory.avatarFrame),
                      profileState),
                  _buildItemGrid(_itemsForCategory(ShopItemCategory.background),
                      profileState),
                  _buildItemGrid(
                      _itemsForCategory(ShopItemCategory.abilitySkin),
                      profileState),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int coins) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            S.shop,
            style: GoogleFonts.exo2(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: GoogleFonts.exo2(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          Tab(text: S.avatarFrames),
          Tab(text: S.backgrounds),
          Tab(text: S.abilitySkins),
        ],
      ),
    );
  }

  Widget _buildItemGrid(List<ShopItem> items, ProfileState profileState) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _ShopItemCard(
          item: item,
          canAfford: profileState.coins >= item.price,
          onBuy: () => _buyItem(item, profileState),
        );
      },
    );
  }

  void _buyItem(ShopItem item, ProfileState profileState) {
    if (_ownedItems.contains(item.id)) return;
    if (profileState.coins < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nu ai suficiente monede!',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppColors.wrong,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item.name,
          style:
              GoogleFonts.exo2(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Cumperi "${item.name}" pentru ${item.price} monede?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(S.cancel,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _ownedItems.add(item.id));
              // Deduct coins via provider
              // In real app: ref.read(profileProvider.notifier).spendCoins(item.price)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} cumpărat!',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppColors.correct,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              '${S.buy} (${item.price})',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  final ShopItem item;
  final bool canAfford;
  final VoidCallback onBuy;

  const _ShopItemCard({
    required this.item,
    required this.canAfford,
    required this.onBuy,
  });

  Color _parseColor() {
    try {
      final hex = item.colorHex.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemColor = _parseColor();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Color placeholder image
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [itemColor, itemColor.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _iconForCategory(item.category),
                    size: 40,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          // Item info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.exo2(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: item.isPurchased
                      ? Container(
                          decoration: BoxDecoration(
                            color: AppColors.correct.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.correct.withOpacity(0.4)),
                          ),
                          child: Center(
                            child: Text(
                              S.owned,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.correct,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: canAfford ? onBuy : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford
                                ? AppColors.primary
                                : Colors.white.withOpacity(0.1),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.monetization_on,
                                  color: AppColors.gold, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${item.price}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForCategory(ShopItemCategory category) {
    switch (category) {
      case ShopItemCategory.avatarFrame:
        return Icons.crop_square;
      case ShopItemCategory.background:
        return Icons.wallpaper;
      case ShopItemCategory.abilitySkin:
        return Icons.auto_awesome;
    }
  }
}
