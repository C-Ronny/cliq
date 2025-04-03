// contains constants: colors, API keys (loaded from .env)
import 'package:supabase_flutter/supabase_flutter.dart';



import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  static String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String agoraAppId = dotenv.env['AGORA_APP_ID'] ?? '';
  static final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);
}