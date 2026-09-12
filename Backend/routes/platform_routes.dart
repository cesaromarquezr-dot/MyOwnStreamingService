// FILE: `Backend/routes/platform_routes.dart`.
// Purpose: Implements the platform routes portion of the streaming service.
// This file is part of the documented Flutter/home-server architecture.

import 'dart:convert';
import 'dart:io';
import '../middleware/authentication.dart';
class PlatformRoutes {
  final AuthenticationMiddleware authentication;
  PlatformRoutes({required this.authentication});
  /// Performs `handle` for this feature. Update this documentation when its contract changes.
  Future<void> handle(HttpRequest request) async {
    final auth=authentication.authenticate(request);
    if(auth==null)return _json(request,401,{'success':false,'error':'Authentication required.'});
    final path=request.uri.path;
    if(request.method=='GET'&&path=='/api/v1/platform/capabilities') return _json(request,200,{'success':true,'capabilities':{'aiConcierge':true,'naturalLanguageSearch':true,'adaptiveStreaming':true,'watchParties':true,'cloudSync':true,'libraryScanner':true,'metadataEnrichment':true,'multiVersionMedia':true,'twoFactorReady':true,'familyControls':true,'remoteSessions':true,'crossPlatform':['android','ios','windows','macos','linux','web','android_tv','apple_tv','fire_tv']}});
    if(request.method=='GET'&&path=='/api/v1/platform/dashboard') return _json(request,200,{'success':true,'accountId':auth.id,'cloudSync':true,'security':{'twoFactor':false},'server':{'status':'online'}});
    return _json(request,404,{'success':false,'error':'Platform route not found.'});
  }
  /// Performs `_json` for this feature. Update this documentation when its contract changes.
  Future<void> _json(HttpRequest r,int status,Map<String,dynamic> body)async{r.response.statusCode=status;r.response.headers.contentType=ContentType.json;r.response.write(jsonEncode(body));await r.response.close();}
}
