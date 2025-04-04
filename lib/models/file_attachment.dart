class FileAttachment {
  final String path;
  final String name;
  final String type;
  final int size;
  final String? base64Content;

  FileAttachment({
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    this.base64Content,
  });
} 