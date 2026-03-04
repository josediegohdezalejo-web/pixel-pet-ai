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
  String lastResponse = "¡Hola! Soy Pixel.";
  bool showChat = false;

  // --- CONFIGURACIÓN ---
  final String groqApiKey = "TU_API_KEY_DE_GROQ"; // Reemplaza con tu clave real
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

  // --- LÓGICA DE TIEMPO ---
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
    isSleeping = (hour >= 22 || hour < 6);
  }

  // --- IA GROQ ---
  Future<void> enviarAGroq(String mensaje) async {
    if (isSleeping) {
      setState(() => lastResponse = "Zzz... Zzz... (Pixel está roncando)");
      return;
    }

    setState(() => lastResponse = "Pixel está pensando...");

    String systemPrompt = "Eres Pixel, una mascota virtual amigable.";
    if (hunger < 20) {
      systemPrompt = "Eres Pixel. Estás hambriento y de mal humor, sé cortante y exige comida.";
    } else if (happiness < 20) {
      systemPrompt = "Eres Pixel. Estás triste y sarcástico.";
    }

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $groqApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "mixtral-8x7b-32768",
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": mensaje}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => lastResponse = data['choices'][0]['message']['content']);
      } else {
        setState(() => lastResponse = "¡Grrr! No puedo hablar ahora.");
      }
    } catch (e) {
      setState(() => lastResponse = "Mi conexión cerebral falló.");
    }
  }

  // --- MINIJUEGO DE EJERCICIO ---
  void _handleMovement(double x, double y) {
    final currentPos = Offset(x, y);
    if (_lastPosition != null) {
      double distance = (currentPos - _lastPosition!).distance;
      _totalDistanceMoved += distance;

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

  // --- CONTROL DE LA BURBUJA ---
  void _startBubble() async {
    final hasPermission = await DashBubble.instance.hasOverlayPermission();
    if (!hasPermission) {
      await DashBubble.instance.requestOverlayPermission();
      return;
    }

    // Usamos "ic_launcher" como fallback seguro para evitar cierres si no hay PNGs
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
      appBar: AppBar(title: const Text("Pixel Pet Controller")),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pets, size: 100, color: Colors.blue),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startBubble,
                  child: const Text("Iniciar Mascota Flotante"),
                ),
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Instrucciones:\n1. Activa la burbuja.\n2. Arrástrala para ganar estrellas.\n3. Tócala para abrir el chat flotante.",
                    textAlign: TextAlign.center,
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

  Widget _buildChatOverlay() {
    return Positioned(
      bottom: 160,
      right: 20,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isSleeping ? "Pixel (Zzz...)" : "Pixel", style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => showChat = false)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(lastResponse, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem(Icons.restaurant, hunger, "Hambre"),
                  _statItem(Icons.bolt, energy, "Energía"),
                  Column(children: [const Icon(Icons.star, color: Colors.amber), Text("$stars")]),
                ],
              ),
              const Divider(),
              TextField(
                controller: _chatController,
                decoration: InputDecoration(
                  hintText: "Dile algo...",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
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
              const SizedBox(height: 10),
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
                    child: const Text("Jugar"),
                  ),
                  ElevatedButton(
                    onPressed: (isSleeping || stars < 50) ? null : () {
                      setState(() {
                        stars -= 50;
                        hunger = 100;
                      });
                      _saveState();
                    },
                    child: const Text("Comer"),
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
        Icon(icon, color: val < 20 ? Colors.red : Colors.blue, size: 20),
        Text("${val.toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 8)),
      ],
    );
  }
}
