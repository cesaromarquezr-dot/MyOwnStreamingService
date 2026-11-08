import '../repositories/theater_repository.dart';
class TheaterService {
  const TheaterService(this.repository); final TheaterRepository repository;
  Future<Map<String,dynamic>> createSession(String accountId,String profileId,Map<String,dynamic> input) async {
    final mediaId=input['mediaId']?.toString().trim() ?? ''; final title=input['title']?.toString().trim() ?? '';
    if(mediaId.isEmpty || title.isEmpty) throw ArgumentError('A media ID and title from your library are required.');
    final seats=(input['seatIds'] as List? ?? const []).map((v)=>v.toString()).take(32).toList(growable:false);
    final now=DateTime.now().toUtc(); final id='theater_${now.microsecondsSinceEpoch}';
    final record=<String,dynamic>{'id':id,'mediaId':mediaId,'title':title,'roomId':input['roomId']?.toString() ?? 'room-1','seatIds':seats,'status':'ready','createdAt':now.toIso8601String(),'privateViewing':true,'paymentRequired':false};
    await repository.saveSession(accountId,profileId,id,record); return record;
  }
  Future<List<Map<String,dynamic>>> listSessions(String accountId,String profileId) => repository.listSessions(accountId,profileId);
}
