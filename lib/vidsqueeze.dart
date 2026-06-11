/// Flutter video compression plugin powered by native Android and iOS encoders.
///
/// Use [Vidsqueeze.instance] to start compression, listen to progress states,
/// and cancel active work by task id.
library vidsqueeze;

export 'src/models/compression_request.dart';
export 'src/models/compression_result.dart';
export 'src/models/compression_resolution_cap.dart';
export 'src/models/compression_state.dart';
export 'src/models/compression_preset.dart';
export 'src/models/force_codec.dart';
export 'src/vidsqueeze.dart';
