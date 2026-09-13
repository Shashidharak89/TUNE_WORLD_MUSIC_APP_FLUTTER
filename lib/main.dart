import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/audio_handler.dart';
import 'providers/auth_provider.dart';
import 'providers/audio_provider.dart';
import 'providers/playlist_provider.dart';
import 'theme/app_theme.dart';
import 'views/home_screen.dart';

late TuneWorldAudioHandler _audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background audio handler for system notification bar controls
  _audioHandler = (await initAudioService()) as TuneWorldAudioHandler;

  runApp(const TuneWorldApp());
}

class TuneWorldApp extends StatelessWidget {
  const TuneWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
      ],
      child: MaterialApp(
        title: 'Tune World',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: HomeScreen(audioHandler: _audioHandler),
      ),
    );
  }
}
