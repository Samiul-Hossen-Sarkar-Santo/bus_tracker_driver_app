class RouteCatalogItem {
  final String routeId;
  final String routeName;

  const RouteCatalogItem({
    required this.routeId,
    required this.routeName,
  });
}

class BusCatalogItem {
  final String busId;
  final String routeId;
  final String routeName;
  final String busNumber;
  final String driverName;

  const BusCatalogItem({
    required this.busId,
    required this.routeId,
    required this.routeName,
    required this.busNumber,
    required this.driverName,
  });

  String get dropdownLabel => '$busNumber - $driverName';
}

const List<RouteCatalogItem> routeCatalog = [
  RouteCatalogItem(routeId: 'uttara', routeName: 'উত্তরা'),
  RouteCatalogItem(routeId: 'jfpkakrail', routeName: 'জেএফপি-কাকরাইল'),
  RouteCatalogItem(routeId: 'mogbazarkakrail', routeName: 'মগবাজার-কাকরাইল'),
  RouteCatalogItem(routeId: 'shahbagh', routeName: 'শাহবাগ'),
  RouteCatalogItem(routeId: 'khamarbarimor', routeName: 'খামার বাড়ি মোর'),
  RouteCatalogItem(routeId: 'asadgate', routeName: 'আসাদ গেট'),
  RouteCatalogItem(routeId: 'citycollege', routeName: 'সিটি কলেজ'),
  RouteCatalogItem(routeId: 'jahangirgate', routeName: 'জাহাঙ্গীর গেট'),
  RouteCatalogItem(routeId: 'parbatcinemahall',routeName: 'পুরাতন পর্বত/পর্বত সিনেমা হল'),
];

const List<BusCatalogItem> busCatalog = [
  BusCatalogItem(
    busId: 'uttara1',
    routeId: 'uttara',
    routeName: 'উত্তরা',
    busNumber: '০৪৯৪',
    driverName: 'আশরাফ',
  ),
  BusCatalogItem(
    busId: 'uttara2',
    routeId: 'uttara',
    routeName: 'উত্তরা',
    busNumber: '০৪৭২',
    driverName: 'মাহমুদ',
  ),
  BusCatalogItem(
    busId: 'jfpkakrail1',
    routeId: 'jfpkakrail',
    routeName: 'জেএফপি-কাকরাইল',
    busNumber: '০৩৫৩',
    driverName: 'বারেক',
  ),
  BusCatalogItem(
    busId: 'jfpkakrail2',
    routeId: 'jfpkakrail',
    routeName: 'জেএফপি-কাকরাইল',
    busNumber: '০৩৫৪',
    driverName: 'মোন্নাফ',
  ),
  BusCatalogItem(
    busId: 'jfpkakrail3',
    routeId: 'jfpkakrail',
    routeName: 'জেএফপি-কাকরাইল',
    busNumber: '৫১৫৭',
    driverName: 'আল আমিন',
  ),
  BusCatalogItem(
    busId: 'mogbazarkakrail1',
    routeId: 'mogbazarkakrail',
    routeName: 'মগবাজার-কাকরাইল',
    busNumber: '০২৯৩',
    driverName: 'জসিম',
  ),
  BusCatalogItem(
    busId: 'shahbagh1',
    routeId: 'shahbagh',
    routeName: 'শাহবাগ',
    busNumber: '০৪২৬',
    driverName: 'ফায়জুল',
  ),
  BusCatalogItem(
    busId: 'shahbagh2',
    routeId: 'shahbagh',
    routeName: 'শাহবাগ',
    busNumber: '০৩০০',
    driverName: 'কাউসার',
  ),
  BusCatalogItem(
    busId: 'khamarbarimor1',
    routeId: 'khamarbarimor',
    routeName: 'খামার বাড়ি মোর',
    busNumber: '০২৯১',
    driverName: 'নুহু আলম',
  ),
  BusCatalogItem(
    busId: 'khamarbarimor2',
    routeId: 'khamarbarimor',
    routeName: 'খামার বাড়ি মোর',
    busNumber: '০২৯৫',
    driverName: 'বাদশা',
  ),
  BusCatalogItem(
    busId: 'asadgate1',
    routeId: 'asadgate',
    routeName: 'আসাদ গেট',
    busNumber: '০৪০২',
    driverName: 'ছলেমান',
  ),
  BusCatalogItem(
    busId: 'asadgate2',
    routeId: 'asadgate',
    routeName: 'আসাদ গেট',
    busNumber: '০৩০১',
    driverName: 'জয়নাল',
  ),
  BusCatalogItem(
    busId: 'citycollege1',
    routeId: 'citycollege',
    routeName: 'সিটি কলেজ',
    busNumber: '০৪৭১',
    driverName: 'তৈয়ব',
  ),
  BusCatalogItem(
    busId: 'citycollege2',
    routeId: 'citycollege',
    routeName: 'সিটি কলেজ',
    busNumber: '০৪২৪',
    driverName: 'ওবায়দুল',
  ),
  BusCatalogItem(
    busId: 'jahangirgate1',
    routeId: 'jahangirgate',
    routeName: 'জাহাঙ্গীর গেট',
    busNumber: '০২৯২',
    driverName: 'ইউনুছ',
  ),
  BusCatalogItem(
    busId: 'jahangirgate2',
    routeId: 'jahangirgate',
    routeName: 'জাহাঙ্গীর গেট',
    busNumber: '০৪০১',
    driverName: 'গোলাপ',
  ),
  BusCatalogItem(
    busId: 'parbatcinemahall1',
    routeId: 'parbatcinemahall',
    routeName: 'পুরাতন পর্বত/পর্বত সিনেমা হল',
    busNumber: '৬০২০',
    driverName: 'শাহাবুদ্দিন',
  ),
];

List<BusCatalogItem> busesForRoute(String routeId) {
  return busCatalog.where((bus) => bus.routeId == routeId).toList();
}
