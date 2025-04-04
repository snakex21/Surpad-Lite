import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io'; // Potrzebny do File
// import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart'; // jeśli używasz cache
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart'; // kompas
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math.dart' show radians;
// flutter_map + latlong2
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

// fl_chart do wykresu SNR
import 'package:fl_chart/fl_chart.dart';

//
// Klasa do przechowywania historii SNR (czas + wartość)
//
class SnrDataPoint {
  final DateTime timestamp;
  final double snr;
  SnrDataPoint(this.timestamp, this.snr);
}

//
// Klasa NmeaSatellite (dla GSV)
//
class NmeaSatellite {
  final int svid;
  final String system;
  final double? elevation; // 0..90
  final double? azimuth;   // 0..359
  final double? snr;       // dB

  NmeaSatellite({
    required this.svid,
    required this.system,
    this.elevation,
    this.azimuth,
    this.snr,
  });

  String get key => '${system}_$svid';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NmeaSatellite &&
       other.key == key &&
       other.elevation == elevation &&
       other.azimuth == azimuth &&
       other.snr == snr);

  @override
  int get hashCode => Object.hash(key, elevation, azimuth, snr);
}

//
// Główny Ekran
//
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin { 
  // 1. GNSS i Lokalizacja
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  String? _error;

  static const _nmeaEventChannel = EventChannel('com.example.surpad_lite/nmea');
  StreamSubscription? _nmeaSubscription;
  final Map<String, NmeaSatellite> _visibleSatellites = {};
  final Map<String, DateTime> _lastSeenSatellite = {};
  Timer? _satelliteCleanupTimer;
  final Duration _satelliteTimeout = const Duration(seconds: 15);
  String? _gnssError;

  // Lista wszystkich systemów GNSS, filtry
  final List<String> _allPossibleSystems = [
    'GPS', 'GLONASS', 'Galileo', 'BeiDou', 'QZSS', 'NavIC'
  ];
  late Set<String> _selectedSystemsForPlot;

  // Status uprawnień
  String _permissionStatus = 'Sprawdzanie uprawnień...';
  bool _isLoading = true;

  // 2. Mapa + Śledzenie
  final MapController _mapController = MapController();
  final List<LatLng> _trackPoints = [];
  bool _isTracking = false;
  LatLng? _lastTrackPointAdded;
  final double _minTrackingDistance = 5.0;
  double _trackedDistance = 0.0;
  List<double?> _trackAltitudes = []; // Lista wysokości (może zawierać null)


    // --- NOWE ZMIENNE DLA STATYSTYK ---
  DateTime? _trackingStartTime; // Czas rozpoczęcia bieżącego śledzenia
  double _maxSpeed = 0.0;      // Maksymalna zarejestrowana prędkość (w m/s)
  // ----------------------------------

  // 3. Kompas i Heading
  StreamSubscription<CompassEvent>? _compassSubscription;
  double? _compassHeading;   // Odczyt z kompasu
  double _activeHeading = 0; // Faktycznie używany heading (GPS/kompas)
  bool _mapIsRotating = false;

  // 4. GGA i GSA
  int? _fixQualityGga;
  Set<int> _activeSatelliteSvidsGsa = {};
  double? _pdopGsa;
  double? _hdopGsa;
  double? _vdopGsa;

  // 5. Historia SNR + Wykres
  final Map<String, List<SnrDataPoint>> _snrHistory = {};
  final int _maxHistoryLength = 60;
  final int _topNForChart = 8;
  Timer? _chartUpdateTimer;

  List<Map<String, dynamic>> _savedTracks = []; // Lista zapisanych tras

  // --- NOWE ZMIENNE DLA USTAWIEŃ ---
  double _minTrackDistanceSetting = 5.0; // Domyślna wartość
  Color _trackColor = Colors.redAccent;   // Domyślny kolor śladu
  double _trackStrokeWidth = 4.0;       // Domyślna grubość śladu
  // ---------------------------------

    // --- ZMIENNA dla AnimationController (wskaźnik śledzenia) ---
  late AnimationController _trackingIndicatorController;
  // ----------------------------------------------------------


  @override
  void initState() {
    super.initState();
         _trackingIndicatorController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true); // Powtarzaj animację (mruganie)
    _selectedSystemsForPlot = Set.from(_allPossibleSystems);
    _clearGgaGsaData();
    _loadSavedTracks(); // Załaduj zapisane trasy przy starcie
    // Timer do odświeżania wykresu co 2 s
    _chartUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
    _loadSettings();
    _loadSavedTracks(); // Załaduj zapisane trasy
    // Uruchom uprawnienia + strumienie
    _requestPermissionAndStartStreams();
    // Uruchom kompas
    _startCompassStream();
    
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _nmeaSubscription?.cancel();
    _compassSubscription?.cancel();
    _satelliteCleanupTimer?.cancel();
    _chartUpdateTimer?.cancel();

    _mapController.dispose();
    _trackingIndicatorController.dispose(); // <<--- Zwolnij kontroler animacji
    super.dispose();
  }

  // Czyszczenie GGA/GSA
  void _clearGgaGsaData() {
    _fixQualityGga = null;
    _activeSatelliteSvidsGsa.clear();
    _pdopGsa = null;
    _hdopGsa = null;
    _vdopGsa = null;
  }

  // -----------------------------
  // Kompas
  // -----------------------------
  void _startCompassStream() {
    if (_compassSubscription != null) return;
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      if (event.heading != null) {
        setState(() {
          _compassHeading = event.heading;
          _updateActiveHeading();
        });
      }
    }, onError: (error) {
      if (!mounted) return;
      debugPrint("Błąd kompasu: $error");
      setState(() {
        _compassHeading = null;
        _updateActiveHeading();
      });
    });
  }

  /// Aktualizuje _activeHeading, wybierając między heading z GPS a kompasu
  void _updateActiveHeading() {
    double? newActive;
    final pos = _currentPosition;

    // 1) GPS heading, jeśli prędkość > 0.8 m/s i headingAccuracy OK
    if (pos != null &&
        pos.speed > 0.8 &&
        pos.headingAccuracy > 0 &&
        pos.headingAccuracy < 90) {
      newActive = pos.heading;
    }
    // 2) Kompas
    else if (_compassHeading != null) {
      newActive = _compassHeading;
    }
    // 3) Bez zmian
    else {
      newActive = _activeHeading;
    }

    if (newActive != null && newActive != _activeHeading) {
      setState(() {
        _activeHeading = newActive!;
      });
    }
  }

  // -----------------------------
  // Uprawnienia + Strumienie
  // -----------------------------
  Future<void> _requestPermissionAndStartStreams() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _gnssError = null;
      _permissionStatus = 'Proszenie o uprawnienia lokalizacji...';
      _visibleSatellites.clear();
      _lastSeenSatellite.clear();
    });

    var status = await Permission.location.request();
    if (status.isGranted) {
      setState(() => _permissionStatus = 'Uprawnienia przyznane.');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Usługi lokalizacji są wyłączone.';
          _permissionStatus = 'Usługi lokalizacji wyłączone.';
          _isLoading = false;
        });
        _stopNmeaStream();
        return;
      }
      setState(() {
        _permissionStatus = 'Usługi lokalizacji włączone.';
        _startLocationStream();
        _startNmeaStream();
        _isLoading = false;
      });
    }
    else if (status.isDenied) {
      setState(() {
        _permissionStatus = 'Odmówiono uprawnień lokalizacji.';
        _error = 'Aplikacja wymaga uprawnień lokalizacji.';
        _isLoading = false;
      });
      _stopNmeaStream();
    }
    else if (status.isPermanentlyDenied) {
      setState(() {
        _permissionStatus = 'Trwale odmówiono uprawnień.';
        _error = 'Uprawnienia lokalizacji zablokowane.';
        _isLoading = false;
      });
      _stopNmeaStream();
    }
  }

  void _startLocationStream() {
    const locSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locSettings)
        .handleError((error) {
          if (!mounted) return;
          debugPrint("Błąd lokalizacji: $error");
          setState(() => _error = "Błąd lokalizacji: $error");
        })
        .listen((pos) {
        if (!mounted) return;
        final latLng = LatLng(pos.latitude, pos.longitude);
        final currentAltitude = pos.altitude; // Pobierz wysokość raz
        bool shouldAddPoint = false;
        double distanceIncrement = 0.0; // Przyrost dystansu dla tego kroku

        debugPrint('[GPS LISTEN] Otrzymano Alt: ${currentAltitude?.toStringAsFixed(1) ?? "null"}'); // Loguj KAŻDĄ otrzymaną wysokość

          if (_isTracking && (pos.latitude != 0 || pos.longitude != 0)) {
            if (_lastTrackPointAdded == null) {
              // Pierwszy punkt śledzenia - ZAWSZE dodajemy, jeśli _isTracking=true i mamy pozycję
              shouldAddPoint = true;
              distanceIncrement = 0.0; // Dystans dla pierwszego punktu to 0
              debugPrint('[GPS LISTEN] Pierwszy punkt śledzenia.');
            } else {
              // Kolejne punkty - sprawdzamy dystans
              const Distance dist = Distance();
              final meters = dist(_lastTrackPointAdded!, latLng);
              if (meters >= _minTrackDistanceSetting) {
                shouldAddPoint = true;
                distanceIncrement = meters;
                debugPrint('[GPS LISTEN] Warunek odległości spełniony (>=${_minTrackDistanceSetting}m).');
              } else {
                 debugPrint('[GPS LISTEN] Warunek odległości NIESPEŁNIONY (${meters.toStringAsFixed(1)}m < ${_minTrackDistanceSetting}m).');
              }
            }
          } else if (!_isTracking) {
              debugPrint('[GPS LISTEN] Śledzenie wyłączone.');
          }



 // Wykonaj setState niezależnie od tego, czy dodajemy punkt, aby zaktualizować _currentPosition
          setState(() {
            _currentPosition = pos; // Zawsze aktualizuj bieżącą pozycję
            _error = null;
            _updateActiveHeading();
        // --- AKTUALIZACJA MAX PRĘDKOŚCI (jeśli śledzimy) ---
        if (_isTracking && pos.speed > _maxSpeed) {
           _maxSpeed = pos.speed;
        }
             // --- POPRAWIONA LOGIKA DODAWANIA ---
            if (shouldAddPoint) {
              // Dodaj nowy punkt i wysokość DO OBU LIST
              _trackPoints.add(latLng);
              _trackAltitudes.add(currentAltitude); // Dodaj wysokość (nawet jeśli jest null)

              // Zaktualizuj ostatni dodany punkt i dystans
              _lastTrackPointAdded = latLng;
              _trackedDistance += distanceIncrement;

              // Loguj DOKŁADNIE po dodaniu
              debugPrint('[GPS LISTEN] Dodano Pkt/Wys: ${_trackPoints.length}/${_trackAltitudes.length} (Alt: ${currentAltitude?.toStringAsFixed(1) ?? "null"})');
            }
            // ------------------------------------

            // Przesuwanie mapy
            if (pos.latitude != 0 && pos.longitude != 0 && mounted) {
              try {
                if (_mapIsRotating) _mapController.moveAndRotate(latLng, _mapController.zoom, _activeHeading);
                else _mapController.move(latLng, _mapController.zoom);
              } catch (e) { debugPrint("Błąd przesuwania mapy (ignorowany): $e"); }
            }
          });
        });
    _getInitialLocation();
  }

      // --- NOWA ZMIENNA: Wyświetlana zapisana trasa ---
  List<LatLng>? _displayedSavedTrack; // Punkty trasy wybranej do wyświetlenia
  String? _displayedSavedTrackTimestamp; // Timestamp trasy wybranej do wyświetlenia (dla identyfikacji)



  Future<void> _getInitialLocation() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      if (!mounted) return;
      setState(() => _currentPosition = p);

      final latLng = LatLng(p.latitude, p.longitude);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        try {
          if (_mapIsRotating) {
            _mapController.moveAndRotate(latLng, 15.0, _activeHeading);
          } else {
            _mapController.move(latLng, 15.0);
          }
        } catch (e) {
          debugPrint("Błąd centrowania mapy: $e");
        }
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("Błąd initial location: $e");
      if (_currentPosition == null) {
        setState(() => _error = "Nie można pobrać początkowej lokalizacji: $e");
      }
    }
  }

