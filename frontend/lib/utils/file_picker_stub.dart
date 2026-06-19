class PickedFilePayload {
  final String data;
  final String name;
  final String type;

  PickedFilePayload({required this.data, required this.name, required this.type});
}

Future<PickedFilePayload?> pickFileAttachment() async {
  throw UnimplementedError('Platform not supported');
}
