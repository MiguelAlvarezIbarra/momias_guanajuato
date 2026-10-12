import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logica/motor_juego.dart';
import '../logica/personaje.dart';
import '../logica/momia.dart';
import '../logica/calaverita.dart';
import '../logica/rectangulo.dart';
import '../logica/estado_juego.dart';

class JuegoScreen extends StatefulWidget {
  const JuegoScreen({super.key});

  @override
  State<JuegoScreen> createState() => _JuegoScreenState();
}

class _JuegoScreenState extends State<JuegoScreen> {
  static const double _alturaNivel = 340;

  late MotorJuego _motor;
  Timer? _bucle;
  double _direccion = 0;
  final FocusNode _foco = FocusNode();

  @override
  void initState() {
    super.initState();
    _iniciarNivel();
    _iniciarBucle();
  }

  void _iniciarNivel() {
    _direccion = 0;
    _motor = MotorJuego(
      personaje: Personaje(x: 20, y: 100),
      plataformas: const [
        Rectangulo(x: 0, y: 300, ancho: 2000, alto: 40),
        Rectangulo(x: 300, y: 220, ancho: 120, alto: 20),
        Rectangulo(x: 550, y: 160, ancho: 120, alto: 20),
      ],
      momias: [
        Momia(x: 320, y: 268, limiteIzquierdo: 300, limiteDerecho: 420),
        Momia(x: 900, y: 268, limiteIzquierdo: 850, limiteDerecho: 1100),
      ],
      // Sin const: Calaverita es mutable (recolectada) y no tiene constructor const.
      calaveritas: [
        Calaverita(x: 360, y: 180),
        Calaverita(x: 600, y: 120),
        Calaverita(x: 1200, y: 260),
      ],
      posicionMeta: 1900,
      anchoNivel: 2000,
    );
  }

  void _iniciarBucle() {
    _bucle?.cancel();
    _bucle = Timer.periodic(const Duration(milliseconds: 16), (_) {
      setState(() => _motor.mover(_direccion * 4));
      if (_motor.estado != EstadoJuego.jugando) {
        _bucle?.cancel();
        _mostrarResultado();
      }
    });
  }

  @override
  void dispose() {
    _bucle?.cancel();
    _foco.dispose();
    super.dispose();
  }

  void _mostrarResultado() {
    final gano = _motor.estado == EstadoJuego.ganado;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'resultado',
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
        child: FadeTransition(
          opacity: anim1,
          child: AlertDialog(
            title: Text(gano ? '¡Llegaste al Callejón del Beso!' : 'Las momias te atraparon'),
            content: Text('Puntaje: ${_motor.puntaje}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(_iniciarNivel);
                  _iniciarBucle();
                  _foco.requestFocus();
                },
                child: const Text('Jugar de nuevo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Teclado (util al probar en Chrome / Windows): flechas o A/D para mover, espacio/W/↑ para saltar.
  KeyEventResult _alTeclear(FocusNode node, KeyEvent event) {
    final k = HardwareKeyboard.instance;
    final izq = k.isLogicalKeyPressed(LogicalKeyboardKey.arrowLeft) ||
        k.isLogicalKeyPressed(LogicalKeyboardKey.keyA);
    final der = k.isLogicalKeyPressed(LogicalKeyboardKey.arrowRight) ||
        k.isLogicalKeyPressed(LogicalKeyboardKey.keyD);
    _direccion = ((der ? 1 : 0) - (izq ? 1 : 0)).toDouble();

    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.arrowUp ||
            event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.keyW)) {
      _motor.saltar();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _foco,
      autofocus: true,
      onKeyEvent: _alTeclear,
      child: Scaffold(
        appBar: AppBar(title: const Text('Momias de Guanajuato')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Vidas: ${_motor.vidas}'),
                  Text('Puntaje: ${_motor.puntaje}'),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final anchoVentana = c.maxWidth;
                  final maxCamara =
                      (_motor.anchoNivel - anchoVentana).clamp(0.0, double.infinity).toDouble();
                  final camaraX =
                      (_motor.personaje.x - anchoVentana / 2).clamp(0.0, maxCamara).toDouble();
                  // Ancla el nivel a la parte de abajo de la pantalla.
                  final offsetY = (c.maxHeight - _alturaNivel).clamp(0.0, double.infinity).toDouble();

                  return ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        ..._motor.plataformas.map((pl) => Positioned(
                              left: pl.x - camaraX,
                              top: pl.y + offsetY,
                              child: Container(
                                width: pl.ancho,
                                height: pl.alto,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE91E63),
                                  border: Border.all(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )),
                        ..._motor.calaveritas.where((cal) => !cal.recolectada).map((cal) => Positioned(
                              left: cal.x - camaraX,
                              top: cal.y + offsetY,
                              child: const Text('\u{1F480}', style: TextStyle(fontSize: 20)),
                            )),
                        ..._motor.momias.where((m) => !m.derrotada).map((m) => Positioned(
                              left: m.x - camaraX,
                              top: m.y + offsetY,
                              child: Container(
                                width: m.ancho,
                                height: m.alto,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD7CCC8),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.black38),
                                ),
                                alignment: Alignment.center,
                                child: const Text('\u{1F9DF}', style: TextStyle(fontSize: 18)),
                              ),
                            )),
                        Positioned(
                          left: _motor.personaje.x - camaraX,
                          top: _motor.personaje.y + offsetY,
                          child: Container(
                            width: _motor.personaje.ancho,
                            height: _motor.personaje.alto,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Text('\u{1F920}', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    _boton(Icons.arrow_back, () => _direccion = -1, () => _direccion = 0),
                    const SizedBox(width: 12),
                    _boton(Icons.arrow_forward, () => _direccion = 1, () => _direccion = 0),
                  ]),
                  _boton(Icons.arrow_upward, () => _motor.saltar(), () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boton(IconData icono, VoidCallback alPresionar, VoidCallback alSoltar) {
    return GestureDetector(
      onTapDown: (_) => alPresionar(),
      onTapUp: (_) => alSoltar(),
      onTapCancel: alSoltar,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.indigo,
        child: Icon(icono, color: Colors.white),
      ),
    );
  }
}
