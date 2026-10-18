import 'market.dart';

class Dish {
  const Dish({
    required this.id,
    required this.nameKm,
    required this.nameEn,
    required this.detailKm,
    required this.detailEn,
    required this.usd,
  });

  final String id;
  final String nameKm;
  final String nameEn;
  final String detailKm;
  final String detailEn;
  final double usd;

  String nameFor(LocaleCode lang) => lang == LocaleCode.km ? nameKm : nameEn;
}

enum LocaleCode { km, en }

class Kitchen {
  const Kitchen({
    required this.id,
    required this.cityId,
    required this.nameKm,
    required this.nameEn,
    required this.areaKm,
    required this.areaEn,
    required this.latitude,
    required this.longitude,
    required this.etaMin,
    required this.deliveryUsd,
    required this.rating,
    required this.menu,
    this.openHour = 8,
    this.closeHour = 21,
    this.typicalReplySeconds = 180,
    this.nationwide = true,
  });

  final String id;
  final String cityId;
  final String nameKm;
  final String nameEn;
  final String areaKm;
  final String areaEn;
  final double latitude;
  final double longitude;
  final int etaMin;
  final double deliveryUsd;
  final double rating;
  final List<Dish> menu;

  /// Local hour when replies start counting, inclusive.
  final int openHour;

  /// Local hour when replies stop counting, exclusive.
  final int closeHour;

  /// Average seconds to reply during [openHour]–[closeHour].
  final int typicalReplySeconds;

  /// Sample kitchens serve every province, city, and village.
  final bool nationwide;

  bool serves(String placeId) => nationwide || cityId == placeId;

  String nameFor(LocaleCode lang) => lang == LocaleCode.km ? nameKm : nameEn;

  String areaFor(LocaleCode lang) => lang == LocaleCode.km ? areaKm : areaEn;

  Dish dish(String id) => menu.firstWhere((d) => d.id == id);
}

class PopularPick {
  const PopularPick({
    required this.cityId,
    required this.window,
    required this.kitchenId,
    required this.dishId,
    required this.orders,
  });

  final String cityId;
  final PopularWindow window;
  final String kitchenId;
  final String dishId;
  final int orders;
}

class Catalog {
  Catalog._();

  static const kitchens = <Kitchen>[
    Kitchen(
      id: 'nom_banh_chok',
      cityId: 'phnom_penh',
      nameKm: 'នំបញ្ចុកព្រឹក',
      nameEn: 'Morning Nom Banh Chok',
      areaKm: 'ទួលទំពូង',
      areaEn: 'Toul Tom Poung',
      latitude: 11.5454,
      longitude: 104.9108,
      etaMin: 22,
      deliveryUsd: 0.40,
      rating: 4.8,
      menu: [
        Dish(
          id: 'nbc_khmer',
          nameKm: 'នំបញ្ចុកសម្លរខ្មែរ',
          nameEn: 'Nom banh chok, Khmer curry',
          detailKm: 'ប្រហិតស្រស់ ត្រកួន ត្រសក់',
          detailEn: 'Fresh noodles, water spinach, cucumber',
          usd: 2.50,
        ),
        Dish(
          id: 'nbc_coco',
          nameKm: 'នំបញ្ចុកសម្លរកោះ',
          nameEn: 'Nom banh chok, coconut curry',
          detailKm: 'សម្លរក្រអូប ស៊ុតព្រៃ',
          detailEn: 'Coconut gravy, quail egg',
          usd: 3,
        ),
        Dish(
          id: 'orange',
          nameKm: 'ទឹកក្រូចខ្មែរ',
          nameEn: 'Khmer orange juice',
          detailKm: 'ក្រូចខ្វិតច្របាច់ដៃ',
          detailEn: 'Hand-squeezed',
          usd: 1,
        ),
      ],
    ),
    Kitchen(
      id: 'pork_rice',
      cityId: 'phnom_penh',
      nameKm: 'បាយសាច់ជ្រូកចំការមន',
      nameEn: 'Chamkarmon pork rice',
      areaKm: 'ចំការមន',
      areaEn: 'Chamkarmon',
      latitude: 11.5458,
      longitude: 104.9230,
      etaMin: 18,
      deliveryUsd: 0.35,
      rating: 4.7,
      typicalReplySeconds: 900,
      menu: [
        Dish(
          id: 'bai_sach',
          nameKm: 'បាយសាច់ជ្រូក',
          nameEn: 'Pork rice plate',
          detailKm: 'សាច់អាំង ស៊ុតดาว ទឹកត្រីផ្អែម',
          detailEn: 'Grilled pork, fried egg, sweet fish sauce',
          usd: 2.25,
        ),
        Dish(
          id: 'pork_soup',
          nameKm: 'ស៊ុបសាច់ជ្រូក',
          nameEn: 'Clear pork soup',
          detailKm: 'ឆ្អឹងជំនីរ ល្ពៅ',
          detailEn: 'Ribs and gourd',
          usd: 2,
        ),
      ],
    ),
    Kitchen(
      id: 'kampot_grill',
      cityId: 'phnom_penh',
      nameKm: 'កាពិក្រសាំងអាំង',
      nameEn: 'Kampot pepper grill',
      areaKm: 'បឹងកេងកង ១',
      areaEn: 'BKK1',
      latitude: 11.5557,
      longitude: 104.9235,
      etaMin: 28,
      deliveryUsd: 0.50,
      rating: 4.9,
      menu: [
        Dish(
          id: 'beef_pepper',
          nameKm: 'សាច់គោអាំងម្រេចកំពត',
          nameEn: 'Kampot-pepper beef',
          detailKm: 'ម្រេចចាស់ ២៥ក្រាម',
          detailEn: 'Aged Kampot pepper, 25g',
          usd: 5.50,
        ),
        Dish(
          id: 'crab',
          nameKm: 'ក្តាមឆាម្រេចកំពត',
          nameEn: 'Kampot-pepper crab',
          detailKm: 'ក្តាមស្រស់ឆ្នេរខេត្តកំពត',
          detailEn: 'Coastal crab, Kampot pepper',
          usd: 7,
        ),
      ],
    ),
    Kitchen(
      id: 'angkor_khmer',
      cityId: 'siem_reap',
      nameKm: 'ម្ហូបខ្មែរអង្គរ',
      nameEn: 'Angkor Khmer kitchen',
      areaKm: 'ផ្សារចាស់',
      areaEn: 'Old Market',
      latitude: 13.3540,
      longitude: 103.8550,
      etaMin: 20,
      deliveryUsd: 0.40,
      rating: 4.8,
      menu: [
        Dish(
          id: 'amok',
          nameKm: 'អាម៉ុកត្រី',
          nameEn: 'Fish amok',
          detailKm: 'ស្លឹកគ្រៃ ស្លឹកក្រូចសណ្ដាយ ចំហុយក្នុងស្លឹកចេក',
          detailEn: 'Lemongrass, kaffir, steamed in banana leaf',
          usd: 4.25,
        ),
        Dish(
          id: 'sr_nbc',
          nameKm: 'នំបញ្ចុកសម្លរខ្មែរ',
          nameEn: 'Nom banh chok, Khmer curry',
          detailKm: 'រូបមន្តសៀមរាប ប្រហិតស្រស់',
          detailEn: 'Siem Reap-style noodles',
          usd: 2.75,
        ),
        Dish(
          id: 'kari',
          nameKm: 'មាន់ខ្វៃអង្គរ',
          nameEn: 'Angkor roasted chicken',
          detailKm: 'ក្រអូបខ្ទិះ ម្ទេសដី',
          detailEn: 'Coconut, ground chilli',
          usd: 4,
        ),
      ],
    ),
    Kitchen(
      id: 'old_market_cafe',
      cityId: 'siem_reap',
      nameKm: 'កាហ្វេផ្សារចាស់',
      nameEn: 'Old Market coffee',
      areaKm: 'ផ្សាររាត្រី',
      areaEn: 'Night market',
      latitude: 13.3535,
      longitude: 103.8542,
      etaMin: 15,
      deliveryUsd: 0.35,
      rating: 4.6,
      typicalReplySeconds: 720,
      menu: [
        Dish(
          id: 'ice_coffee',
          nameKm: 'កាហ្វេទឹកកកទឹកដោះគោ',
          nameEn: 'Iced milk coffee',
          detailKm: 'គ្រាប់រតនគិរី',
          detailEn: 'Ratanakiri beans',
          usd: 1.50,
        ),
        Dish(
          id: 'num_paen',
          nameKm: 'នំប៉័ងទួរគី',
          nameEn: 'Khmer baguette',
          detailKm: 'សាច់ក្រក ទឹកស៊ីអ៊ីវផ្អែម',
          detailEn: 'Pâté, sweet soy',
          usd: 1.75,
        ),
      ],
    ),
  ];

