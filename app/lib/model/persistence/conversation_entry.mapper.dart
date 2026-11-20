// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'conversation_entry.dart';

class ConversationDeliveryMapper extends EnumMapper<ConversationDelivery> {
  ConversationDeliveryMapper._();

  static ConversationDeliveryMapper? _instance;
  static ConversationDeliveryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ConversationDeliveryMapper._());
    }
    return _instance!;
  }

  static ConversationDelivery fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  ConversationDelivery decode(dynamic value) {
    switch (value) {
      case r'waiting':
        return ConversationDelivery.waiting;
      case r'sending':
        return ConversationDelivery.sending;
      case r'delivered':
        return ConversationDelivery.delivered;
      case r'failed':
        return ConversationDelivery.failed;
      case r'declined':
        return ConversationDelivery.declined;
      case r'cancelled':
        return ConversationDelivery.cancelled;
      case r'interrupted':
        return ConversationDelivery.interrupted;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(ConversationDelivery self) {
    switch (self) {
      case ConversationDelivery.waiting:
        return r'waiting';
      case ConversationDelivery.sending:
        return r'sending';
      case ConversationDelivery.delivered:
        return r'delivered';
      case ConversationDelivery.failed:
        return r'failed';
      case ConversationDelivery.declined:
        return r'declined';
      case ConversationDelivery.cancelled:
        return r'cancelled';
      case ConversationDelivery.interrupted:
        return r'interrupted';
    }
  }
}

extension ConversationDeliveryMapperExtension on ConversationDelivery {
  String toValue() {
    ConversationDeliveryMapper.ensureInitialized();
    return MapperContainer.globals.toValue<ConversationDelivery>(this)
        as String;
  }
}

class ConversationEntryMapper extends ClassMapperBase<ConversationEntry> {
  ConversationEntryMapper._();

  static ConversationEntryMapper? _instance;
  static ConversationEntryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ConversationEntryMapper._());
      DeviceMapper.ensureInitialized();
      ConversationDeliveryMapper.ensureInitialized();
      FileTypeMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'ConversationEntry';

  static String _$id(ConversationEntry v) => v.id;
  static const Field<ConversationEntry, String> _f$id = Field('id', _$id);
  static Device _$peer(ConversationEntry v) => v.peer;
  static const Field<ConversationEntry, Device> _f$peer = Field('peer', _$peer);
  static bool _$outgoing(ConversationEntry v) => v.outgoing;
  static const Field<ConversationEntry, bool> _f$outgoing = Field(
    'outgoing',
    _$outgoing,
  );
  static DateTime _$timestamp(ConversationEntry v) => v.timestamp;
  static const Field<ConversationEntry, DateTime> _f$timestamp = Field(
    'timestamp',
    _$timestamp,
  );
  static ConversationDelivery _$delivery(ConversationEntry v) => v.delivery;
  static const Field<ConversationEntry, ConversationDelivery> _f$delivery =
      Field('delivery', _$delivery);
  static String _$sessionId(ConversationEntry v) => v.sessionId;
  static const Field<ConversationEntry, String> _f$sessionId = Field(
    'sessionId',
    _$sessionId,
  );
  static String _$fileId(ConversationEntry v) => v.fileId;
  static const Field<ConversationEntry, String> _f$fileId = Field(
    'fileId',
    _$fileId,
  );
  static String _$fileName(ConversationEntry v) => v.fileName;
  static const Field<ConversationEntry, String> _f$fileName = Field(
    'fileName',
    _$fileName,
  );
  static FileType _$fileType(ConversationEntry v) => v.fileType;
  static const Field<ConversationEntry, FileType> _f$fileType = Field(
    'fileType',
    _$fileType,
  );
  static int _$fileSize(ConversationEntry v) => v.fileSize;
  static const Field<ConversationEntry, int> _f$fileSize = Field(
    'fileSize',
    _$fileSize,
  );
  static String? _$text(ConversationEntry v) => v.text;
  static const Field<ConversationEntry, String> _f$text = Field('text', _$text);
  static String? _$path(ConversationEntry v) => v.path;
  static const Field<ConversationEntry, String> _f$path = Field('path', _$path);
  static bool _$savedToGallery(ConversationEntry v) => v.savedToGallery;
  static const Field<ConversationEntry, bool> _f$savedToGallery = Field(
    'savedToGallery',
    _$savedToGallery,
    opt: true,
    def: false,
  );
  static String? _$error(ConversationEntry v) => v.error;
  static const Field<ConversationEntry, String> _f$error = Field(
    'error',
    _$error,
    opt: true,
  );

  @override
  final MappableFields<ConversationEntry> fields = const {
    #id: _f$id,
    #peer: _f$peer,
    #outgoing: _f$outgoing,
    #timestamp: _f$timestamp,
    #delivery: _f$delivery,
    #sessionId: _f$sessionId,
    #fileId: _f$fileId,
    #fileName: _f$fileName,
    #fileType: _f$fileType,
    #fileSize: _f$fileSize,
    #text: _f$text,
    #path: _f$path,
    #savedToGallery: _f$savedToGallery,
    #error: _f$error,
  };

  static ConversationEntry _instantiate(DecodingData data) {
    return ConversationEntry(
      id: data.dec(_f$id),
      peer: data.dec(_f$peer),
      outgoing: data.dec(_f$outgoing),
      timestamp: data.dec(_f$timestamp),
      delivery: data.dec(_f$delivery),
      sessionId: data.dec(_f$sessionId),
      fileId: data.dec(_f$fileId),
      fileName: data.dec(_f$fileName),
      fileType: data.dec(_f$fileType),
      fileSize: data.dec(_f$fileSize),
      text: data.dec(_f$text),
      path: data.dec(_f$path),
      savedToGallery: data.dec(_f$savedToGallery),
      error: data.dec(_f$error),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static ConversationEntry fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<ConversationEntry>(map);
  }

  static ConversationEntry deserialize(String json) {
    return ensureInitialized().decodeJson<ConversationEntry>(json);
  }
}

mixin ConversationEntryMappable {
  String serialize() {
    return ConversationEntryMapper.ensureInitialized()
        .encodeJson<ConversationEntry>(this as ConversationEntry);
  }

  Map<String, dynamic> toJson() {
    return ConversationEntryMapper.ensureInitialized()
        .encodeMap<ConversationEntry>(this as ConversationEntry);
  }

  ConversationEntryCopyWith<
    ConversationEntry,
    ConversationEntry,
    ConversationEntry
  >
  get copyWith =>
      _ConversationEntryCopyWithImpl<ConversationEntry, ConversationEntry>(
        this as ConversationEntry,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ConversationEntryMapper.ensureInitialized().stringifyValue(
      this as ConversationEntry,
    );
  }

  @override
  bool operator ==(Object other) {
    return ConversationEntryMapper.ensureInitialized().equalsValue(
      this as ConversationEntry,
      other,
    );
  }

  @override
  int get hashCode {
    return ConversationEntryMapper.ensureInitialized().hashValue(
      this as ConversationEntry,
    );
  }
}

extension ConversationEntryValueCopy<$R, $Out>
    on ObjectCopyWith<$R, ConversationEntry, $Out> {
  ConversationEntryCopyWith<$R, ConversationEntry, $Out>
  get $asConversationEntry => $base.as(
    (v, t, t2) => _ConversationEntryCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class ConversationEntryCopyWith<
  $R,
  $In extends ConversationEntry,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  DeviceCopyWith<$R, Device, Device> get peer;
  $R call({
    String? id,
    Device? peer,
    bool? outgoing,
    DateTime? timestamp,
    ConversationDelivery? delivery,
    String? sessionId,
    String? fileId,
    String? fileName,
    FileType? fileType,
    int? fileSize,
    String? text,
    String? path,
    bool? savedToGallery,
    String? error,
  });
  ConversationEntryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _ConversationEntryCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, ConversationEntry, $Out>
    implements ConversationEntryCopyWith<$R, ConversationEntry, $Out> {
  _ConversationEntryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<ConversationEntry> $mapper =
      ConversationEntryMapper.ensureInitialized();
  @override
  DeviceCopyWith<$R, Device, Device> get peer =>
      $value.peer.copyWith.$chain((v) => call(peer: v));
  @override
  $R call({
    String? id,
    Device? peer,
    bool? outgoing,
    DateTime? timestamp,
    ConversationDelivery? delivery,
    String? sessionId,
    String? fileId,
    String? fileName,
    FileType? fileType,
    int? fileSize,
    Object? text = $none,
    Object? path = $none,
    bool? savedToGallery,
    Object? error = $none,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (peer != null) #peer: peer,
      if (outgoing != null) #outgoing: outgoing,
      if (timestamp != null) #timestamp: timestamp,
      if (delivery != null) #delivery: delivery,
      if (sessionId != null) #sessionId: sessionId,
      if (fileId != null) #fileId: fileId,
      if (fileName != null) #fileName: fileName,
      if (fileType != null) #fileType: fileType,
      if (fileSize != null) #fileSize: fileSize,
      if (text != $none) #text: text,
      if (path != $none) #path: path,
      if (savedToGallery != null) #savedToGallery: savedToGallery,
      if (error != $none) #error: error,
    }),
  );
  @override
  ConversationEntry $make(CopyWithData data) => ConversationEntry(
    id: data.get(#id, or: $value.id),
    peer: data.get(#peer, or: $value.peer),
    outgoing: data.get(#outgoing, or: $value.outgoing),
    timestamp: data.get(#timestamp, or: $value.timestamp),
    delivery: data.get(#delivery, or: $value.delivery),
    sessionId: data.get(#sessionId, or: $value.sessionId),
    fileId: data.get(#fileId, or: $value.fileId),
    fileName: data.get(#fileName, or: $value.fileName),
    fileType: data.get(#fileType, or: $value.fileType),
    fileSize: data.get(#fileSize, or: $value.fileSize),
    text: data.get(#text, or: $value.text),
    path: data.get(#path, or: $value.path),
    savedToGallery: data.get(#savedToGallery, or: $value.savedToGallery),
    error: data.get(#error, or: $value.error),
  );

  @override
  ConversationEntryCopyWith<$R2, ConversationEntry, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _ConversationEntryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

