import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

class ShadcnFallbackLocalizationsDelegate
    extends LocalizationsDelegate<shadcn.ShadcnLocalizations> {
  const ShadcnFallbackLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'ko' || locale.languageCode == 'en';
  }

  @override
  Future<shadcn.ShadcnLocalizations> load(Locale locale) {
    // shadcn_flutter 0.0.51 only ships English resources.
    return shadcn.ShadcnLocalizations.delegate.load(const Locale('en'));
  }

  @override
  bool shouldReload(ShadcnFallbackLocalizationsDelegate old) => false;
}
