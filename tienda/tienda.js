// Página "Mi tienda": lee apps.json y dibuja una tarjeta por app.
// Todo el texto se inserta con textContent (nunca innerHTML) para que un
// dato del catálogo no pueda inyectar código en la página.
(function () {
  'use strict';

  var contenedor = document.getElementById('apps');
  var plantilla = document.getElementById('tarjeta');
  var fecha = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'long', year: 'numeric' });

  function mb(bytes) {
    return bytes ? (bytes / (1024 * 1024)).toFixed(1).replace('.', ',') + ' MB' : '';
  }

  function soloRelativa(ruta) {
    // Solo se aceptan rutas relativas dentro de /tienda/ (sin "..", sin dominio).
    return typeof ruta === 'string' && /^[a-zA-Z0-9_./-]+$/.test(ruta) && ruta.indexOf('..') === -1;
  }

  function enlaceApk(ruta) {
    // Los instaladores viven en GitHub Releases (Firebase gratis no permite .apk).
    if (typeof ruta === 'string' && /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/releases\/download\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\.apk$/.test(ruta)) {
      return true;
    }
    return soloRelativa(ruta);
  }

  function tarjeta(app) {
    var nodo = plantilla.content.cloneNode(true);
    var versiones = (app.releases || []).slice().sort(function (a, b) { return b.build - a.build; });
    var actual = versiones[0];

    var icono = nodo.querySelector('.icono');
    if (soloRelativa(app.icon)) icono.src = app.icon; else icono.remove();
    nodo.querySelector('.nombre').textContent = app.name;
    nodo.querySelector('.descripcion').textContent = app.description || '';

    var descargar = nodo.querySelector('.descargar');
    var web = nodo.querySelector('.web');
    if (app.webUrl && /^https:\/\//.test(app.webUrl)) web.href = app.webUrl; else web.hidden = true;

    if (actual) {
      nodo.querySelector('.meta').textContent = [
        'Versión ' + actual.version,
        fecha.format(new Date(actual.date)),
        mb(actual.sizeBytes),
        'Android'
      ].filter(Boolean).join(' · ');

      if (enlaceApk(actual.apk)) {
        descargar.href = actual.apk;
        descargar.textContent = 'Descargar ' + actual.version;
      } else {
        descargar.hidden = true;
      }

      nodo.querySelector('.novedades h4').textContent = 'Novedades de la versión ' + actual.version;
      var lista = nodo.querySelector('.novedades ul');
      (actual.notes || []).forEach(function (n) {
        var li = document.createElement('li');
        li.textContent = n;
        lista.appendChild(li);
      });

      if (actual.sha256) {
        nodo.querySelector('.huella').textContent = 'SHA-256: ' + actual.sha256;
      }
    } else {
      descargar.hidden = true;
      nodo.querySelector('.novedades').remove();
    }

    var anteriores = nodo.querySelector('.anteriores');
    var listaAnt = anteriores.querySelector('ul');
    versiones.slice(1).forEach(function (r) {
      var li = document.createElement('li');
      var titulo = document.createElement('strong');
      titulo.textContent = r.version + ' · ' + fecha.format(new Date(r.date));
      li.appendChild(titulo);
      if (enlaceApk(r.apk)) {
        li.appendChild(document.createTextNode(' — '));
        var a = document.createElement('a');
        a.href = r.apk;
        a.textContent = 'descargar';
        a.setAttribute('download', '');
        li.appendChild(a);
      }
      if (r.notes && r.notes.length) {
        var p = document.createElement('div');
        p.textContent = r.notes.join(' · ');
        li.appendChild(p);
      }
      listaAnt.appendChild(li);
    });
    if (versiones.length < 2) anteriores.remove();

    return nodo;
  }

  fetch('apps.json?t=' + Date.now(), { cache: 'no-store' })
    .then(function (r) {
      if (!r.ok) throw new Error('HTTP ' + r.status);
      return r.json();
    })
    .then(function (catalogo) {
      contenedor.textContent = '';
      var apps = catalogo.apps || [];
      if (!apps.length) {
        var vacio = document.createElement('p');
        vacio.className = 'cargando';
        vacio.textContent = 'Todavía no hay apps publicadas.';
        contenedor.appendChild(vacio);
        return;
      }
      apps.forEach(function (app) { contenedor.appendChild(tarjeta(app)); });
    })
    .catch(function () {
      contenedor.textContent = '';
      var p = document.createElement('p');
      p.className = 'error';
      p.textContent = 'No pudimos cargar la tienda. Revisa tu conexión y recarga la página.';
      contenedor.appendChild(p);
    });
})();
