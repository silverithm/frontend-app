class AppSpacing {
  static const double none = 0;
  static const double px = 1;
  static const double space0_5 = 2;
  static const double space1 = 4;
  static const double space1_5 = 6;
  static const double space2 = 8;
  static const double space2_5 = 10;
  static const double space3 = 12;
  static const double space3_5 = 14;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 28;
  static const double space8 = 32;
  static const double space9 = 36;
  static const double space10 = 40;
  static const double space12 = 48;
  static const double space14 = 56;
  static const double space16 = 64;
  static const double space20 = 80;
}

class AppBorderRadius {
  static const double none = 0;
  static const double sm = 2;
  static const double base = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double xl2 = 16;
  static const double xl3 = 24;
  static const double full = 9999;
}

class AppShadows {
  static const List<double> xs = [0, 1, 2, 0];
  static const List<double> sm = [0, 1, 3, 0];
  static const List<double> base = [0, 4, 6, -1];
  static const List<double> md = [0, 10, 15, -3];
  static const List<double> lg = [0, 20, 25, -5];
  static const List<double> xl = [0, 25, 50, -12];
}

class AppTransitions {
  static const Duration fastest = Duration(milliseconds: 75);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slowest = Duration(milliseconds: 500);
}