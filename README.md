![image](https://github.com/user-attachments/assets/cfe02f0e-7abe-413b-af51-74d25a87abab)# Surpad Lite

A Flutter application designed as a 'lite' version inspired by surveying tools, focusing on displaying detailed GPS/GNSS information, mapping, track recording, and data visualization. Developed as a project for a Location Systems course.

The goal was to create a feature-rich app demonstrating various aspects of location services on Android, including platform channel usage for accessing raw NMEA data.

## Screenshots

*   *Ekran główny z mapą*
*   *Widok Sky Plot z filtrami*
![image](https://github.com/user-attachments/assets/7a052be1-1bd9-4764-856d-42d7021725e2)
*   *Wykres siły sygnału (SNR)*
  ![image](https://github.com/user-attachments/assets/05027c49-c3c0-4a71-b0cd-c5f68eca41d2)
*   *Wykres profilu wysokościowego*
  ![image](https://github.com/user-attachments/assets/92f1f3ad-f1f6-4b06-b1ca-018a5c5f8ed7)
*   *Karta danych lokalizacyjnych*
*   *Widok dużego kompasu*
![image](https://github.com/user-attachments/assets/954a6406-246f-48cc-be25-1de64bcf2dab)


## Funkcje

*   **Lokalizacja GPS/GNSS:**
    *   Wyświetlanie bieżącej pozycji (szerokość, długość, wysokość n.p.m.).
    *   Wyświetlanie dokładności poziomej i pionowej.
    *   Wyświetlanie prędkości, kursu (kierunku ruchu) oraz ich dokładności.
    *   Wyświetlanie czasu ostatniego fixa GPS.
*   **Mapa Online (OpenStreetMap):**
    *   Wyświetlanie pozycji użytkownika na mapie OSM.
    *   Automatyczne centrowanie i śledzenie pozycji.
    *   Przycisk do ręcznego centrowania mapy.
    *   **Cachowanie kafelków:** Kafelki mapy są cachowane, umożliwiając przeglądanie wcześniej załadowanych obszarów w trybie offline.
    *   Przycisk do czyszczenia cache mapy.
*   **Śledzenie Trasy:**
    *   Rysowanie przebytej trasy (śladu GPS) na mapie.
    *   Przyciski Start/Stop do nagrywania trasy.
    *   Przycisk do czyszczenia bieżącej trasy.
    *   Wyraźny wskaźnik wizualny podczas nagrywania trasy.
    *   Obliczanie i wyświetlanie:
        *   Dystansu przebytej trasy (metry/kilometry).
        *   Czasu trwania nagrywania.
        *   Średniej prędkości.
        *   Maksymalnej prędkości.
        *   Liczby zapisanych punktów trasy.
*   **Zarządzanie Trasami:**
    *   Zapisywanie bieżącej trasy w pamięci urządzenia (`shared_preferences`).
    *   Wyświetlanie listy zapisanych tras (data, dystans, liczba punktów).
    *   Możliwość usunięcia zapisanej trasy.
    *   **Eksport tras do GPX:** Możliwość eksportu bieżącej lub zapisanej trasy do standardowego formatu GPX za pomocą systemowego udostępniania.
*   **Dane GNSS (NMEA):**
    *   **Platform Channel:** Wykorzystanie kanału platformy do komunikacji z natywnym kodem Android (Kotlin) w celu odbierania surowych wiadomości NMEA.
    *   **Parsowanie NMEA:** Parsowanie komunikatów GSV, GGA i GSA.
    *   **Aktywne Systemy:** Wyświetlanie listy aktualnie odbieranych systemów GNSS (GPS, GLONASS, Galileo, BeiDou, etc.).
    *   **Jakość Fixa (GGA):** Wyświetlanie statusu fixa (np. Brak fixa, Fix autonomiczny, DGPS, RTK - jeśli dostępne).
    *   **Dane GSA:** Wyświetlanie liczby satelitów używanych w fixie oraz wartości PDOP, HDOP, VDOP.
*   **Wizualizacje GNSS:**
    *   **Sky Plot:** Graficzna reprezentacja widocznych satelitów na niebie:
        *   Pozycja (Azymut/Elewacja).
        *   System GNSS (różne kolory).
        *   Identyfikator satelity (SVID/PRN).
        *   Siła sygnału (SNR) wizualizowana rozmiarem/przezroczystością punktu.
        *   **Wyróżnienie satelitów używanych w fixie** (żółta obwódka).
        *   Możliwość filtrowania wyświetlanych systemów na Sky Plocie.
    *   **Wykres SNR:** Wykres liniowy pokazujący zmiany siły sygnału (SNR) w czasie dla 8 najsilniejszych satelitów.
    *   **Wykres Elewacji:** Wykres liniowy pokazujący profil wysokościowy zarejestrowanej (bieżącej) trasy.
*   **Kompas:**
    *   Integracja z kompasem urządzenia (`flutter_compass`).
    *   Tryb obracania mapy "Heading Up" (kierunek na górze) przełączany z trybem "North Up" (północ na górze).
    *   Inteligentne przełączanie między kierunkiem z GPS (podczas ruchu) a kierunkiem z kompasu (podczas postoju) dla płynnej rotacji.
    *   Duży, czytelny widget kompasu w osobnej karcie.
    *   Mały wskaźnik kompasu (zawsze wskazujący północ) nałożony na mapę.
*   **UI/UX:**
    *   Obsługa trybu jasnego i ciemnego (automatycznie na podstawie ustawień systemu).
    *   Interfejs oparty na kartach w przewijanej liście (`ListView`).
    *   Przyciski akcji przeniesione do `AppBar` dla lepszej widoczności.
    *   Panel ustawień (BottomSheet) do konfiguracji parametrów śledzenia (min. dystans, kolor, grubość linii).

## Technologie i Pakiety

*   **Framework:** Flutter (v3.x)
*   **Języki:** Dart, Kotlin (dla Platform Channel Android)
*   **Kluczowe Pakiety Flutter:**
    *   `geolocator`: Podstawowa lokalizacja.
    *   `permission_handler`: Zarządzanie uprawnieniami.
    *   `flutter_map`: Wyświetlanie mapy OpenStreetMap.
    *   `latlong2`: Reprezentacja współrzędnych geograficznych.
    *   `flutter_map_tile_caching`: Cachowanie kafelków mapy online.
    *   `flutter_compass`: Odczyt danych z kompasu.
    *   `fl_chart`: Rysowanie wykresów SNR i elewacji.
    *   `shared_preferences`: Zapisywanie tras i ustawień.
    *   `path_provider`: Uzyskiwanie ścieżek do zapisu plików/cache.
    *   `share_plus`: Udostępnianie plików GPX.
    *   `vector_math`: Obliczenia na wektorach/kątach (radiany).
*   **Natywny Kod Android:**
    *   `Platform Channel (EventChannel)`: Do przesyłania danych NMEA z Kotlina do Darta.
    *   `LocationManager`, `OnNmeaMessageListener`: Do nasłuchiwania wiadomości NMEA w systemie Android.

## Jak Uruchomić Projekt

1.  **Wymagania Wstępne:**
    *   Zainstalowany Flutter SDK (zalecana stabilna wersja).
    *   Skonfigurowane środowisko Android (Android Studio lub same narzędzia wiersza poleceń + Android SDK).
    *   Emulator Android lub fizyczne urządzenie z Androidem (API Level 21+ dla większości funkcji, API 24+ zalecane dla pełnej funkcjonalności NMEA).
    *   **Do testowania funkcji GPS/GNSS zalecane jest fizyczne urządzenie i testy na zewnątrz.**

2.  **Klonowanie Repozytorium:**
    ```bash
    git clone https://github.com/snakex21/Surpad-Lite
    cd surpad_lite
    ```

3.  **Pobranie Zależności:**
    ```bash
    flutter pub get
    ```

4.  **Uruchomienie Aplikacji:**
    *   Podłącz urządzenie lub uruchom emulator.
    *   Sprawdź ID urządzenia: `flutter devices`
    *   Uruchom aplikację, podając ID urządzenia (zastąp `c4f31150` swoim ID):
        ```bash
        flutter run -d c4f31150
        ```
        Lub po prostu:
        ```bash
        flutter run
        ```
        (jeśli masz tylko jedno podłączone urządzenie/emulator).
    *   Aplikacja poprosi o **uprawnienia do lokalizacji**. Należy je przyznać.
    *   Upewnij się, że **usługi lokalizacji (GPS)** są włączone w ustawieniach telefonu.

## Potencjalne Przyszłe Ulepszenia

*   Implementacja wczytywania map offline z plików MBTiles.
*   Możliwość importu plików GPX.
*   Bardziej zaawansowane statystyki trasy (suma podejść/zejść).
*   Dodawanie i zarządzanie punktami POI na mapie.
*   Bardziej rozbudowany ekran ustawień.
*   Poprawa dokładności okręgu dokładności na mapie.

## Licencja
MIT License
