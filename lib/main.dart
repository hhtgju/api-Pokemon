import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PokemonGrid(),
    );
  }
}

// ==================== MODEL ====================
class Pokemon {
  final String name;
  final String url;

  Pokemon({required this.name, required this.url});

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    return Pokemon(
      name: json['name'],
      url: json['url'],
    );
  }

  int get id {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    return int.parse(segments[segments.length - 2]);
  }

  String get imageUrl {
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
  }
}

// ==================== SERVICE ====================
class PokeApiService {
  static Future<List<Pokemon>> fetchPokemonList() async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=151')); // ambil gen 1 biar ringan
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      return results.map((json) => Pokemon.fromJson(json)).toList();
    } else {
      throw Exception('Gagal mengambil data Pokémon');
    }
  }

  static Future<Map<String, dynamic>> fetchPokemonDetail(String name) async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$name'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Gagal mengambil detail Pokémon');
    }
  }

  static Future<List<String>> fetchEvolutionChain(String name) async {
    // Ambil species -> evolution chain
    final speciesResponse = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon-species/$name'));
    if (speciesResponse.statusCode != 200) return [];

    final speciesData = json.decode(speciesResponse.body);
    final evoUrl = speciesData['evolution_chain']['url'];

    final evoResponse = await http.get(Uri.parse(evoUrl));
    if (evoResponse.statusCode != 200) return [];

    final evoData = json.decode(evoResponse.body);

    List<String> evolution = [];
    var chain = evoData['chain'];

    // ambil chain evolusi
    while (chain != null) {
      evolution.add(chain['species']['name']);
      if (chain['evolves_to'] != null && chain['evolves_to'].isNotEmpty) {
        chain = chain['evolves_to'][0];
      } else {
        chain = null;
      }
    }

    return evolution;
  }
}

// ==================== UI ====================
class PokemonGrid extends StatefulWidget {
  const PokemonGrid({super.key});

  @override
  State<PokemonGrid> createState() => _PokemonGridState();
}

class _PokemonGridState extends State<PokemonGrid> {
  late Future<List<Pokemon>> futurePokemon;
  List<Pokemon> allPokemon = [];
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    futurePokemon = PokeApiService.fetchPokemonList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[900],
      appBar: AppBar(
        title: const Text('Pokédex'),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          // 🔎 Search Bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari Pokémon...',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Pokemon>>(
              future: futurePokemon,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Tidak ada data.'));
                }

                allPokemon = snapshot.data!;
                final filteredPokemon = allPokemon.where((p) => p.name.contains(searchQuery)).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 3 / 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: filteredPokemon.length,
                  itemBuilder: (context, index) {
                    final pokemon = filteredPokemon[index];
                    return GestureDetector(
                      onTap: () => _showPokemonDetail(pokemon),
                      child: Card(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Image.network(
                                pokemon.imageUrl,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error, color: Colors.red);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pokemon.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== DETAIL ====================
  void _showPokemonDetail(Pokemon pokemon) async {
    final detail = await PokeApiService.fetchPokemonDetail(pokemon.name);
    final evolution = await PokeApiService.fetchEvolutionChain(pokemon.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.blueGrey[800],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final types = (detail['types'] as List).map((t) => t['type']['name']).join(', ');
        final stats = detail['stats'] as List;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.network(pokemon.imageUrl, height: 150),
                const SizedBox(height: 10),
                Text(
                  pokemon.name.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text("Tipe: $types", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 20),

                // Stats
                const Text("Statistik", style: TextStyle(color: Colors.yellow, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Column(
                  children: stats.map((s) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['stat']['name'], style: const TextStyle(color: Colors.white)),
                        Text(s['base_stat'].toString(), style: const TextStyle(color: Colors.white)),
                      ],
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Evolution
                const Text("Evolusi", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                evolution.isEmpty
                    ? const Text("Tidak ada evolusi", style: TextStyle(color: Colors.white70))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: evolution.map((evo) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              children: [
                                Image.network(
                                  'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${allPokemon.firstWhere((p) => p.name == evo, orElse: () => Pokemon(name: evo, url: "https://pokeapi.co/api/v2/pokemon/0/")).id}.png',
                                  height: 60,
                                  errorBuilder: (c, e, s) => const Icon(Icons.error, color: Colors.red),
                                ),
                                Text(evo, style: const TextStyle(color: Colors.white)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
