import 'package:flutter/material.dart';
import '../models/media_models.dart';

class ImageGallery extends StatelessWidget {
  final List<MediaImage> images;

  const ImageGallery({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(child: Text("No Images"));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final img = images[index];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(),
                  body: Center(child: Image.network(img.url)),
                ),
              ),
            );
          },
          child: Image.network(
            img.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;

              return const Center(child: CircularProgressIndicator());
            },
          ),
        );
      },
    );
  }
}
