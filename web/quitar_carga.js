// Quita el mensaje "Cargando…" apenas Flutter dibuja la primera pantalla.
// (Archivo aparte y no inline, para permitir una política de seguridad
// de contenido estricta sin 'unsafe-inline' en scripts.)
window.addEventListener('flutter-first-frame', function () {
  var el = document.getElementById('cargando');
  if (el) el.remove();
});