// W klasie _HomeScreenState
void _showSettingsBottomSheet() {
   showModalBottomSheet(
      context: context,
      // isScrollControlled: true, // Jeśli zawartość jest długa
      builder: (context) {
         // Użyj StatefulWidget, aby zarządzać stanem wewnątrz bottom sheet
         return SettingsBottomSheet(
            initialMinDistance: _minTrackDistanceSetting,
            initialColor: _trackColor,
            initialStrokeWidth: _trackStrokeWidth,
            onSettingsChanged: (newDistance, newColor, newWidth) {
               setState(() {
                  _minTrackDistanceSetting = newDistance;
                  _trackColor = newColor;
                  _trackStrokeWidth = newWidth;
               });
               // Zapisz nowe ustawienia
               _saveSetting('minTrackDistance', newDistance);
               _saveSetting('trackColor', newColor.value); // Zapisz kolor jako int
               _saveSetting('trackStrokeWidth', newWidth);
            },
         );
      },
   );
}

    // --- NOWE METODY ZAPISU/ŁADOWANIA ---
  Future<void> _loadSavedTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? tracksJson = prefs.getStringList('savedTracks');
      if (tracksJson != null) {
        setState(() {
          _savedTracks = tracksJson
              .map((json) => jsonDecode(json) as Map<String, dynamic>)
              .toList();
        });
        debugPrint("Załadowano ${_savedTracks.length} tras.");
      }
    } catch (e) { debugPrint("Błąd ładowania tras: $e"); }
  }

  Future<void> _saveCurrentTrack() async {
    if (_trackPoints.length < 2) { // Zapisuj tylko jeśli są co najmniej 2 punkty
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trasa jest zbyt krótka, aby ją zapisać.')));
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackData = {
        'timestamp': DateTime.now().toIso8601String(), // Data zapisu
        'distance': _trackedDistance,
        'points': _trackPoints.map((p) => {'lat': p.latitude, 'lon': p.longitude}).toList(),
      };
      // Dodaj nową trasę do listy
      _savedTracks.add(trackData);
      // Zapisz całą listę tras z powrotem do SharedPreferences
      final List<String> tracksJson = _savedTracks.map((track) => jsonEncode(track)).toList();
      await prefs.setStringList('savedTracks', tracksJson);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trasa zapisana pomyślnie.')));
      // Opcjonalnie wyczyść bieżącą trasę po zapisie
      // _clearTrack();
      setState(() {}); // Aby zaktualizować np. listę zapisanych tras, jeśli ją wyświetlasz
    } catch (e) {
       debugPrint("Błąd zapisu trasy: $e");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu trasy: $e')));
    }
  }
void _clearTrack() {
    setState(() {
      _trackPoints.clear();
      _lastTrackPointAdded = null;
      _trackAltitudes.clear();
      _trackedDistance = 0.0;
      // Jeśli wyświetlaliśmy właśnie tę trasę, też ją usuńmy z widoku mapy
      _trackingStartTime = null; // Resetuj czas startu
      _maxSpeed = 0.0;         // Resetuj max prędkość
      if (_displayedSavedTrackTimestamp == null && _displayedSavedTrack != null) {
         _displayedSavedTrack = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bieżąca ścieżka wyczyszczona.')));
  }


// --- NOWE METODY: Ładowanie/Zapis Ustawień ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _minTrackDistanceSetting = prefs.getDouble('minTrackDistance') ?? 5.0;
      _trackColor = Color(prefs.getInt('trackColor') ?? Colors.redAccent.value);
      _trackStrokeWidth = prefs.getDouble('trackStrokeWidth') ?? 4.0;
    });
    debugPrint("Ustawienia załadowane: dist=$_minTrackDistanceSetting, color=$_trackColor, width=$_trackStrokeWidth");
  }

  Future<void> _saveSetting<T>(String key, T value) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      if (value is double) await prefs.setDouble(key, value);
      else if (value is int) await prefs.setInt(key, value);
      else if (value is String) await prefs.setString(key, value);
      // --- POPRAWKA TUTAJ ---
      else if (value is bool) await prefs.setBool(key, value); // Poprawna nazwa metody
      // ----------------------
      else if (value is Color) await prefs.setInt(key, value.value); // Zapisz kolor jako int
      debugPrint("Zapisano ustawienie: $key = $value");
    } catch (e) {
       debugPrint("Błąd zapisu ustawienia $key: $e");
    }
  }
  // ------------------------------------------

  // -----------------------------
  // NMEA + Parsowanie
  // -----------------------------
  void _startNmeaStream() {
    if (_nmeaSubscription != null) return;
    setState(() {
      _permissionStatus = 'Uruchamianie strumienia NMEA...';
      _gnssError = null;
    });

    _satelliteCleanupTimer?.cancel();
    _satelliteCleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanupInactiveSatellites();
    });

    _nmeaSubscription = _nmeaEventChannel.receiveBroadcastStream().listen(
      (data) {
        if (!mounted) return;
        if (data is Map) {
          final msg = data['message'] as String?;
          if (msg != null) {
            // Parsowanie GSV
            final sats = _parseNmeaGsvMessage(msg);
            if (sats.isNotEmpty) {
              final now = DateTime.now();
              bool satellitesChanged = false;
              for (var sat in sats) {
                // Historia SNR
                if (sat.snr != null && sat.snr! > 0) {
                  final hist = _snrHistory.putIfAbsent(sat.key, () => []);
                  hist.add(SnrDataPoint(now, sat.snr!));
                  if (hist.length > _maxHistoryLength) {
                    hist.removeAt(0);
                  }
                }

                // Widoczne satelity
                final existing = _visibleSatellites[sat.key];
                if (existing == null || existing != sat) {
                  _visibleSatellites[sat.key] = sat;
                  satellitesChanged = true;
                }
                _lastSeenSatellite[sat.key] = now;
              }
              if (satellitesChanged) {
                setState(() {
                  if (!_permissionStatus.contains('Odbieranie')) {
                    _permissionStatus = 'Odbieranie danych lokalizacyjnych i NMEA...';
                  }
                  _gnssError = null;
                });
              }
            }
            // GGA, GSA
            _parseNmeaGgaMessage(msg);
            _parseNmeaGsaMessage(msg);
          }
        }
      },
      onError: (error) {
        if (!mounted) return;
        debugPrint("Błąd NMEA: $error");
        String msg = "Nieznany błąd NMEA.";
        if (error is PlatformException) {
          msg = "Błąd NMEA (${error.code}): ${error.message}";
          if (error.code == "PERMISSION_DENIED") {
            msg = "Brak uprawnień do odczytu NMEA.";
          } else if (error.code == "GPS_DISABLED") {
            msg = "GPS wyłączony.";
          }
        }
        setState(() {
          _gnssError = msg;
          _visibleSatellites.clear();
          _lastSeenSatellite.clear();
          _permissionStatus = 'Błąd strumienia NMEA.';
        });
      },
      cancelOnError: false,
    );
  }

  List<NmeaSatellite> _parseNmeaGsvMessage(String message) {
    if (!message.contains('GSV,') ||
        !message.startsWith('\$') ||
        !message.contains('*')) {
      return [];
    }
    final parts = message.substring(0, message.indexOf('*')).split(',');
    if (parts.length < 4) return [];

    final header = parts[0];
    if (!header.endsWith('GSV') || header.length < 5) return [];

    String? system;
    final systemId = header.substring(1, 3);
    switch (systemId) {
      case 'GP': system = 'GPS'; break;
      case 'GL': system = 'GLONASS'; break;
      case 'GA': system = 'Galileo'; break;
      case 'GB':
      case 'BD': system = 'BeiDou'; break;
      case 'QZ': system = 'QZSS'; break;
      case 'NV':
      case 'GI': system = 'NavIC'; break;
      default: return [];
    }

    final List<NmeaSatellite> result = [];
    for (int i = 4; i + 3 < parts.length; i += 4) {
      final svid = int.tryParse(parts[i]);
      if (svid == null || svid == 0) continue;
      final el = double.tryParse(parts[i+1]);
      final az = double.tryParse(parts[i+2]);
      final snr = double.tryParse(parts[i+3]);
      result.add(NmeaSatellite(
        svid: svid, system: system, elevation: el, azimuth: az, snr: snr));
    }
    return result;
  }

  void _parseNmeaGgaMessage(String message) {
    if (!message.contains('GGA,')) return;
    try {
      final parts = message.substring(0, message.indexOf('*')).split(',');
      if (parts.length > 6 && parts[6].isNotEmpty) {
        final newQuality = int.tryParse(parts[6]);
        if (newQuality != null && newQuality != _fixQualityGga) {
          setState(() => _fixQualityGga = newQuality);
        }
      }
    } catch (e) {
      debugPrint("Błąd GGA: $e / $message");
    }
  }

  void _parseNmeaGsaMessage(String message) {
    if (!message.contains('GSA,')) return;
    try {
      final parts = message.substring(0, message.indexOf('*')).split(',');
      if (parts.length > 17) {
        Set<int> currentActive = {};
        for (int i = 3; i <= 14; i++) {
          if (parts[i].isNotEmpty) {
            final svid = int.tryParse(parts[i]);
            if (svid != null && svid > 0) {
              currentActive.add(svid);
            }
          }
        }
        final pdop = double.tryParse(parts[15]);
        final hdop = double.tryParse(parts[16]);
        final vdop = double.tryParse(parts[17]);

        bool svidsChanged = !setEquals(_activeSatelliteSvidsGsa, currentActive);
        bool dopsChanged = (pdop != _pdopGsa || hdop != _hdopGsa || vdop != _vdopGsa);
        if (svidsChanged || dopsChanged) {
          setState(() {
            _activeSatelliteSvidsGsa = currentActive;
            _pdopGsa = pdop;
            _hdopGsa = hdop;
            _vdopGsa = vdop;
          });
        }
      }
    } catch (e) {
      debugPrint("Błąd GSA: $e / $message");
    }
  }

  void _cleanupInactiveSatellites() {
    if (!mounted) return;
    final now = DateTime.now();
    final toRemove = <String>[];
    _lastSeenSatellite.forEach((key, lastTime) {
      if (now.difference(lastTime) > _satelliteTimeout) {
        toRemove.add(key);
      }
    });
    if (toRemove.isNotEmpty) {
      setState(() {
        for (var key in toRemove) {
          _visibleSatellites.remove(key);
          _lastSeenSatellite.remove(key);
        }
      });
    }
  }

  void _stopNmeaStream() {
    _nmeaSubscription?.cancel();
    _nmeaSubscription = null;
    _satelliteCleanupTimer?.cancel();
    _satelliteCleanupTimer = null;
  }

  // --- NOWA METODA: Eksport do GPX ---
