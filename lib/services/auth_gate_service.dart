import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';

enum AuthResult {
  ok,
  cancelled,

  /// El teléfono no tiene bloqueo de pantalla/huella configurado.
  notAvailable,

  /// Versión web: no hay forma segura de confirmar identidad.
  webBlocked,
  error,
}

/// Exige huella/rostro/PIN del dispositivo antes de operar o al abrir la
/// app. Falla cerrado: si el sistema de autenticación da error, NO deja
/// pasar.
class AuthGateService {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// [strict]: si es true (modo real o bloqueo de app), un teléfono sin
  /// bloqueo configurado tampoco pasa. En modo paper se permite operar sin
  /// bloqueo de pantalla porque no hay dinero real en juego.
  Future<AuthResult> confirmIdentity({
    required String reason,
    required bool strict,
  }) async {
    // El navegador no tiene huella/PIN del sistema. En la versión web solo
    // se permite lo que no usa dinero real (modo práctica).
    if (kIsWeb) return strict ? AuthResult.webBlocked : AuthResult.ok;
    try {
      if (!await _auth.isDeviceSupported()) {
        return strict ? AuthResult.notAvailable : AuthResult.ok;
      }
      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return ok ? AuthResult.ok : AuthResult.cancelled;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.passcodeNotSet ||
          e.code == auth_error.notEnrolled) {
        return strict ? AuthResult.notAvailable : AuthResult.ok;
      }
      return AuthResult.error;
    } catch (_) {
      return AuthResult.error;
    }
  }

  static String failureMessage(AuthResult r) => switch (r) {
        AuthResult.ok => '',
        AuthResult.cancelled => 'Autenticación cancelada.',
        AuthResult.notAvailable =>
          'Configura un bloqueo de pantalla (PIN, huella o rostro) en el teléfono para continuar.',
        AuthResult.webBlocked =>
          'Por seguridad, en la versión web no se pueden hacer operaciones con dinero real. '
              'Usa la app del celular (pide tu huella) o el modo práctica.',
        AuthResult.error => 'No se pudo verificar tu identidad. Intenta de nuevo.',
      };
}
