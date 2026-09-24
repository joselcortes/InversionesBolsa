// Descarga un archivo de texto: en la versión web lo baja directo desde el
// navegador; en el celular no aplica (ahí se usa "Compartir").
export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
