import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/card_sr_data.dart';
import '../objectbox.g.dart';

class ObjectBoxService {
  late final Store store;
  late final Box<CardSRData> srBox;

  ObjectBoxService._create(this.store) {
    srBox = store.box<CardSRData>();
  }

  static Future<ObjectBoxService> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, 'deckit_objectbox');
    final store = await openStore(directory: storePath);
    return ObjectBoxService._create(store);
  }

  void close() => store.close();
}
