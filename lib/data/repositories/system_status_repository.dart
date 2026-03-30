import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/system_status_model.dart';
import '../firestore/mock_data.dart';

class SystemStatusRepository {
  final FirebaseFirestore? _firestore;
  final bool useMockData;

  SystemStatusRepository({FirebaseFirestore? firestore, this.useMockData = true})
      : _firestore = firestore;

  Stream<List<SystemStatusModel>> watchSystemStatuses() {
    if (useMockData) {
      return Stream.periodic(Duration(seconds: 3), (_) {
        return MockData.mockSystemStatuses.map((status) {
          return SystemStatusModel(
            componentName: status.componentName,
            status: status.status,
            lastHeartbeat: DateTime.now().subtract(
              Duration(seconds: 5 + (status.componentName.hashCode % 10)),
            ),
            version: status.version,
            metadata: status.metadata,
          );
        }).toList();
      }).asBroadcastStream();
    }
    
    return _firestore!
        .collection('system_status')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SystemStatusModel.fromFirestore(doc))
            .toList());
  }

  Future<SystemStatusModel?> getComponentStatus(String componentName) async {
    if (useMockData) {
      await Future.delayed(Duration(milliseconds: 300));
      try {
        return MockData.mockSystemStatuses
            .firstWhere((s) => s.componentName == componentName);
      } catch (e) {
        return null;
      }
    }
    
    final doc =
        await _firestore!.collection('system_status').doc(componentName).get();
    return doc.exists ? SystemStatusModel.fromFirestore(doc) : null;
  }
}