  static const popular = <PopularPick>[
    PopularPick(
      cityId: 'phnom_penh',
      window: PopularWindow.hour,
      kitchenId: 'nom_banh_chok',
      dishId: 'nbc_khmer',
      orders: 38,
    ),
    PopularPick(
      cityId: 'phnom_penh',
      window: PopularWindow.day,
      kitchenId: 'pork_rice',
      dishId: 'bai_sach',
      orders: 214,
    ),
    PopularPick(
      cityId: 'phnom_penh',
      window: PopularWindow.week,
      kitchenId: 'kampot_grill',
      dishId: 'beef_pepper',
      orders: 910,
    ),
    PopularPick(
      cityId: 'phnom_penh',
      window: PopularWindow.month,
      kitchenId: 'kampot_grill',
      dishId: 'crab',
      orders: 2406,
    ),
    PopularPick(
      cityId: 'siem_reap',
      window: PopularWindow.hour,
      kitchenId: 'angkor_khmer',
      dishId: 'sr_nbc',
      orders: 41,
    ),
    PopularPick(
      cityId: 'siem_reap',
      window: PopularWindow.day,
      kitchenId: 'angkor_khmer',
      dishId: 'amok',
      orders: 186,
    ),
    PopularPick(
      cityId: 'siem_reap',
      window: PopularWindow.week,
      kitchenId: 'old_market_cafe',
      dishId: 'num_paen',
      orders: 640,
    ),
    PopularPick(
      cityId: 'siem_reap',
      window: PopularWindow.month,
      kitchenId: 'angkor_khmer',
      dishId: 'kari',
      orders: 1988,
    ),
  ];

  static Future<List<Kitchen>> load({bool fail = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (fail) {
      throw const CatalogException();
    }
    return kitchens;
  }

  static Kitchen kitchen(String id) => kitchens.firstWhere((k) => k.id == id);

  static PopularPick? popularNear(
    Iterable<String> kitchenIds,
    PopularWindow window,
  ) {
    final ids = kitchenIds.toSet();
    for (final pick in popular) {
      if (pick.window == window && ids.contains(pick.kitchenId)) return pick;
    }
    return null;
  }

  static PopularPick? popularIn(String cityId, PopularWindow window) {
    PopularPick? anywhere;
    for (final pick in popular) {
      if (pick.window != window) continue;
      if (pick.cityId == cityId) return pick;
      anywhere ??= pick;
    }
    return anywhere;
  }
}

class CatalogException implements Exception {
  const CatalogException();
}
