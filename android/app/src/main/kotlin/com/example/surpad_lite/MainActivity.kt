package com.example.surpad_lite // Upewnij się, że nazwa pakietu jest zgodna

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.location.OnNmeaMessageListener // Zmieniony import
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler

class MainActivity: FlutterActivity() {
    // Zmieniamy nazwę kanału, żeby było jasne, że teraz wysyła NMEA
    private val NMEA_CHANNEL_NAME = "com.example.surpad_lite/nmea"
    private var nmeaEventChannel: EventChannel? = null
    private var nmeaMessageHandler: NmeaMessageHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d("MainActivity", "Configuring Flutter Engine and setting up NMEA EventChannel")

        nmeaMessageHandler = NmeaMessageHandler(this) // Utwórz nowy handler
        nmeaEventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, NMEA_CHANNEL_NAME)
        nmeaEventChannel!!.setStreamHandler(nmeaMessageHandler) // Ustaw handler dla kanału
    }

    override fun onDestroy() {
        Log.d("MainActivity", "onDestroy called, cleaning up NMEA EventChannel")
        nmeaEventChannel?.setStreamHandler(null)
        nmeaMessageHandler?.stopListening() // Zatrzymaj nasłuch NMEA
        nmeaMessageHandler = null
        nmeaEventChannel = null
        super.onDestroy()
    }
}

// Klasa obsługująca strumień wiadomości NMEA
class NmeaMessageHandler(private val context: Context) : StreamHandler {

    private var locationManager: LocationManager? = null
    private var nmeaListener: OnNmeaMessageListener? = null // Zmieniony typ listenera
    private var eventSink: EventSink? = null
    // Handler do uruchamiania listenera w głównym wątku (zalecane dla LocationManager)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListen(arguments: Any?, events: EventSink?) {
        Log.d("NmeaMessageHandler", "onListen called")
        this.eventSink = events
        locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        startListening()
    }

    override fun onCancel(arguments: Any?) {
        Log.d("NmeaMessageHandler", "onCancel called")
        stopListening()
        this.eventSink = null
    }

    fun stopListening() {
        Log.d("NmeaMessageHandler", "stopListening called")
        if (locationManager != null && nmeaListener != null) {
            locationManager!!.removeNmeaListener(nmeaListener!!)
            Log.d("NmeaMessageHandler", "NMEA listener removed")
        }
        nmeaListener = null
        // locationManager = null // Możemy go zostawić, jeśli jest potrzebny
    }

    private fun startListening() {
        Log.d("NmeaMessageHandler", "startListening called")
        // --- Sprawdzanie uprawnień ---
        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w("NmeaMessageHandler", "ACCESS_FINE_LOCATION permission not granted!")
            eventSink?.error("PERMISSION_DENIED", "ACCESS_FINE_LOCATION permission is required.", null)
            return
        }

        // Sprawdź, czy dostawca GPS jest włączony
        if (!locationManager!!.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
            Log.w("NmeaMessageHandler", "GPS Provider is disabled!")
            eventSink?.error("GPS_DISABLED", "GPS provider is disabled in system settings.", null)
            // return // Zwykle chcemy kontynuować, bo inne systemy mogą działać
        }

        // --- Rejestracja Listenera NMEA ---
        Log.d("NmeaMessageHandler", "Registering NMEA Listener...")
        nmeaListener = OnNmeaMessageListener { message, timestamp ->
            // Otrzymano wiadomość NMEA
            // Log.v("NmeaListener", "NMEA Received: [$timestamp] $message") // Log Verbose - może być dużo danych

            // Przygotuj dane do wysłania do Fluttera
            val nmeaData = mapOf(
                "timestamp" to timestamp,
                "message" to message
            )
            // Wyślij dane do Fluttera (upewnij się, że robisz to w głównym wątku, jeśli eventSink tego wymaga)
             mainHandler.post { // Używamy handlera wątku głównego dla bezpieczeństwa z EventSink
                 try {
                    eventSink?.success(nmeaData)
                 } catch (e: Exception) {
                    // Czasami EventSink może rzucić wyjątek, jeśli Flutter się rozłączył
                    Log.e("NmeaMessageHandler", "Error sending NMEA data to Flutter: ${e.message}")
                 }
             }
        }

        // Zarejestruj listener w systemie, używając Handler'a wątku głównego
         try {
            val success = locationManager!!.addNmeaListener(nmeaListener!!, mainHandler)
             if(success) {
                 Log.i("NmeaMessageHandler", "NMEA Listener registered successfully.")
             } else {
                  Log.e("NmeaMessageHandler", "Failed to register NMEA Listener (returned false).")
                  eventSink?.error("REGISTRATION_FAILED", "Failed to register NMEA Listener with LocationManager.", null)
             }
         } catch (e: SecurityException) {
             Log.e("NmeaMessageHandler", "SecurityException on registering NMEA listener: ${e.message}", e)
             eventSink?.error("PERMISSION_DENIED", "SecurityException: ACCESS_FINE_LOCATION might be missing or revoked.", e.message)
         } catch (e: Exception) {
              Log.e("NmeaMessageHandler", "Exception on registering NMEA listener: ${e.message}", e)
              eventSink?.error("UNKNOWN_ERROR", "An unexpected error occurred during NMEA listener registration.", e.message)
         }
    }
}