Future<void> _exportTrackAsGpx() async {
  if (_trackPoints.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak trasy do wyeksportowania.')));
    return;
  }

  // 1. Stwórz zawartość pliku GPX jako string XML
  final StringBuffer gpxContent = StringBuffer();
  gpxContent.writeln('<?xml version="1.0" encoding="UTF-8"?>');
  gpxContent.writeln('<gpx version="1.1" creator="Surpad Lite" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');
  gpxContent.writeln('  <metadata>');
  gpxContent.writeln('    <name>Surpad Lite Track ${DateTime.now().toIso8601String()}</name>');
  gpxContent.writeln('    <time>${DateTime.now().toUtc().toIso8601String()}Z</time>'); // Czas UTC
  gpxContent.writeln('  </metadata>');
  gpxContent.writeln('  <trk>');
  gpxContent.writeln('    <name>Aktualna Trasa</name>');
  gpxContent.writeln('    <trkseg>');

  // Dodaj punkty trasy
  for (final point in _trackPoints) {
    gpxContent.writeln('      <trkpt lat="${point.latitude.toStringAsFixed(7)}" lon="${point.longitude.toStringAsFixed(7)}">');
    // Opcjonalnie można dodać czas dla każdego punktu, jeśli go zapisujemy
    // gpxContent.writeln('        <time>${point.timestamp?.toUtc().toIso8601String()}Z</time>');
    gpxContent.writeln('      </trkpt>');
  }

  gpxContent.writeln('    </trkseg>');
  gpxContent.writeln('  </trk>');
  gpxContent.writeln('</gpx>');

  try {
    // 2. Zapisz string do pliku tymczasowego
    final Directory tempDir = await getTemporaryDirectory(); // Katalog tymczasowy
    final String fileName = 'surpad_lite_track_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final File file = File('${tempDir.path}/$fileName');
    await file.writeAsString(gpxContent.toString());
    debugPrint('GPX zapisany tymczasowo w: ${file.path}');

    // 3. Udostępnij plik za pomocą share_plus
    final result = await Share.shareXFiles(
       [XFile(file.path, mimeType: 'application/gpx+xml')], // Ważne: podaj typ MIME
       subject: 'Eksport trasy Surpad Lite',
       text: 'Plik GPX z zapisaną trasą.',
    );

    if (result.status == ShareResultStatus.success) {
       debugPrint('Plik GPX udostępniony pomyślnie.');
    } else {
       debugPrint('Udostępnianie pliku GPX anulowane lub nieudane: ${result.status}');
       // Można pokazać SnackBar
    }
    // Plik tymczasowy zostanie usunięty przez system operacyjny

  } catch (e) {
     debugPrint("Błąd eksportu GPX: $e");
     if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd eksportu GPX: $e')));
     }
  }
}

  // -----------------------------
  // UI – Scaffold
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Surpad Lite - SNR Chart'),
        actions: [
          // Przycisk rotacji mapy
          IconButton(
            icon: Icon(_mapIsRotating ? Icons.navigation_rounded : Icons.north_rounded),
            tooltip: _mapIsRotating ? 'Tryb Heading Up' : 'Tryb North Up',
            onPressed: () {
              setState(() {
                _mapIsRotating = !_mapIsRotating;
                if (_currentPosition != null) {
                  final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                  if (_mapIsRotating) {
                    _mapController.moveAndRotate(latLng, _mapController.zoom, _activeHeading);
                  } else {
                    _mapController.moveAndRotate(latLng, _mapController.zoom, 0.0);
                  }
                }
              });
            },
          ),
          // Start/Stop Śledzenia
          IconButton(
            icon: Icon(_isTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
            tooltip: _isTracking ? 'Zatrzymaj śledzenie' : 'Rozpocznij śledzenie',
            color: _isTracking ? Colors.redAccent : null,
            onPressed: () {
              setState(() {
      _isTracking = !_isTracking;
      if (!_isTracking) {
        _lastTrackPointAdded = null; // Zresetuj dla następnego startu
      } else {
        // Rozpoczęcie śledzenia - WYCZYŚĆ poprzednie dane
        _trackPoints.clear();
        _trackAltitudes.clear(); // <<--- WAŻNE: Wyczyść też wysokości
        _trackedDistance = 0.0;
        _lastTrackPointAdded = null;
        _trackingStartTime = DateTime.now(); // <<--- ZAPISZ CZAS STARTU
        _maxSpeed = 0.0;                 // <<--- ZRESETUJ MAX PRĘDKOŚĆ
        debugPrint('[TRACKING START] Rozpoczęto śledzenie, listy wyczyszczone.');
        // Nie dodajemy tu pierwszego punktu, poczekamy na pierwszy event z listen()
      }
    });
  },
          ),
              if (_isTracking || _trackPoints.length >= 2) // Pokaż, jeśli śledzimy lub jest co zapisać
      IconButton(
        icon: const Icon(Icons.save_alt_rounded),
        tooltip: 'Zapisz aktualną trasę',
        onPressed: _saveCurrentTrack,
      ),
      
          // Czyszczenie ścieżki
          if (_trackPoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Wyczyść ścieżkę',
              onPressed: () {
                setState(() {
                  _trackPoints.clear();
                  _lastTrackPointAdded = null;
                  _trackedDistance = 0.0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ścieżka wyczyszczona.'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
                if (_trackPoints.length >= 2) // Pokaż tylko jeśli jest co eksportować
      IconButton(
        icon: const Icon(Icons.share_rounded),
        tooltip: 'Eksportuj trasę do GPX',
        onPressed: _exportTrackAsGpx,
      ),
          // Centrowanie
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Wycentruj mapę',
            onPressed: _centerMapOnLocation,
          ),
              IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Ustawienia',
      onPressed: _showSettingsBottomSheet, // Wywołaj nową metodę
    ),
          // Odśwież
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież',
            onPressed: _onRefreshPressed,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }
  

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_permissionStatus),
        ]),
      );
    }

    // Błąd krytyczny
    if ((_error != null && _currentPosition == null &&
         (_gnssError != null || _visibleSatellites.isEmpty))
        || _permissionStatus.contains('Odmówiono')
        || _permissionStatus.contains('wyłączone')) {
      return _buildCriticalError();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_gnssError != null && _visibleSatellites.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "Info NMEA: $_gnssError",
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
        if (_error != null && _currentPosition != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "Info Lokalizacji: $_error",
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
        Row( // Użyj Row dla statusu i wskaźnika
          children: [
            Text("Status: $_permissionStatus", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            const Spacer(), // Wypełnij przestrzeń
            // --- NOWY: Wskaźnik śledzenia ---
            if (_isTracking)
               _buildTrackingIndicator(),
            // ------------------------------
          ],
        ),
        const SizedBox(height: 10),

        // Karta mapy (z overlay kompasu)
        _buildMapCard(),
        const SizedBox(height: 16),

        // Karta lokalizacji (GGA/GSA)
        _buildLocationCard(),
        const SizedBox(height: 16),

        // --- NOWA KARTA z dużym kompasem rysowanym w CustomPaint ---
        _buildCompassCard(),
        const SizedBox(height: 16),

        // Karta GNSS
        _buildGnssStatusCard(),
        const SizedBox(height: 16),

        // Karta Wykresu SNR
        _buildSignalChartCard(),
        const SizedBox(height: 16),

        _buildElevationChartCard(),
        const SizedBox(height: 16), // <<--- DODANA KARTA PROFILU WYSOKOŚCI

        _buildSavedTracksCard(), // <<--- DODANA KARTA ZAPISANYCH TRAS
      ],
    );
  }

