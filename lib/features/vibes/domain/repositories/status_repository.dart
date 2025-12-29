import 'package:image_picker/image_picker.dart';
import '../entities/user_status.dart';

abstract class StatusRepository {
  Future<void> uploadStatus(XFile file, bool isVideo, {String? caption});
  Future<List<UserStatus>> getActiveStatuses();
  Future<void> deleteStatus(String statusId);
  Future<void> markStatusViewed(String statusId);
  Stream<void> watchStatusChanges();
}
