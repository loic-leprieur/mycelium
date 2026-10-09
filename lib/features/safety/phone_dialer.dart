import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lance un appel `tel:` ; renvoie false si l'appareil ne peut pas appeler
/// (ordinateur, tablette sans téléphonie). Remplaçable dans les tests.
typedef PhoneDialer = Future<bool> Function(Uri uri);

final phoneDialerProvider = Provider<PhoneDialer>((ref) => launchUrl);
