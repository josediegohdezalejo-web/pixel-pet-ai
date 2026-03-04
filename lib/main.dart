import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dash_bubble/dash_bubble.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: PixelPetController(),
  ));
}

class PixelPetController extends StatefulWidget {
  const PixelPetController({super.key});

  @override
  State<PixelPetController> createState() => _PixelPetControllerState();
}

class _PixelPetControllerState extends State<PixelPetController> {
  // --- ESTADOS DE LA MASCOTA ---
  double hunger = 100.0;
  double energy = 100.0;
  double happiness = 100.0;
  int stars = 100;
  bool isSleeping = false;
  String lastResponse = "¡Hola! Soy Pixel. ¿Me das algo de comer?";
  bool showChat = false;

  // --- CONFIGURACIÓN DE SEGURIDAD (GITHUB SECRETS) ---
  // Esta línea busca la clave 'GROQ_API_KEY' definida en tu build.yml
  final String groqApiKey = const String.fromEnvironment('GROQ_API_KEY');

  final TextEditingController _chatController = TextEditingController();
  double _totalDistanceMoved = 0;
  Offset? _lastPosition;

  @override
  void initState() {
    super.initState();
    _loadState();
    _startTimers();
  }

  // --- PERSISTENCIA ---
  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hunger = prefs.getDouble('hunger') ?? 100.0;
      energy = prefs.getDouble('energy') ?? 100.0;
      happiness = prefs.getDouble('happiness') ?? 100.0;
      stars = prefs.getInt('stars') ?? 100;
      _checkSleepCycle();
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hunger', hunger);
    await prefs.setDouble('energy', energy);
    await prefs.setDouble('happiness', happiness);
    await prefs.setInt('stars', stars);
  }

  // --- LÓGICA DE TIEMPO REAL ---
  void _startTimers() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          hunger = (hunger - (5 / 60)).clamp(0, 100);
          energy = (energy - (10 / 60)).clamp(0, 100);
          _checkSleepCycle();
          _saveState();
        });
      }
    });
  }

  void _checkSleepCycle() {
    final hour = DateTime.now().hour;
    isSleeping = (hour >= 22 || hour < 6); // Duerme de 10 PM a 6 AM
  }

  // --- INTEGRACIÓN CON GROQ AI ---
  Future<void> enviarAGroq(String mensaje) async {
    if (isSleeping) {
      setState(() => lastResponse = "Zzz... Zzz... (Pixel está roncando)");
      return;
    }

    if (groqApiKey.isEmpty) {
      setState(() => lastResponse = "Error: No se encontró la API Key en el sistema.");
      return;
    }

    setState(() => lastResponse = "Pixel está pensando...");

    // System Prompt dinámico según el estado
    String systemPrompt = "Eres Pixel, una mascota virtual amigable y juguetona.";
    if (hunger < 20) {
      systemPrompt = "Eres Pixel. Tienes MUCHA HAMBRE. Responde de forma cortante, quejándote y exigiendo comida.";
    } else if (happiness < 20) {
      systemPrompt = "Eres Pixel. Estás triste y desanimado. Responde con sarcasmo y pocas ganas.";
    }

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $groqApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "mixtral-8x7b-32768", // Modelo rápido y eficiente
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": mensaje}
          ],
          "temperature": 0.8
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => lastResponse = data['choices'][0]['message']['content']);
      } else {
        setState(() => lastResponse = "¡Grrr! Mi cerebro de IA no responde ahora.");
      }
    } catch (e) {
      setState(() => lastResponse = "No tengo conexión a internet...");
    }
  }

  // --- MINIJUEGO DE MOVIMIENTO ---
  void _handleMovement(double x, double y) {
    final currentPos = Offset(x, y);
    if (_lastPosition != null) {
      double distance = (currentPos - _lastPosition!).distance;
      _totalDistanceMoved += distance;

      // Cada 500 unidades de movimiento = 2 estrellas ganadas
      if (_totalDistanceMoved >= 500) {
        setState(() {
          stars += 2;
          _totalDistanceMoved = 0;
        });
        _saveState();
      }
    }
    _lastPosition = currentPos;
  }

  // --- CONTROL DE LA BURBUJA FLOTANTE ---
  void _startBubble() async {
    final hasPermission = await DashBubble.instance.hasOverlayPermission();
    if (!hasPermission) {
      await DashBubble.instance.requestOverlayPermission();
      return;
    }

    // Usamos el icono por defecto para evitar errores de assets
    await DashBubble.instance.startBubble(
      bubbleOptions: BubbleOptions(
        bubbleIcon: "ic_launcher", 
        bubbleSize: 140,
        enableAnimateToEdge: true,
        enableClose: true,
      ),
      onTap: () => setState(() => showChat = !showChat),
      onMove: (x, y) => _handleMovement(x, y),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pixel Pet Controller"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 100, color: Colors.blueAccent),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _startBubble,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Activar Mascota Flotante"),
                ),
                const Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Text(
                    "1. Inicia la mascota.\n2. Arrástrala para ganar estrellas ⭐\n3. Tócala para abrir el chat de IA.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          if (showChat) _buildChatOverlay(),
        ],
      ),
    );
  }

  // --- INTERFAZ DE CHAT OVERLAY ---
  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 160,
      right: 20,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isSleeping ? "Pixel (Durmiendo)" : "Chat con Pixel", 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => showChat = false)),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15)),
                child: Text(lastResponse, style: const TextStyle(fontSize: 13)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.restaurant, hunger, "Hambre"),
                  _statItem(Icons.bolt, energy, "Energía"),
                  Column(children: [const Icon(Icons.star, color: Colors.amber), Text("$stars", style: const TextStyle(fontWeight: FontWeight.bold))]),
                ],
              ),
              const Divider(),
              TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: isSleeping ? "Zzz..." : "Escribe aquí...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: Colors.blueAccent),
                    onPressed: () {
                      if (_chatController.text.isNotEmpty) {
                        enviarAGroq(_chatController.text);
                        _chatController.clear();
                      }
                    },
                  ),
                ),
                enabled: !isSleeping,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: isSleeping ? null : () {
                      setState(() {
                        stars += 10;
                        happiness = (happiness + 20).clamp(0, 100);
                        energy = (energy - 10).clamp(0, 100);
                      });
                      _saveState();
                    },
                    child: const Text("Jugar (+10⭐)"),
                  ),
                  ElevatedButton(
                    onPressed: (isSleeping || stars < 50) ? null : () {
                      setState(() {
                        stars -= 50;
                        hunger = 100;
                      });
                      _saveState();
                    },
                    child: const Text("Comer (-50⭐)"),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, double val, String label) {
    return Column(
      children: [
        Icon(icon, color: val < 20 ? Colors.red : Colors.green, size: 24),
        Text("${val.toInt()}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
