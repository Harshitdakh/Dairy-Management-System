import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Note: .env load error (using defaults if needed): $e');
  }

  const defaultUrl = 'https://heypwnxdzuosonxasnqb.supabase.co';
  const defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhleXB3bnhkenVvc29ueGFzbnFiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4ODk4ODQsImV4cCI6MjA4NjQ2NTg4NH0.XVI-0mAjMBO7a37o32VAF5qnhUKjHpXZ03MOLNR_O9Y';

  final supabaseUrl =
      (dotenv.env['SUPABASE_URL'] != null && dotenv.env['SUPABASE_URL']!.isNotEmpty)
          ? dotenv.env['SUPABASE_URL']!
          : defaultUrl;

  final supabaseAnonKey =
      (dotenv.env['SUPABASE_ANON_KEY'] != null && dotenv.env['SUPABASE_ANON_KEY']!.isNotEmpty)
          ? dotenv.env['SUPABASE_ANON_KEY']!
          : defaultAnonKey;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const ProviderScope(child: MilkHubApp()));
}

final supabase = Supabase.instance.client;