// --- NOWY WIDGET: Wskaźnik śledzenia ---
  Widget _buildTrackingIndicator() {
     // Prosty timer do mrugania (zamiast AnimationController dla uproszczenia)
     // Można by go zoptymalizować, tworząc go raz w initState
     final bool showDot = (DateTime.now().second % 2 == 0); // Mrugaj co sekundę

     return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
            AnimatedOpacity( // Płynne pojawianie/znikanie kropki
               opacity: showDot ? 1.0 : 0.3,
               duration: const Duration(milliseconds: 500),
               child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
               ),
            ),
            const SizedBox(width: 4),
            Text('NAGRYWANIE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
         ],
      );
  }
  // ---------------------------------------


  Widget _buildCriticalError() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Problem z uruchomieniem:',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.red)),
          const SizedBox(height: 8),
          if (_error != null) Text(_error!, textAlign: TextAlign.center),
          if (_gnssError != null) Text(_gnssError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text("Status: $_permissionStatus", style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text("Otwórz ustawienia aplikacji"),
            onPressed: openAppSettings,
          ),
        ]),
      ),
    );
  }

  void _centerMapOnLocation() {
    if (_currentPosition != null) {
      final latLng = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      if (_mapIsRotating) {
        _mapController.moveAndRotate(latLng, 15.0, _activeHeading);
      } else {
        _mapController.move(latLng, 15.0);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poczekaj na ustalenie pozycji.')),
      );
    }
  }

  void _onRefreshPressed() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _stopNmeaStream();
    setState(() {
      _isLoading = true;
      _currentPosition = null;
      _visibleSatellites.clear();
      _lastSeenSatellite.clear();
      _trackingStartTime = null; // Resetuj czas startu
      _maxSpeed = 0.0;         // Resetuj max prędkość
      _error = null;
      _gnssError = null;
      _clearGgaGsaData();
      _snrHistory.clear();
      _trackPoints.clear(); // <<--- Resetuj ścieżkę
       _trackAltitudes.clear(); // <<--- Wyczyść wysokości
      _lastTrackPointAdded = null;
      _trackedDistance = 0.0; // <<--- Resetuj dystans
      _displayedSavedTrack = null; // Wyczyść wyświetlaną trasę
      _displayedSavedTrackTimestamp = null;
      _permissionStatus = 'Ponowne uruchamianie...';
    });
    Future.delayed(const Duration(milliseconds: 100), _requestPermissionAndStartStreams);
  }

