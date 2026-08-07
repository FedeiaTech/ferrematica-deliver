import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/providers.dart';
import 'supabase_catalog_remote.dart';

/// The [CatalogRemote] port, backed by the real `supabase_flutter` client.
final Provider<CatalogRemote> catalogRemoteProvider = Provider<CatalogRemote>(
  (ref) => SupabaseCatalogRemote(ref.watch(supabaseProvider)),
);
