// FILE: `lib/profile_artwork.dart`.
// Purpose: Lets a profile select approved artwork from imported/local media.
//
// This screen displays artwork associated with media in the current library.
// Selecting an image updates the profile avatar and, when authenticated,
// persists the change through the backend API. The original media artwork
// remains unchanged.

import 'dart:io';

import 'package:flutter/material.dart';

import 'app_core.dart';

class ProfileArtworkScreen extends StatefulWidget {
  final Profile profile;

  const ProfileArtworkScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileArtworkScreen> createState() => _ProfileArtworkScreenState();
}

class _ProfileArtworkScreenState extends State<ProfileArtworkScreen> {
  @override
  Widget build(BuildContext context) {
    final candidates = AppController.instance.library
        .where(
          (m) => m.imageUrl != null && m.imageUrl!.isNotEmpty,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.profile.name} Artwork'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Choose artwork from your library',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'ARM can expose disc artwork, scans and other approved media '
            'artwork here. The original media artwork is never replaced.',
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: .78,
            ),
            itemCount: candidates.length,
            itemBuilder: (_, index) {
              final media = candidates[index];

              return InkWell(
                onTap: () async {
                  // Update the selected profile locally.
                  widget.profile.avatarUrl = media.imageUrl;

                  // Persist the selected artwork when the backend session
                  // is authenticated.
                  if (AppController.instance.isBackendAuthenticated) {
                    try {
                      await AppController.instance.backendApi.updateProfile(
                        profileId: widget.profile.id,
                        name: widget.profile.name,
                        avatarUrl: media.imageUrl,
                      );
                    } catch (_) {
                      // Keep the local selection even if the backend update
                      // fails. The surrounding application can handle
                      // synchronization/retry separately.
                    }
                  }

                  // Return to the previous screen after the artwork has
                  // been selected and the backend update has been attempted.
                  if (mounted) {
                    Navigator.pop(this.context);
                  }
                },
                child: Column(
                  children: [
                    Expanded(
                      child: _image(media.imageUrl!),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      media.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Displays artwork from either a remote URL or a local file path.
  ///
  /// If the supplied value is an HTTP/HTTPS URL, the image is loaded from
  /// the network. Otherwise, the value is treated as a local file path.
  /// A fallback icon is displayed when the local file does not exist.
  Widget _image(String value) {
    final file = File(value);

    if (value.startsWith('http')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
      );
    }

    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: Colors.white10,
      child: const Icon(Icons.image),
    );
  }
}