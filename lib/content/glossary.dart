/// Explicaciones en lenguaje simple de cada concepto de la app. Se muestran
/// en la sección "Aprende" y en los botones ⓘ repartidos por las pantallas.
class GlossaryEntry {
  final String id;
  final String title;

  /// Una frase corta: qué es.
  final String short;

  /// Explicación más larga, con ejemplo.
  final String body;

  const GlossaryEntry({
    required this.id,
    required this.title,
    required this.short,
    required this.body,
  });
}

class GlossarySection {
  final String title;
  final String emoji;
  final List<GlossaryEntry> entries;
  const GlossarySection(this.title, this.emoji, this.entries);
}

class Glossary {
  static const sections = [
    GlossarySection('Lo básico', '🌱', [
      GlossaryEntry(
        id: 'accion',
        title: 'Acción',
        short: 'Un pedacito de una empresa.',
        body: 'Cuando compras una acción de Apple (AAPL) pasas a ser dueño de una parte muy pequeña de '
            'Apple. Si a la empresa le va bien y más gente quiere sus acciones, el precio sube y tu '
            'acción vale más. Si le va mal, el precio baja.\n\n'
            'Cada acción tiene un "símbolo" o "ticker" de pocas letras: AAPL es Apple, TSLA es Tesla, '
            'VOO es un fondo que agrupa a las 500 empresas más grandes de EE.UU.',
      ),
      GlossaryEntry(
        id: 'bolsa',
        title: 'La bolsa de EE.UU. y su horario',
        short: 'Donde se compran y venden acciones. Abre de lunes a viernes.',
        body: 'Las acciones de esta app se transan en la bolsa de Nueva York. Abre de lunes a viernes '
            'de 9:30 a 16:00 hora de Nueva York, que en Chile suele ser entre 10:30 y 17:00 (cambia '
            'una hora según el horario de verano de cada país). No abre fines de semana ni feriados '
            'de EE.UU.\n\n'
            'Si compras con la bolsa cerrada, tu orden queda "pendiente" y se ejecuta cuando abra.',
      ),
      GlossaryEntry(
        id: 'alpaca',
        title: 'Alpaca (tu corredora)',
        short: 'La empresa donde está tu cuenta y tu dinero.',
        body: 'Alpaca es el bróker o corredora: la empresa que guarda tu dinero y tus acciones y '
            'envía tus órdenes a la bolsa. Esta app solo se conecta a tu cuenta de Alpaca usando tus '
            '"API keys" (una especie de usuario y contraseña para apps). La app no guarda tu dinero.',
      ),
      GlossaryEntry(
        id: 'api_keys',
        title: 'Cómo conectar tu cuenta (API keys)',
        short: 'Las claves que permiten a la app ver y operar tu cuenta.',
        body: '1. Entra a alpaca.markets con tu cuenta.\n'
            '2. Elige si quieres la cuenta de práctica ("Paper") o la real ("Live").\n'
            '3. En el panel, busca "API Keys" y presiona "Generate New Key".\n'
            '4. Copia el "Key ID" y el "Secret Key" (el secreto se muestra una sola vez).\n'
            '5. En esta app ve a Más → Ajustes, pega ambas claves y presiona Conectar.\n\n'
            'Las claves quedan cifradas solo en tu teléfono. Nunca las compartas con nadie.',
      ),
      GlossaryEntry(
        id: 'paper',
        title: 'Modo práctica (paper) vs. real',
        short: 'Práctica = dinero simulado. Real = tu dinero de verdad.',
        body: 'En modo práctica (Alpaca lo llama "paper trading") tienes dinero de mentira para '
            'aprender: puedes comprar y vender sin riesgo. Todo funciona igual que en real.\n\n'
            'En modo real las órdenes usan tu dinero de verdad y no se pueden deshacer. '
            'Recomendación: practica unas semanas antes de pasar a real.',
      ),
      GlossaryEntry(
        id: 'dolar',
        title: 'Dólares y pesos chilenos',
        short: 'Tu cuenta está en dólares; la app te lo traduce a pesos.',
        body: 'Las acciones de EE.UU. se compran en dólares (US\$), así que tu cuenta en Alpaca está en '
            'dólares. Para que sea más fácil de entender, la app convierte los montos a pesos '
            'chilenos usando el "dólar observado" del Banco Central (el valor oficial del día).\n\n'
            'Ojo: el valor en pesos también cambia si sube o baja el dólar, aunque tus acciones no '
            'se muevan. Si el dólar sube, tu saldo en pesos sube.',
      ),
    ]),
    GlossarySection('Tu dinero', '💰', [
      GlossaryEntry(
        id: 'saldo_total',
        title: 'Saldo total (valor del portafolio)',
        short: 'Todo lo que tienes: acciones + dinero disponible.',
        body: 'Es la suma de lo que valen hoy tus acciones más el dinero que tienes sin invertir. '
            'Si vendieras todo en este momento, recibirías aproximadamente esto.\n\n'
            'Ejemplo: tienes \$300.000 en acciones y \$50.000 disponibles → saldo total \$350.000.',
      ),
      GlossaryEntry(
        id: 'efectivo',
        title: 'Disponible (efectivo)',
        short: 'Dinero en tu cuenta que no está invertido.',
        body: 'Es la plata que depositaste o que recibiste al vender, y que todavía no usas para '
            'comprar acciones. Este dinero no sube ni baja con la bolsa.',
      ),
      GlossaryEntry(
        id: 'poder_compra',
        title: 'Poder de compra',
        short: 'Cuánto puedes gastar ahora en comprar acciones.',
        body: 'Normalmente es igual a tu dinero disponible. Puede ser distinto si tienes órdenes de '
            'compra pendientes (ese dinero queda "reservado") o si tu cuenta permite préstamos '
            '(margen). La app no te deja comprar más que tu poder de compra.',
      ),
      GlossaryEntry(
        id: 'invertido',
        title: 'Invertido',
        short: 'Cuánto pagaste en total por las acciones que tienes.',
        body: 'Es lo que te costaron tus acciones al comprarlas. Se compara con lo que valen hoy para '
            'saber si vas ganando o perdiendo.\n\n'
            'Ejemplo: compraste 2 acciones a US\$100 → invertiste US\$200.',
      ),
      GlossaryEntry(
        id: 'ganancia_hoy',
        title: 'Ganancia o pérdida de hoy',
        short: 'Cuánto subió o bajó tu saldo desde el cierre de ayer.',
        body: 'Compara tu saldo ahora con el de ayer al cierre de la bolsa. En verde si ganaste, en '
            'rojo si perdiste. Es normal que cambie todos los días: las acciones suben y bajan.\n\n'
            'Un mal día no significa que hayas perdido tu inversión: lo importante es el largo plazo.',
      ),
      GlossaryEntry(
        id: 'ganancia_total',
        title: 'Ganancia total (no realizada)',
        short: 'Lo que ganarías o perderías si vendieras hoy.',
        body: 'Es la diferencia entre lo que valen hoy tus acciones y lo que pagaste por ellas. Se '
            'llama "no realizada" porque todavía no vendes: es ganancia (o pérdida) en el papel, y '
            'puede cambiar.\n\n'
            'Ejemplo: pagaste \$100.000 y hoy valen \$112.000 → ganancia no realizada de \$12.000 (+12%).\n\n'
            'Cuando vendes, pasa a ser "realizada" y ahí cuenta para impuestos.',
      ),
      GlossaryEntry(
        id: 'porcentaje',
        title: 'Porcentaje de variación (%)',
        short: 'Cuánto cambió algo, en proporción.',
        body: '+5% significa que subió 5 pesos por cada 100. −3% que bajó 3 por cada 100.\n\n'
            'Sirve para comparar: ganar \$5.000 sobre \$10.000 (+50%) es mucho mejor que ganar '
            '\$5.000 sobre \$1.000.000 (+0,5%).',
      ),
      GlossaryEntry(
        id: 'costo_promedio',
        title: 'Costo promedio',
        short: 'El precio promedio que pagaste por cada acción.',
        body: 'Si compraste 1 acción a US\$100 y otra a US\$120, tu costo promedio es US\$110. Si hoy '
            'el precio está sobre tu costo promedio, vas ganando con esa acción.',
      ),
      GlossaryEntry(
        id: 'fraccionadas',
        title: 'Acciones fraccionadas (comprar por monto)',
        short: 'Comprar un pedazo de acción, por ejemplo US\$10.',
        body: 'Algunas acciones cuestan cientos de dólares. Con las fraccionadas puedes invertir un '
            'monto (por ejemplo US\$20) y recibes la parte proporcional, como 0,1 acción. En la app, '
            'elige "Monto US\$" al comprar. No todas las acciones lo permiten.',
      ),
      GlossaryEntry(
        id: 'diversificar',
        title: 'Diversificar',
        short: 'No poner todos los huevos en la misma canasta.',
        body: 'Si todo tu dinero está en una sola empresa y a esa empresa le va mal, pierdes mucho. '
            'Repartir entre varias empresas o usar fondos (como VOO, que incluye 500 empresas) reduce '
            'el riesgo. La app te avisa si una acción es más del 40% de tu portafolio.',
      ),
    ]),
    GlossarySection('Comprar y vender', '🛒', [
      GlossaryEntry(
        id: 'orden',
        title: 'Orden',
        short: 'Tu instrucción de compra o venta.',
        body: 'Cuando presionas Comprar o Vender, envías una orden a Alpaca. La orden puede quedar:\n'
            '• Ejecutada: se compró o vendió.\n'
            '• Pendiente: esperando que abra la bolsa o que el precio llegue a tu límite.\n'
            '• Cancelada, expirada o rechazada: no se hizo.\n\n'
            'Las órdenes pendientes las puedes cancelar desde Portafolio.',
      ),
      GlossaryEntry(
        id: 'orden_mercado',
        title: 'Orden a mercado',
        short: 'Comprar o vender ya, al precio del momento.',
        body: 'Es la más simple: se ejecuta de inmediato (con la bolsa abierta) al mejor precio '
            'disponible, que puede diferir unos centavos del que viste en pantalla.',
      ),
      GlossaryEntry(
        id: 'orden_limite',
        title: 'Orden límite',
        short: 'Comprar o vender solo si el precio llega al que tú eliges.',
        body: 'Tú pones el precio. Al comprar: solo se compra a ese precio o más barato. Al vender: '
            'solo se vende a ese precio o más caro. Si el precio nunca llega, la orden queda '
            'esperando hasta que la canceles.\n\n'
            'Ejemplo: Apple está a US\$200 y pones límite de compra en US\$190: solo compras si baja a US\$190.',
      ),
      GlossaryEntry(
        id: 'bid_ask',
        title: 'Precio de compra / venta (bid / ask) y spread',
        short: 'Lo que ofrecen los compradores y lo que piden los vendedores.',
        body: 'El "bid" es lo máximo que alguien ofrece pagar ahora; el "ask" es lo mínimo que alguien '
            'pide para vender. La diferencia se llama "spread". En acciones grandes es de centavos; '
            'en acciones pequeñas puede ser mayor, y conviene usar órdenes límite.',
      ),
    ]),
    GlossarySection('Protegerte de pérdidas', '🛡️', [
      GlossaryEntry(
        id: 'stop_loss',
        title: 'Stop-loss',
        short: 'Venta automática si el precio baja hasta cierto valor.',
        body: 'Es un "freno" para que una pérdida no crezca. Si compraste a US\$100 y pones stop-loss en '
            'US\$90, Alpaca vende sola si el precio baja a US\$90, aunque tengas la app cerrada.\n\n'
            'Ojo: en caídas bruscas la venta puede hacerse un poco más abajo del stop.',
      ),
      GlossaryEntry(
        id: 'take_profit',
        title: 'Take-profit',
        short: 'Venta automática cuando ya ganaste lo que querías.',
        body: 'Si compraste a US\$100 y pones take-profit en US\$120, Alpaca vende sola cuando el '
            'precio llega a US\$120 y aseguras esa ganancia.',
      ),
      GlossaryEntry(
        id: 'trailing',
        title: 'Trailing stop',
        short: 'Un stop-loss que sube solo cuando la acción sube.',
        body: 'Defines un porcentaje, por ejemplo 8%. Si la acción sube, el punto de venta sube con '
            'ella; si baja 8% desde su máximo, se vende.\n\n'
            'Ejemplo: compras a US\$100, sube a US\$150 → el stop queda en US\$138. Si luego cae a '
            'US\$138, vendes, asegurando ganancia.',
      ),
      GlossaryEntry(
        id: 'bracket',
        title: 'Bracket / OCO (stop-loss + take-profit juntos)',
        short: 'Dos ventas automáticas: la primera que ocurra cancela la otra.',
        body: 'Pones un precio de ganancia (take-profit) y uno de pérdida máxima (stop-loss). Si se '
            'cumple uno, el otro se cancela solo. "Bracket" es cuando lo defines al comprar; "OCO" '
            'cuando lo agregas a acciones que ya tienes (botón "Proteger" en la acción).',
      ),
    ]),
    GlossarySection('Alertas y automático', '🤖', [
      GlossaryEntry(
        id: 'alertas',
        title: 'Alertas',
        short: 'Avisos al celular cuando pasa algo con una acción.',
        body: 'Puedes pedir que te avise cuando:\n'
            '• El precio sube o baja a un valor.\n'
            '• La acción se mueve más de cierto % en el día.\n'
            '• Hay volumen inusual (mucha más gente comprando/vendiendo que ayer).\n'
            '• El precio cruza su media móvil (cambio de tendencia).\n\n'
            'Las alertas solo avisan, no compran ni venden.',
      ),
      GlossaryEntry(
        id: 'dca',
        title: 'Compras automáticas (DCA)',
        short: 'Invertir el mismo monto cada semana o mes.',
        body: 'En vez de adivinar el mejor momento, inviertes una cantidad fija periódicamente. Cuando '
            'el precio está bajo compras más acciones, y cuando está alto compras menos; así tu costo '
            'se promedia. Es una estrategia popular para el largo plazo.\n\n'
            'Ejemplo: US\$50 en VOO cada lunes.',
      ),
    ]),
    GlossarySection('Leer el gráfico', '📈', [
      GlossaryEntry(
        id: 'velas',
        title: 'Gráfico de velas',
        short: 'Cada "vela" muestra cómo se movió el precio en un periodo.',
        body: 'Verde: cerró más alto de lo que abrió. Roja: cerró más bajo. El cuerpo va desde el '
            'precio de apertura al de cierre y las "mechas" (líneas finas) marcan el máximo y mínimo.',
      ),
      GlossaryEntry(
        id: 'volumen',
        title: 'Volumen',
        short: 'Cuántas acciones se compraron y vendieron.',
        body: 'Mucho volumen significa mucho interés. Si una acción se mueve fuerte con volumen alto, '
            'el movimiento suele ser más "serio". La app muestra "Vol 2x" cuando hoy va el doble que ayer.\n\n'
            'Nota: la app usa datos gratuitos (IEX), que muestran solo una parte del volumen total.',
      ),
      GlossaryEntry(
        id: 'media_movil',
        title: 'Media móvil (MM20, MM50, MM200)',
        short: 'El precio promedio de los últimos días; muestra la tendencia.',
        body: 'MM50 es el promedio de los cierres de los últimos 50 días. Si el precio está sobre la '
            'media, la tendencia es al alza; si está bajo, a la baja. La de 200 días se usa para la '
            'tendencia de largo plazo.',
      ),
      GlossaryEntry(
        id: 'rsi',
        title: 'RSI',
        short: 'Indica si una acción subió o bajó "demasiado rápido".',
        body: 'Va de 0 a 100. Sobre 70 = "sobrecompra" (subió mucho en poco tiempo, podría corregir). '
            'Bajo 30 = "sobreventa" (cayó mucho, podría rebotar). Es solo una pista, no una garantía.',
      ),
      GlossaryEntry(
        id: 'max52',
        title: 'Máximo y mínimo de 52 semanas',
        short: 'El precio más alto y más bajo del último año.',
        body: 'Sirve para ver en qué parte de su rango está la acción. Si está cerca del máximo, subió '
            'mucho durante el año; cerca del mínimo, cayó bastante.',
      ),
      GlossaryEntry(
        id: 'volatilidad',
        title: 'Volatilidad',
        short: 'Qué tanto sube y baja el precio.',
        body: 'Una volatilidad anual de 20% es moderada (empresas grandes y estables); sobre 50% es '
            'alta (la acción puede tener movimientos muy fuertes, para bien o para mal).',
      ),
    ]),
    GlossarySection('Impuestos en Chile', '🇨🇱', [
      GlossaryEntry(
        id: 'impuestos',
        title: 'Impuestos por tus inversiones',
        short: 'Las ganancias al vender y los dividendos se declaran en la Operación Renta.',
        body: 'En Chile, las ganancias que obtienes al vender acciones extranjeras y los dividendos que '
            'recibes se declaran en el Formulario 22 (abril). La app calcula un resumen referencial en '
            'Más → Reporte para el SII, convertido a pesos con el dólar de cada fecha.\n\n'
            'Es una ayuda, no asesoría tributaria: revísalo con un contador.',
      ),
      GlossaryEntry(
        id: 'dividendo',
        title: 'Dividendo y retención de EE.UU.',
        short: 'Parte de las ganancias que la empresa reparte a sus accionistas.',
        body: 'Algunas empresas te pagan dinero cada cierto tiempo solo por tener sus acciones. EE.UU. '
            'retiene un impuesto (normalmente 30% para chilenos) antes de depositártelo. Esa retención '
            'podría servirte como crédito en tu declaración en Chile.',
      ),
      GlossaryEntry(
        id: 'fifo',
        title: 'FIFO (cálculo de ganancia al vender)',
        short: 'Lo primero que compraste es lo primero que vendes.',
        body: 'Si compraste acciones en distintas fechas y vendes una parte, el cálculo asume que '
            'vendiste las más antiguas primero. Así se determina el costo y la ganancia de cada venta.',
      ),
    ]),
  ];

  static final Map<String, GlossaryEntry> _byId = {
    for (final s in sections)
      for (final e in s.entries) e.id: e,
  };

  static GlossaryEntry? byId(String id) => _byId[id];

  static List<GlossaryEntry> search(String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return [];
    return _byId.values
        .where((e) =>
            e.title.toLowerCase().contains(t) ||
            e.short.toLowerCase().contains(t) ||
            e.body.toLowerCase().contains(t))
        .toList();
  }
}
