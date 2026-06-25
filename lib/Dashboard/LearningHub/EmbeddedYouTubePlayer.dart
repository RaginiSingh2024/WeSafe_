import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:womensafteyhackfair/constants.dart';

class EmbeddedYouTubePlayer extends StatelessWidget {
  final String videoId;
  final String title;

  const EmbeddedYouTubePlayer({
    Key? key,
    required this.videoId,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Standard embed URL with clean controls and autoplay
    final String embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1&modestbranding=1&rel=0&showinfo=0';

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.primaryDark,
        appBar: AppBar(
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppColors.primaryDark,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 64),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
                label: Text(
                  "Watch Video on YouTube",
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final Uri uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return WebviewScaffold(
      url: embedUrl,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            final flutterWebviewPlugin = FlutterWebviewPlugin();
            flutterWebviewPlugin.close();
            Navigator.pop(context);
          },
        ),
      ),
      withZoom: false,
      withLocalStorage: true,
      hidden: true,
      initialChild: Container(
        color: AppColors.primaryDark,
        child: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
        ),
      ),
    );
  }
}
