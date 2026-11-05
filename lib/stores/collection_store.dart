import 'package:flutter/foundation.dart';
import '../data/collection_repository.dart';
import '../models/media_collection_models.dart';

class CollectionStore extends ChangeNotifier {
  CollectionStore._(); static final CollectionStore instance=CollectionStore._();
  final CollectionRepository _repository=const CollectionRepository();
  List<MediaCollection> _collections=const []; bool _loaded=false;
  List<MediaCollection> get collections=>List.unmodifiable(_collections); bool get isLoaded=>_loaded;
  void load(){_collections=_repository.fromLibrary();_loaded=true;notifyListeners();}
  void refresh(){load();}
}
