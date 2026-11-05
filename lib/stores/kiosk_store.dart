import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KioskStore extends ChangeNotifier {
  KioskStore._(); static final KioskStore instance=KioskStore._();
  Set<String> _favorites=<String>{}; bool _loaded=false; String _layout='shelf'; String? _profileId;
  Set<String> get favorites=>Set.unmodifiable(_favorites); String get layout=>_layout;
  Future<void> load(String? profileId) async {final id=(profileId ?? 'default').trim().isEmpty?'default':profileId!.trim();if(_loaded&&_profileId==id)return;_profileId=id;final prefs=await SharedPreferences.getInstance();_favorites=(prefs.getStringList(_key(id)) ?? const []).toSet();_layout=prefs.getString('${_key(id)}_layout') ?? 'shelf';_loaded=true;notifyListeners();}
  bool isFavorite(String id)=>_favorites.contains(id);
  Future<void> toggleFavorite(String id) async {if(_favorites.contains(id)){_favorites.remove(id);}else{_favorites.add(id);}final prefs=await SharedPreferences.getInstance();await prefs.setStringList(_key(_profileId ?? 'default'),_favorites.toList());notifyListeners();}
  Future<void> setLayout(String layout) async {if(!{'shelf','poster-wall','compact'}.contains(layout))return;_layout=layout;final prefs=await SharedPreferences.getInstance();await prefs.setString('${_key(_profileId ?? 'default')}_layout',layout);notifyListeners();}
  String _key(String id)=>'owned_media_kiosk_$id';
}