// --- Eksport ZAPISANEJ Trasy ---
  Future<void> _exportSpecificTrack(int index) async {
     if (index < 0 || index >= _savedTracks.length) return;
     final trackData = _savedTracks[index];
     final List<dynamic>? pointsData = trackData['points'] as List<dynamic>?;
     final timestamp = trackData['timestamp'] as String? ?? DateTime.now().toIso8601String();
     final distance = trackData['distance'] as double? ?? 0.0;

     if (pointsData == null || pointsData.length < 2) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak wystarczających danych w tej trasie.')));
       return;
     }

     final List<LatLng> points = pointsData
         .map((p) => LatLng(p['lat'] as double, p['lon'] as double))
         .toList();

     // --- Budowanie GPX (podobne jak poprzednio, ale z danych trackData) ---
      final StringBuffer gpxContent = StringBuffer();
      gpxContent.writeln('<?xml version="1.0" encoding="UTF-8"?>');
      gpxContent.writeln('<gpx version="1.1" creator="Surpad Lite" xmlns="http://www.topografix.com/GPX/1/1" ...>'); // Dodaj przestrzenie nazw
      gpxContent.writeln('  <metadata>');
      gpxContent.writeln('    <name>Surpad Lite Track $timestamp</name>'); // Użyj timestampu trasy
      gpxContent.writeln('    <time>${DateTime.tryParse(timestamp)?.toUtc().toIso8601String() ?? DateTime.now().toUtc().toIso8601String()}Z</time>');
      gpxContent.writeln('    <desc>Dystans: ${_formatDistance(distance)}</desc>'); // Dodaj dystans
      gpxContent.writeln('  </metadata>');
      gpxContent.writeln('  <trk>');
      gpxContent.writeln('    <name>Trasa $timestamp</name>');
      gpxContent.writeln('    <trkseg>');
      for (final point in points) {
        gpxContent.writeln('      <trkpt lat="${point.latitude.toStringAsFixed(7)}" lon="${point.longitude.toStringAsFixed(7)}"></trkpt>');
      }
      gpxContent.writeln('    </trkseg>');
      gpxContent.writeln('  </trk>');
      gpxContent.writeln('</gpx>');
     // --------------------------------------------------------------------

      try {
        final Directory tempDir = await getTemporaryDirectory();
        final String safeTimestamp = timestamp.replaceAll(':', '-').replaceAll('.', '-'); // Bezpieczna nazwa pliku
        final String fileName = 'surpad_lite_track_$safeTimestamp.gpx';
        final File file = File('${tempDir.path}/$fileName');
        await file.writeAsString(gpxContent.toString());
        debugPrint('GPX zapisany tymczasowo w: ${file.path}');

        final result = await Share.shareXFiles([XFile(file.path, mimeType: 'application/gpx+xml')], subject: 'Eksport trasy Surpad Lite $timestamp');
        // ... (obsługa wyniku Share) ...
      } catch (e) { /* ... obsługa błędu ... */ }
  }


  // --- NOWE METODY ZARZĄDZANIA TRASAMI ---

  // Wyświetla wybraną zapisaną trasę na mapie
  void _displaySavedTrack(int index) {
    if (index < 0 || index >= _savedTracks.length) return;
    final trackData = _savedTracks[index];
    final List<dynamic>? pointsData = trackData['points'] as List<dynamic>?;
    final timestamp = trackData['timestamp'] as String?; // Pobierz timestamp

    if (pointsData != null && timestamp != null) {
      final List<LatLng> points = pointsData
          .map((p) => LatLng(p['lat'] as double, p['lon'] as double))
          .toList();
      setState(() {
        _displayedSavedTrack = points;
        _displayedSavedTrackTimestamp = timestamp; // Zapisz timestamp wyświetlanej trasy
      });
      // Opcjonalnie: wycentruj mapę na początku zapisanej trasy
      if (points.isNotEmpty) {
         _mapController.move(points.first, 14.0); // Zoom 14
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wyświetlono zapisaną trasę.'), duration: Duration(seconds: 1)));
    }
  }

  // Ukrywa wyświetlaną zapisaną trasę
  void _hideSavedTrack() {
    if (_displayedSavedTrack != null) {
      setState(() {
        _displayedSavedTrack = null;
        _displayedSavedTrackTimestamp = null;
      });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ukryto zapisaną trasę.'), duration: Duration(seconds: 1)));
    }
  }

  // Usuwa zapisaną trasę z listy i SharedPreferences
  Future<void> _deleteSavedTrack(int index) async {
    if (index < 0 || index >= _savedTracks.length) return;
    final timestampToDelete = _savedTracks[index]['timestamp']; // Timestamp usuwanej trasy

    // Wyświetl dialog potwierdzający
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Potwierdź usunięcie'),
          content: const Text('Czy na pewno chcesz usunąć tę zapisaną trasę?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Usuń', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Sprawdź, czy usuwana trasa jest aktualnie wyświetlana
        if (_displayedSavedTrackTimestamp == timestampToDelete) {
           _displayedSavedTrack = null; // Ukryj ją, jeśli jest usuwana
           _displayedSavedTrackTimestamp = null;
        }
        // Usuń z listy w stanie
        setState(() {
          _savedTracks.removeAt(index);
        });
        // Zapisz zaktualizowaną listę do SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final List<String> tracksJson = _savedTracks.map((track) => jsonEncode(track)).toList();
        await prefs.setStringList('savedTracks', tracksJson);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trasa usunięta.')));
      } catch (e) {
        debugPrint("Błąd usuwania trasy: $e");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usuwania trasy: $e')));
      }
    }
  }
  // -----------------------------------------
  // --- NOWA METODA: Formatowanie dystansu (metry/kilometry) ---
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m'; // Pokaż metry bez miejsc po przecinku
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(2)} km'; // Pokaż kilometry z 2 miejscami
    }
  }


  //
  // KARTA MAPY – z overlay kompasa w rogu
  //
  Widget _buildMapCard() {
    final lat = _currentPosition?.latitude ?? 52.23;
    final lon = _currentPosition?.longitude ?? 21.01;
    final initialCenter = LatLng(lat, lon);
    final double initialZoom = _currentPosition != null ? 15.0 : 6.0;


    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  // ewentualnie tileProvider: FMTC.instance.getTileProvider(),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.surpad_lite',
                ),                // --- NOWA: Warstwa Okręgu Dokładności ---
                if (_currentPosition != null && _currentPosition!.accuracy > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        radius: _currentPosition!.accuracy, // Promień w metrach
                        useRadiusInMeter: true, // WAŻNE: Powiedz flutter_map, że promień jest w metrach
                        color: Colors.blue.withOpacity(0.15),
                        borderColor: Colors.blue.withOpacity(0.3),
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                
                
                if (_displayedSavedTrack != null)
                   PolylineLayer(
                      polylines: [
                        Polyline(
                           points: _displayedSavedTrack!,
                           color: Colors.purpleAccent, // Inny kolor dla zapisanej
                           strokeWidth: 3.0,
                           isDotted: true, // Może być kropkowana dla odróżnienia
                        ),
                      ],
                   ),
                   // -------------------------------------
                PolylineLayer(
                  polylines: [
                    Polyline(points: _trackPoints, color: Colors.redAccent, strokeWidth: 4.0),
                  ],
                ),
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 80, height: 80,
                        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                        child: _buildPositionMarker(),
                      )
                    ],
                  ),
              ],
            ),
            // Mały overlay kompas
            Positioned(
              top: 10,
              right: 10,
              child: _buildCompassIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  // Mały widget kompasu w rogu mapy
  Widget _buildCompassIndicator() {
    final double heading = _compassHeading ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(6.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
      ),
      child: Transform.rotate(
        angle: radians(-heading),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.navigation_rounded, size: 25.0, color: Colors.redAccent),
            Container(
              width: 4, height: 4,
              decoration: BoxDecoration(
                color: Colors.white70,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Marker pozycji
  Widget _buildPositionMarker() {
    bool headingFromGps = false;
    if (_currentPosition != null &&
        _currentPosition!.speed > 0.8 &&
        _currentPosition!.headingAccuracy > 0 &&
        _currentPosition!.headingAccuracy < 90 &&
        _activeHeading == _currentPosition!.heading) {
      headingFromGps = true;
    }
    if (_mapIsRotating || headingFromGps) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue[700]!.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0,2))],
          ),
          child: Transform.rotate(
            angle: radians(_activeHeading),
            child: const Icon(Icons.navigation_rounded, size: 20, color: Colors.white),
          ),
        ),
      );
    } else {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue[700]!.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0,2))],
          ),
          child: const SizedBox(
            width: 12, height: 12,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      );
    }
  }

  //
  // KARTA KOMPASU – duży customowy kompas
  //
  Widget _buildCompassCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kompas', style: theme.textTheme.titleLarge),
            const Divider(),
            const SizedBox(height: 16),

            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                // ewentualne dekoracje
                child: CustomPaint(
                  painter: CompassPainter(_compassHeading, context),
                  size: Size.infinite,
                ),
              ),
            ),
            // Można dodać np. info o headingAccuracy
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Karta Lokalizacji
  // ---------------------------
  Widget _buildLocationCard() {
    final theme = Theme.of(context);
    if (_currentPosition == null) {
      return Card(
        elevation: 4,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Center(child: Text('Oczekiwanie na pierwszą pozycję...')),
        ),
      );
    }
    // Oblicz czas trwania i średnią prędkość (tylko jeśli śledzimy)
    Duration? trackingDuration;
    double averageSpeedKmh = 0.0; // km/h
    if (_isTracking && _trackingStartTime != null && _trackedDistance > 0) {
       trackingDuration = DateTime.now().difference(_trackingStartTime!);
       final durationInSeconds = trackingDuration.inSeconds;
       if (durationInSeconds > 0) {
          double averageSpeedMps = _trackedDistance / durationInSeconds;
          averageSpeedKmh = averageSpeedMps * 3.6; // Konwersja m/s na km/h
       }
    }

    // Formatowanie czasu trwania
    String durationString = "00:00:00";
    if (trackingDuration != null) {
       durationString = trackingDuration.toString().split('.').first.padLeft(8, "0"); // Format HH:MM:SS
    }


    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Aktualna Lokalizacja i Trasa', style: theme.textTheme.titleLarge), // Zmieniony tytuł
          const Divider(),
          // --- Dane Geolocator (jeśli jest pozycja) ---
          if (_currentPosition != null) ...[
             _buildInfoRow('Szerokość (Lat):', _formatCoordinate(_currentPosition!.latitude)),
             _buildInfoRow('Długość (Lon):', _formatCoordinate(_currentPosition!.longitude)),
             _buildInfoRow('Wysokość (Alt):', _formatValue(_currentPosition!.altitude, unit: ' m')),
             _buildInfoRow('Dokładność (Hor.):', _formatValue(_currentPosition!.accuracy, unit: ' m')),
             _buildInfoRow('Dokł. wysokości:', _formatValue(_currentPosition!.altitudeAccuracy, unit: ' m')),
             _buildInfoRow('Prędkość:', _formatValue(_currentPosition!.speed, unit: ' m/s')),
             _buildInfoRow('Dokł. prędkości:', _formatValue(_currentPosition!.speedAccuracy, unit: ' m/s')),
             _buildInfoRow('Kierunek (Kurs):', _formatValue(_currentPosition!.heading, precision: 0, unit: '°')),
             _buildInfoRow('Dokł. kierunku:', _formatValue(_currentPosition!.headingAccuracy, precision: 0, unit: '°')),
             _buildInfoRow('Czas fixa:', _currentPosition!.timestamp?.toLocal().toString() ?? 'N/A'),
          ] else
             const Text("Oczekiwanie na pierwszą pozycję...", style: TextStyle(fontStyle: FontStyle.italic)),

          // --- Dane GGA/GSA (zawsze widoczne, pokazują N/A jeśli brak) ---
          const Divider(height: 16, thickness: 0.5),
          _buildInfoRow('Jakość Fixa (GGA):', _getFixQualityString(_fixQualityGga)),
          _buildInfoRow('Satelity w fixie (GSA):', _activeSatelliteSvidsGsa.length.toString()),
          _buildInfoRow('PDOP (GSA):', _formatValue(_pdopGsa, precision: 1)),
          _buildInfoRow('HDOP (GSA):', _formatValue(_hdopGsa, precision: 1)),
          _buildInfoRow('VDOP (GSA):', _formatValue(_vdopGsa, precision: 1)),

          // --- Statystyki Trasy (widoczne tylko podczas lub po śledzeniu) ---
          if (_isTracking || _trackPoints.isNotEmpty) ...[
             const Divider(height: 16, thickness: 0.5),
             Text("Statystyki Trasy:", style: theme.textTheme.titleMedium?.copyWith(fontSize: 15)), // Podtytuł
             _buildInfoRow('Czas trwania:', durationString),
             _buildInfoRow('Dystans:', _formatDistance(_trackedDistance)),
             _buildInfoRow('Śr. prędkość:', '${averageSpeedKmh.toStringAsFixed(1)} km/h'),
             _buildInfoRow('Max prędkość:', '${(_maxSpeed * 3.6).toStringAsFixed(1)} km/h'), // Pokaż w km/h
             _buildInfoRow('Liczba punktów:', _trackPoints.length.toString()),
          ]
        ]),
      ),
    );
  }
  String _getFixQualityString(int? quality) {
    switch (quality) {
      case 0: return 'Brak fixa';
      case 1: return 'Fix autonomiczny (SPS)';
      case 2: return 'DGPS (różnicowy)';
      case 3: return 'PPS (wojskowy)';
      case 4: return 'RTK Fixed';
      case 5: return 'RTK Float';
      case 6: return 'Estymacja (Dead Reckoning)';
      case 7: return 'Tryb manualny';
      case 8: return 'Symulacja';
      default: return 'N/A';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ]),
    );
  }

  String _formatCoordinate(double? coord) => coord?.toStringAsFixed(6) ?? 'N/A';
  String _formatValue(double? val, {int precision=1, String unit=''}) {
    if (val == null) return 'N/A';
    return '${val.toStringAsFixed(precision)}$unit';
  }

    // --- NOWA METODA: Budowanie Karty Zapisanych Tras ---
  Widget _buildSavedTracksCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row( // Tytuł i przycisk ukrycia trasy
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Zapisane Trasy', style: theme.textTheme.titleLarge),
                if (_displayedSavedTrack != null) // Pokaż przycisk tylko, gdy coś jest wyświetlane
                   TextButton.icon(
                      icon: Icon(Icons.visibility_off_outlined, size: 18, color: theme.colorScheme.secondary),
                      label: Text('Ukryj trasę', style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary)),
                      onPressed: _hideSavedTrack,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                   )
              ],
            ),
            const Divider(),
            if (_savedTracks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(child: Text('Brak zapisanych tras.')),
              )
            else
              ListView.builder(
                shrinkWrap: true, // Aby ListView działał wewnątrz Column
                physics: const NeverScrollableScrollPhysics(), // Wyłącz scrollowanie wewnętrzne
                itemCount: _savedTracks.length,
                itemBuilder: (context, index) {
                  final trackData = _savedTracks[index];
                  final timestamp = DateTime.tryParse(trackData['timestamp'] ?? '')?.toLocal();
                  final distance = trackData['distance'] as double? ?? 0.0;
                  final pointCount = (trackData['points'] as List<dynamic>? ?? []).length;
                  final isDisplayed = _displayedSavedTrackTimestamp == trackData['timestamp'];

                  return ListTile(
                    dense: true, // Zmniejsz wysokość
                    leading: Icon(Icons.route_outlined, color: isDisplayed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                    title: Text(
                      timestamp != null ? 'Trasa z ${timestamp.day}.${timestamp.month}.${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2,'0')}' : 'Nieznana data',
                      style: TextStyle(fontWeight: isDisplayed ? FontWeight.bold : FontWeight.normal),
                    ),
                    subtitle: Text(
                      'Dystans: ${_formatDistance(distance)} | Punkty: $pointCount',
                       style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                trailing: Row( // Użyj Row dla dwóch przycisków
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      // --- NOWY: Przycisk Eksportuj ---
                      IconButton(
                        icon: Icon(Icons.share_outlined, size: 20, color: theme.colorScheme.secondary),
                        tooltip: 'Eksportuj tę trasę (GPX)',
                        onPressed: () => _exportSpecificTrack(index), // Wywołaj nową funkcję
                      ),
                      // -----------------------------
                      IconButton( // Przycisk Usuń
                        icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                        tooltip: 'Usuń trasę',
                        onPressed: () => _deleteSavedTrack(index),
                      ),
                   ]
                ),
                    onTap: () {
                       if (isDisplayed) {
                          _hideSavedTrack(); // Jeśli kliknięto wyświetlaną, ukryj ją
                       } else {
                          _displaySavedTrack(index); // Inaczej wyświetl klikniętą
                       }
                    },
                    selected: isDisplayed, // Podświetl wybraną
                    selectedTileColor: theme.colorScheme.primary.withOpacity(0.1), // Kolor podświetlenia
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Karta GNSS (Sky Plot)
  // ---------------------------
  Widget _buildGnssStatusCard() {
    final theme = Theme.of(context);
    final currentSats = _visibleSatellites.values.toList();
    final actuallyDetectedSystems = currentSats.map((s) => s.system).toSet();

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sky Plot i Systemy GNSS', style: theme.textTheme.titleLarge),
          const Divider(),
          const SizedBox(height: 8),

          // Lista systemów
          _buildDetectedSystemsList(actuallyDetectedSystems),
          const SizedBox(height: 12),

          Text('Widoczne Satelity:', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),

          if (_gnssError != null && currentSats.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text('Błąd NMEA: $_gnssError', style: TextStyle(color: Colors.red[700])),
            )
          else if (_nmeaSubscription == null && _gnssError == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Nasłuch NMEA nieaktywny.'),
            )
          else if (currentSats.isEmpty && _gnssError == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Oczekiwanie na dane satelitarne z NMEA...'),
            )
          else
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.blueGrey[850]
                      : Colors.blueGrey[200],
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor, width: 1.0),
                ),
                child: CustomPaint(
                  painter: SkyPlotPainter(
                    currentSats.where((sat) => _selectedSystemsForPlot.contains(sat.system)).toList(),
                    context,
                    _activeSatelliteSvidsGsa,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text('Filtruj Sky Plot:', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 8),
          _buildLegend(),
        ]),
      ),
    );
  }


  // --- NOWA METODA: Budowanie Karty Wykresu Elewacji ---
  Widget _buildElevationChartCard() {
    final theme = Theme.of(context);
    final List<FlSpot> spots = [];
    double cumulativeDistance = 0.0;
    double minAlt = double.infinity;
    double maxAlt = double.negativeInfinity;
    int validAltitudeCount = 0; // Licznik poprawnych wysokości
    // Przygotuj punkty dla wykresu (X: dystans, Y: wysokość)
    if (_trackPoints.length >= 2 && _trackPoints.length == _trackAltitudes.length) {
      // Pierwszy punkt - dodaj go tylko jeśli ma poprawną wysokość
      if (_trackAltitudes[0] != null) {
         spots.add(FlSpot(0.0, _trackAltitudes[0]!));
         minAlt = min(minAlt, _trackAltitudes[0]!);
         maxAlt = max(maxAlt, _trackAltitudes[0]!);
         validAltitudeCount++;
      }

      // Oblicz dystans i wysokość dla kolejnych punktów
      const Distance distance = Distance();
      for (int i = 1; i < _trackPoints.length; i++) {
         // Dodaj dystans od poprzedniego punktu
         cumulativeDistance += distance(_trackPoints[i - 1], _trackPoints[i]);
         final altitude = _trackAltitudes[i];
         // --- POPRAWKA 2: Dodaj punkt tylko jeśli wysokość NIE jest null ---
         if (altitude != null) {
            spots.add(FlSpot(cumulativeDistance, altitude));
            minAlt = min(minAlt, altitude);
            maxAlt = max(maxAlt, altitude);
            validAltitudeCount++;
         }
         // ----------------------------------------------------------------
      }
    }
   // Pokaż komunikat, jeśli mamy mniej niż 2 punkty z poprawną wysokością
      if (validAltitudeCount < 2) {
      return Card(
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Profil Wysokościowy Trasy', style: theme.textTheme.titleLarge),
               const Divider(),
               const SizedBox(height: 8),
               const Center(child: Padding(
                 padding: EdgeInsets.symmetric(vertical: 20),
                 // Zmień komunikat, aby był bardziej informacyjny
                 child: Text('Potrzeba co najmniej 2 punktów trasy\nz poprawną wysokością, aby narysować profil.')
               )),
             ]
          )
        ),
      );
    }
       // -------------------------------------------------------------

    // Jeśli nie ma danych, pokaż komunikat
    if (spots.isEmpty) {
      return Card(
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Profil Wysokościowy Trasy', style: theme.textTheme.titleLarge),
               const Divider(),
               const SizedBox(height: 8),
               const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Rozpocznij śledzenie, aby zobaczyć profil wysokościowy.'))),
             ]
          )
        ),
      );
    }

