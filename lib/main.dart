import 'dart:io'; // Nadal potrzebny do Directory
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';            // Nadal potrzebny
// Import flutter_map_tile_caching pozostaje bez zmian
import 'home_screen.dart';
// Nazwa katalogu dla cache (może być inna niż nazwa store wewnątrz pakietu)
const String _mapCacheDirectoryName = 'mapTileCache'; // Nazwa naszego podkatalogu

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Przygotowanie Katalogu dla Cache Mapy ---
  try {
    // Pobierz katalog, gdzie aplikacja może przechowywać dane
    final Directory appDocumentsDirectory = await getApplicationDocumentsDirectory();
    // Stwórz pełną ścieżkę do naszego podkatalogu cache
    final Directory mapCacheDirectory = Directory('${appDocumentsDirectory.path}/$_mapCacheDirectoryName');

    // Sprawdź, czy katalog istnieje, jeśli nie - utwórz go
    if (!await mapCacheDirectory.exists()) {
      await mapCacheDirectory.create(recursive: true);
      debugPrint('Map tile cache directory created at: ${mapCacheDirectory.path}');
    } else {
      debugPrint('Map tile cache directory already exists at: ${mapCacheDirectory.path}');
    }

    // UWAGA: W flutter_map_tile_caching v9+ inicjalizacja magazynu
    // odbywa się "niejawnie" przy pierwszym użyciu TileProvidera
    // lub innej operacji na Store. Wystarczy zapewnić istnienie katalogu.
    // Opcjonalne odzyskiwanie może być bardziej złożone i wymagać
    // dostępu do konkretnego obiektu Store, jeśli go utworzymy jawnie.
    // Na razie pominiemy `recover`, bo domyślny provider powinien sobie poradzić.

  } catch (e) {
    debugPrint('ERROR preparing map tile cache directory: $e');
  }
  // ------------------------------------------

  runApp(const SurpadLiteApp());
}

// Reszta kodu (SurpadLiteApp, MaterialApp, motywy) pozostaje bez zmian
class SurpadLiteApp extends StatelessWidget {
  const SurpadLiteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surpad Lite',

      // Jasny motyw
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Ciemny motyw
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Użyj motywu systemowego (jasny/ciemny)
      themeMode: ThemeMode.system,

      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}