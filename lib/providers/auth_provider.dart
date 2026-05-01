import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/auth_repository.dart';

/// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// Auth state stream (Session changes)
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current user profile — refetches on auth state change
final profileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final session = authState.valueOrNull;
  if (session == null || session.session == null) return null;
  
  final repo = ref.read(authRepositoryProvider);
  return await repo.getProfile();
});

/// Current user role (convenience)
final userRoleProvider = Provider<String?>((ref) {
  final profile = ref.watch(profileProvider);
  return profile.valueOrNull?.role;
});