// Jeśli mamy wystarczająco danych, kontynuuj rysowanie wykresu...
    // Ustal zakres osi Y z marginesem
    final double yRange = maxAlt - minAlt;
    final double bottomMargin = yRange > 0 ? yRange * 0.1 : 10; // 10% marginesu lub 10m
    final double topMargin = yRange > 0 ? yRange * 0.1 : 10;
    // Unikaj sytuacji, gdy minAlt == maxAlt
    final double minY = (yRange == 0 ? minAlt - 5 : minAlt - bottomMargin).floorToDouble();
    final double maxY = (yRange == 0 ? maxAlt + 5 : maxAlt + topMargin).ceilToDouble();
    // Poprawiony interwał Y, aby uniknąć dzielenia przez zero lub bardzo małych wartości
    final double intervalY = ((maxY - minY) <= 1) ? 1 : ((maxY - minY) / 5).roundToDouble().clamp(1, double.infinity);


    // Ustal zakres osi X
    final double minX = 0.0;
    final double maxX = cumulativeDistance;
    // Poprawiony interwał X
    final double intervalX = maxX > 0 ? (maxX / 5).roundToDouble().clamp(1, double.infinity) : 1.0;



    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profil Wysokościowy Trasy', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 16 / 6, // Wykres może być bardziej płaski niż SNR
              child: LineChart(
                LineChartData(
                  // === Zakresy osi ===
                  minX: minX, maxX: maxX,
                  minY: minY, maxY: maxY,

                  // === Tytuły osi ===
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles( // Oś X (dystans)
                      axisNameWidget: const Text("Dystans", style: TextStyle(fontSize: 10)), // Tytuł osi
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30, interval: intervalX, // Dynamiczny interwał
                        getTitlesWidget: (value, meta) {
                          // Nie pokazuj etykiety dla 0, chyba że to jedyna
                          if (value == 0 && maxX > 0) return Container();
                           // Pokaż tylko kilka etykiet, aby uniknąć tłoku
                          final tickIndex = (value / intervalX).round();
                          if (tickIndex % ((maxX / intervalX / 5).ceil().clamp(1, 10)) != 0 && value != maxX) {
                             // return Container();
                          }
                          return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: Text(_formatDistance(value), style: const TextStyle(fontSize: 10)));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles( // Oś Y (wysokość)
                       axisNameWidget: const Text("Wysokość", style: TextStyle(fontSize: 10)),
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 40, interval: intervalY, // Dynamiczny interwał
                        getTitlesWidget: (value, meta) {
                          // Pokaż tylko co drugą etykietę, jeśli jest ich za dużo
                          if (value != minY && value != maxY && (value / intervalY).round() % 2 != 0 && (maxY-minY)/intervalY > 6) return Container();
                          return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: Text('${value.toInt()}m', style: const TextStyle(fontSize: 10)));
                        },
                      ),
                    ),
                  ),
                  // === Siatka ===
                  gridData: FlGridData(
                     show: true, drawVerticalLine: true, verticalInterval: intervalX,
                     drawHorizontalLine: true, horizontalInterval: intervalY,
                     getDrawingHorizontalLine: (v) => FlLine(color: theme.dividerColor.withOpacity(0.3), strokeWidth: 0.5),
                     getDrawingVerticalLine: (v) => FlLine(color: theme.dividerColor.withOpacity(0.3), strokeWidth: 0.5),
                  ),
                  // === Ramka ===
                  borderData: FlBorderData(show: true, border: Border.all(color: theme.dividerColor, width: 1)),
                  // === Dane Linii ===
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      // gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]), // Opcjonalny gradient
                      color: Colors.cyan, // Kolor linii
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData( // Wypełnienie pod wykresem
                         show: true,
                         gradient: LinearGradient(
                           colors: [Colors.cyan.withOpacity(0.3), Colors.cyan.withOpacity(0.0)],
                           begin: Alignment.topCenter,
                           end: Alignment.bottomCenter,
                         )
                         // color: Colors.cyan.withOpacity(0.2),
                      ),
                    ),
                  ],
                   // === Tooltipy ===
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((i) => TouchedSpotIndicatorData(FlLine(color: Colors.cyan[800]!), FlDotData(show: true, getDotPainter: (s,p,b,i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 1, strokeColor: Colors.cyan[800]!)))).toList(),
                    touchTooltipData: LineTouchTooltipData(
                       getTooltipColor: (spot) => Colors.black.withOpacity(0.7),
                       getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                             final distanceStr = maxX < 2000 ? '${spot.x.toStringAsFixed(0)} m' : '${(spot.x / 1000).toStringAsFixed(2)} km';
                             final altitudeStr = '${spot.y.toStringAsFixed(1)} m';
                             return LineTooltipItem(
                               'Dyst: $distanceStr\nWys: $altitudeStr',
                               const TextStyle(color: Colors.white, fontSize: 11),
                               textAlign: TextAlign.left
                             );
                          }).toList();
                       }
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // -------------------------------------------------------

