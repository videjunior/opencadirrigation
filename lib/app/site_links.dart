/// Addresses of the pages of the public site that the app links to, in the
/// interface language: the site has one folder per language (`/pt/`,
/// `/es/`, …), English at the root (tool/site.dart).
library;

import 'version.dart' show appSiteUrl;

/// A page of the site in [lang]: `https://opencadirrigation.com/pt/privacy/`,
/// `https://opencadirrigation.com/privacy/` in English.
String sitePageUrl(String lang, String page) => '$appSiteUrl/${lang == 'en' ? '' : '$lang/'}$page/';

/// The privacy policy of the site and the app, in [lang].
String privacyPolicyUrl(String lang) => sitePageUrl(lang, 'privacy');

/// The terms of use, in [lang].
String termsOfUseUrl(String lang) => sitePageUrl(lang, 'terms');
