import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class VibeEvent extends Equatable {
  const VibeEvent();

  @override
  List<Object?> get props => [];
}

class LoadVibes extends VibeEvent {}

class UploadVibe extends VibeEvent {
  final XFile file;
  final bool isVideo;
  final String? caption;

  const UploadVibe(this.file, {this.isVideo = false, this.caption});

  @override
  List<Object?> get props => [file, isVideo, caption];
}
