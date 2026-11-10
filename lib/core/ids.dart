import 'package:uuid/uuid.dart';

/// Callable that returns a new opaque id string.
typedef IdGenerator = String Function();

const Uuid _uuid = Uuid();

/// Default UUID v4 id generator for production use.
String generateUuidV4() => _uuid.v4();
