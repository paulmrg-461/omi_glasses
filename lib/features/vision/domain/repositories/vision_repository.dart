abstract class VisionRepository {
  Future<String> describeImage({
    required List<int> imageBytes,
    required String apiKey,
    String model,
  });
}