Widget _buildDetectedSystemsList(Set<String> systems) {
    if (systems.isEmpty) return const SizedBox.shrink();
    final sorted = systems.toList()..sort();
    final theme = Theme.of(context); // Pobierz theme

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aktywne systemy (odbierane):', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0, runSpacing: 4.0,
          children: sorted.map((sys) {
            return Chip(
              label: Text(
                  sys,
                  // --- POPRAWKA: Ustaw kolor tekstu ---
                  style: TextStyle(
                      color: theme.brightness == Brightness.dark ? Colors.black87 : Colors.black54
                  )
                  // -----------------------------------
              ),
              backgroundColor: Colors.green[100], // Jasne tło pasuje do obu motywów
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            );
          }).toList(),
        ),
      ],
    );
  }

Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final colors = SkyPlotPainter([], context, {}).systemColors;
    return Wrap(
      spacing: 8.0,
      children: _allPossibleSystems.map((system) {
        final isSelected = _selectedSystemsForPlot.contains(system);
        final chipColor = colors[system] ?? colors['Unknown']!;
        final Color labelColor;
        if (isSelected) {
          labelColor = (chipColor.computeLuminance() < 0.5) ? Colors.white : Colors.black;
        } else {
          labelColor = Colors.black87;
        }

        return FilterChip(
          label: Text(system, style: TextStyle(fontSize: 11, color: labelColor)),
          selected: isSelected,
          onSelected: (val) {
            setState(() {
              if (val) {
                _selectedSystemsForPlot.add(system);
              } else {
                if (_selectedSystemsForPlot.length > 1) {
                  _selectedSystemsForPlot.remove(system);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Co najmniej jeden system musi być wybrany.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            });
          },
          avatar: CircleAvatar(backgroundColor: chipColor, radius: 6),
          selectedColor: chipColor,
          checkmarkColor: labelColor,
          backgroundColor: Colors.grey[300],
          shape: isSelected
              ? null
              : StadiumBorder(side: BorderSide(color: Colors.grey[400]!)),
        );
      }).toList(),
    );
  }

  Widget _buildLegend() {
    final theme = Theme.of(context);
    final colors = SkyPlotPainter([], context, {}).systemColors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8.0,
        alignment: WrapAlignment.center,
        children: colors.entries.where((e) => e.key != 'Unknown').map((entry) {
          final chipBackgroundColor = Colors.grey[300]!;
          final labelColor = Colors.black87;
          return Chip(
            avatar: CircleAvatar(backgroundColor: entry.value, radius: 6),
            label: Text(entry.key, style: TextStyle(fontSize: 10, color: labelColor)),
            backgroundColor: chipBackgroundColor,
            shape: StadiumBorder(side: BorderSide(color: Colors.grey[400]!)),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.only(left: 2.0, right: 4.0),
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------
  // Karta Wykresu SNR
  // ---------------------------
  Widget _buildSignalChartCard() {
    final List<LineChartBarData> lineBarsData = [];
    final List<NmeaSatellite> topSatellites = _getTopSatellitesForChart();
    final now = DateTime.now();
    final double maxSnr = 55;
    final double minSnr = 0;
    final double timeWindowSeconds = 60.0;

    final double minX = -timeWindowSeconds;
    final double maxX = 0;

    final colors = SkyPlotPainter([], context, {}).systemColors;

    for (int i = 0; i < topSatellites.length; i++) {
      final sat = topSatellites[i];
      final history = _snrHistory[sat.key];
      if (history != null && history.isNotEmpty) {
        final List<FlSpot> spots = history.map((dataPoint) {
          double secondsAgo = dataPoint.timestamp.difference(now).inSeconds.toDouble();
          if (secondsAgo < minX) return null;
          double snrValue = dataPoint.snr.clamp(minSnr, maxSnr);
          return FlSpot(secondsAgo, snrValue);
        }).whereType<FlSpot>().toList();

        if (spots.isNotEmpty) {
          lineBarsData.add(LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colors[sat.system] ?? colors['Unknown']!,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ));
        }
      }
    }

    final theme = Theme.of(context);

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Siła Sygnału (SNR) - Top $_topNForChart Satelitów', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (lineBarsData.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('Brak danych SNR do wyświetlenia.'),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 16/7,
                child: LineChart(
                  LineChartData(
                    minX: minX,
                    maxX: maxX,
                    minY: minSnr,
                    maxY: maxSnr,
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 15,
                          getTitlesWidget: (value, meta) {
                            int seconds = -value.round();
                            if (seconds < 0) seconds = 0;
                            if (seconds % 15 == 0 && seconds <= timeWindowSeconds) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 8.0,
                                child: Text('-${seconds}s'),
                              );
                            }
                            return Container();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 10,
                          getTitlesWidget: (value, meta) {
                            if (value > maxSnr || value < minSnr) return Container();
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 8.0,
                              child: Text('${value.toInt()} dB'),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: 15,
                      drawHorizontalLine: true,
                      horizontalInterval: 10,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: theme.dividerColor.withOpacity(0.3),
                        strokeWidth: 0.5,
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: theme.dividerColor.withOpacity(0.3),
                        strokeWidth: 0.5,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: theme.dividerColor, width: 1),
                    ),
                    lineBarsData: lineBarsData,
                    lineTouchData: LineTouchData(
                      handleBuiltInTouches: true,
                      getTouchedSpotIndicator: (barData, spotIndexes) {
                        return spotIndexes.map((index) {
                          return TouchedSpotIndicatorData(
                            FlLine(color: Colors.blueAccent, strokeWidth: 2),
                            FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: barData.color ?? Colors.blueAccent,
                                strokeWidth: 1,
                                strokeColor: Colors.white,
                              );
                            }),
                          );
                        }).toList();
                      },
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                          return touchedBarSpots.map((barSpot) {
                            String satInfo = 'Sat: ?';
                            if (barSpot.barIndex >= 0 && barSpot.barIndex < topSatellites.length) {
                              final satObj = topSatellites[barSpot.barIndex];
                              satInfo = '${satObj.system} ${satObj.svid}';
                            }
                            final String snrValue = barSpot.y.toStringAsFixed(1);
                            return LineTooltipItem(
                              '$satInfo\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: '$snrValue dB',
                                  style: TextStyle(
                                    color: barSpot.bar.color ?? Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              textAlign: TextAlign.left,
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<NmeaSatellite> _getTopSatellitesForChart() {
    final sats = _visibleSatellites.values.toList();
    sats.sort((a, b) => (b.snr ?? -1.0).compareTo(a.snr ?? -1.0));
    return sats.take(_topNForChart).toList();
  }
}

//
// SkyPlotPainter (bez zmian)
//
class SkyPlotPainter extends CustomPainter {
  final List<NmeaSatellite> satellites;
  final BuildContext context;
  final Set<int>? activeSvids;

  SkyPlotPainter(this.satellites, this.context, this.activeSvids);

  final Map<String, Color> systemColors = {
    'GPS': Colors.lightGreenAccent,
    'GLONASS': Colors.redAccent,
    'Galileo': Colors.lightBlueAccent,
    'BeiDou': Colors.orangeAccent,
    'QZSS': Colors.purpleAccent,
    'NavIC': Colors.tealAccent,
    'Unknown': Colors.grey,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final gridColor = colorScheme.onSurface.withOpacity(0.2);
    final labelColor = colorScheme.onSurface.withOpacity(0.7);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Okręgi 30°, 60°
    canvas.drawCircle(center, radius*2/3, gridPaint);
    canvas.drawCircle(center, radius*1/3, gridPaint);

    // Linie N-S, E-W
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);

    // Etykiety N, E, S, W
    _drawText(canvas, size, 'N', center.dx, center.dy - radius + 8, color: labelColor, align: TextAlign.center);
    _drawText(canvas, size, 'E', center.dx + radius - 8, center.dy, color: labelColor, align: TextAlign.right);
    _drawText(canvas, size, 'S', center.dx, center.dy + radius - 8, color: labelColor, align: TextAlign.center);
    _drawText(canvas, size, 'W', center.dx - radius + 8, center.dy, color: labelColor, align: TextAlign.left);

    final satPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()..style = PaintingStyle.stroke;

    for (final sat in satellites) {
      if (sat.azimuth == null || sat.elevation == null || sat.elevation! < 0) {
        continue;
      }
      final dist = radius * (90 - sat.elevation!) / 90;
      final angleRad = radians(sat.azimuth! - 90);
      final x = center.dx + dist * cos(angleRad);
      final y = center.dy + dist * sin(angleRad);

      final color = systemColors[sat.system] ?? systemColors['Unknown']!;
      double satRadius = 5;
      double opacity = 0.6;
      if (sat.snr != null && sat.snr! > 0) {
        satRadius = 4 + 5*((sat.snr! - 10).clamp(0, 40) / 40);
        opacity = 0.7 + 0.3*((sat.snr! - 10).clamp(0, 40) / 40);
      }
      satPaint.color = color.withOpacity(opacity);

      // Czy w fixie?
      final bool isActive = activeSvids?.contains(sat.svid) ?? false;

      final offset = Offset(x, y);
      canvas.drawCircle(offset, satRadius, satPaint);

      borderPaint
        ..color = isActive ? Colors.yellowAccent : Colors.black.withOpacity(0.5)
        ..strokeWidth = isActive ? 1.5 : 0.5;
      canvas.drawCircle(offset, satRadius, borderPaint);

      // SVID
      final svidText = sat.svid.toString();
      final svidFontSize = max(7.0, satRadius*1.1);
      final isDarkBg = color.computeLuminance() < 0.5;
      final textColor = isDarkBg ? Colors.white : Colors.black;
      _drawText(canvas, size, svidText, x, y,
          fontSize: svidFontSize, color: textColor, align: TextAlign.center);
    }
  }

  void _drawText(Canvas canvas, Size size, String text,
      double x, double y, {
      double fontSize = 10,
      Color color = Colors.white,
      TextAlign align = TextAlign.center,
  }) {
    final span = TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.bold),
    );
    final tp = TextPainter(
      text: span,
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    double dx = x;
    if (align == TextAlign.center) {
      dx = x - tp.width / 2;
    } else if (align == TextAlign.right) {
      dx = x - tp.width;
    }
    final offset = Offset(dx, y - tp.height / 2);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SkyPlotPainter oldDelegate) {
    return !listEquals(oldDelegate.satellites, satellites)
        || !setEquals(oldDelegate.activeSvids, activeSvids)
        || oldDelegate.context != context;
  }
}

// ===============================
// NOWY: Rysowanie Kompasu (POPRAWIONY Path)
// ===============================
class CompassPainter extends CustomPainter {
  final double? heading; // Aktualny kierunek kompasu (0-360)
  final BuildContext context;

  CompassPainter(this.heading, this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final theme = Theme.of(context);
    // Użyj 0 jeśli heading jest null, obróć przeciwnie do kierunku
    final double angle = radians(-(heading ?? 0.0));
    final double radius = min(size.width / 2, size.height / 2) * 0.9;
    final center = Offset(size.width / 2, size.height / 2);

    // Style rysowania
    final backgroundPaint = Paint()..color = theme.brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[300]!;
    final dialPaint = Paint()..color = theme.colorScheme.onSurface.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.0;
    final tickPaint = Paint()..color = theme.colorScheme.onSurface.withOpacity(0.8)..strokeWidth = 1.5;
    final majorTickPaint = Paint()..color = theme.colorScheme.onSurface..strokeWidth = 2.0;
    final northPaint = Paint()..color = Colors.redAccent[200]! ..style = PaintingStyle.fill; // Jaśniejszy czerwony
    final textStyle = TextStyle(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold);
    final degreeStyle = TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold);

    // Tło i obwódka tarczy
    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawCircle(center, radius, dialPaint);

    // Obracamy CAŁĄ tarczę (podziałkę i etykiety), igła będzie nieruchoma (wskazuje górę)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle); // Obróć tarczę
    canvas.translate(-center.dx, -center.dy);

    // Rysowanie podziałki i etykiet
    for (int i = 0; i < 360; i += 10) {
      final double tickAngleRad = radians(i.toDouble() - 90.0); // -90 bo 0 stopni to góra
      final double tickLength = (i % 30 == 0) ? 10.0 : 5.0;
      final tickPaintCurrent = (i % 90 == 0) ? majorTickPaint : tickPaint;

      final tickStart = Offset(center.dx + (radius - tickLength) * cos(tickAngleRad), center.dy + (radius - tickLength) * sin(tickAngleRad));
      final tickEnd = Offset(center.dx + radius * cos(tickAngleRad), center.dy + radius * sin(tickAngleRad));
      canvas.drawLine(tickStart, tickEnd, tickPaintCurrent);

      if (i % 30 == 0) {
        String label;
        switch (i) {
          case 0: label = 'N'; break; case 90: label = 'E'; break;
          case 180: label = 'S'; break; case 270: label = 'W'; break;
          default: label = i.toString();
        }
        final labelRadius = radius - tickLength - 15;
        final labelOffset = Offset(center.dx + labelRadius * cos(tickAngleRad), center.dy + labelRadius * sin(tickAngleRad));
        // Obracamy etykiety liczbowe, by były pionowo (opcjonalne)
        // if (i != 0 && i != 90 && i != 180 && i != 270) {
        //   canvas.save();
        //   canvas.translate(labelOffset.dx, labelOffset.dy);
        //   canvas.rotate(-angle); // Obróć z powrotem, by tekst był poziomo
        //   _drawText(canvas, size, label, 0, 0, style: textStyle.copyWith(fontSize: 10), align: TextAlign.center);
        //   canvas.restore();
        // } else {
           _drawText(canvas, size, label, labelOffset.dx, labelOffset.dy, style: textStyle, align: TextAlign.center);
        // }
      }
    }
    // Przywróć stan przed obrotem tarczy
    canvas.restore();

    // Igła wskazująca aktualny kierunek (zawsze na górze, bo tarczę obróciliśmy)
    // --- POPRAWKA: Użyj ui.Path ---
    final ui.Path needlePath = ui.Path();
    // -----------------------------
    needlePath.moveTo(center.dx, center.dy - radius * 0.8); // Czubek
    needlePath.lineTo(center.dx - 7, center.dy - radius * 0.5); // Lewa podstawa
    needlePath.lineTo(center.dx, center.dy + radius*0.1); // Dolny środek (lekko poniżej)
    needlePath.lineTo(center.dx + 7, center.dy - radius * 0.5); // Prawa podstawa
    needlePath.close();
    canvas.drawPath(needlePath, northPaint); // Narysuj igłę

    // Czarna kropka na środku
    canvas.drawCircle(center, 4, Paint()..color = Colors.black54);
    canvas.drawCircle(center, 4, Paint()..color = theme.colorScheme.onSurface.withOpacity(0.3)..style=PaintingStyle.stroke..strokeWidth=1);


    // Wyświetl cyfrowy odczyt na środku (nad igłą)
    final String headingValue = heading?.toStringAsFixed(0) ?? '---';
    _drawText(canvas, size, '$headingValue°', center.dx, center.dy - radius - 20, // Lekko nad tarczą
              style: degreeStyle.copyWith(fontSize: 16), align: TextAlign.center);
  }

  // Helper do rysowania tekstu (bez zmian)
  void _drawText(Canvas canvas, Size size, String text, double x, double y,
      {required TextStyle style, TextAlign align = TextAlign.center}) {
    final span = TextSpan(text: text, style: style);
    final textPainter = TextPainter(text: span, textAlign: align, textDirection: ui.TextDirection.ltr)..layout();
    double dx = x; if (align == TextAlign.center) dx = x - textPainter.width / 2; else if (align == TextAlign.right) dx = x - textPainter.width;
    textPainter.paint(canvas, Offset(dx, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.heading != heading || oldDelegate.context != context;
  }
}

// ===============================
// NOWY: Widget BottomSheet Ustawień
// ===============================
class SettingsBottomSheet extends StatefulWidget {
  final double initialMinDistance;
  final Color initialColor;
  final double initialStrokeWidth;
  // Callback do przekazania zmienionych ustawień z powrotem
  final Function(double, Color, double) onSettingsChanged;

  const SettingsBottomSheet({
     Key? key,
     required this.initialMinDistance,
     required this.initialColor,
     required this.initialStrokeWidth,
     required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _SettingsBottomSheetState createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  late double _currentMinDistance;
  late Color _currentColor;
  late double _currentStrokeWidth;

  // Prosta lista kolorów do wyboru
  final List<Color> _availableColors = [
     Colors.redAccent, Colors.blueAccent, Colors.greenAccent,
     Colors.orangeAccent, Colors.purpleAccent, Colors.tealAccent, Colors.pinkAccent,
  ];

  @override
  void initState() {
     super.initState();
     _currentMinDistance = widget.initialMinDistance;
     _currentColor = widget.initialColor;
     _currentStrokeWidth = widget.initialStrokeWidth;
  }

  @override
  Widget build(BuildContext context) {
     return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
           mainAxisSize: MainAxisSize.min, // Aby dopasować wysokość do zawartości
           crossAxisAlignment: CrossAxisAlignment.start,
           children: <Widget>[
              Text('Ustawienia Śledzenia Trasy', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),

              // 1. Minimalny Dystans
              Text('Min. dystans punktu: ${_currentMinDistance.toStringAsFixed(1)} m'),
              Slider(
                 value: _currentMinDistance,
                 min: 1.0,
                 max: 50.0, // Maksymalnie 50m
                 divisions: 49, // 49 przedziałów = kroki co 1m
                 label: '${_currentMinDistance.toStringAsFixed(1)} m',
                 onChanged: (value) {
                    setState(() => _currentMinDistance = value);
                 },
                 onChangeEnd: (value) { // Zapisz po zakończeniu przesuwania
                    widget.onSettingsChanged(value, _currentColor, _currentStrokeWidth);
                 },
              ),
              const SizedBox(height: 16),

              // 2. Kolor Śladu
              Text('Kolor śladu:'),
              const SizedBox(height: 8),
              Wrap(
                 spacing: 8.0,
                 children: _availableColors.map((color) {
                    return InkWell( // Użyj InkWell dla efektu tapnięcia
                      onTap: () {
                         setState(() => _currentColor = color);
                         widget.onSettingsChanged(_currentMinDistance, color, _currentStrokeWidth);
                      },
                      child: Container(
                         width: 30, height: 30,
                         decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentColor == color ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                              width: 2.5,
                            ),
                         ),
                      ),
                    );
                 }).toList(),
              ),
              const SizedBox(height: 16),

              // 3. Grubość Śladu
              Text('Grubość śladu: ${_currentStrokeWidth.toStringAsFixed(1)}'),
              Slider(
                 value: _currentStrokeWidth,
                 min: 1.0,
                 max: 10.0,
                 divisions: 9, // Kroki co 1.0
                 label: _currentStrokeWidth.toStringAsFixed(1),
                 onChanged: (value) {
                    setState(() => _currentStrokeWidth = value);
                 },
                 onChangeEnd: (value) {
                    widget.onSettingsChanged(_currentMinDistance, _currentColor, value);
                 },
              ),

              const SizedBox(height: 20), // Dolny margines
           ],
        ),
     );
  }
}
// -------------------------------------------------