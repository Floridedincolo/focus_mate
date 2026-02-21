# 🔒 Accessibility Service - Ghid de Utilizare

## ✅ Ce am implementat?

Am adăugat un sistem **complet automat** pentru verificarea și activarea Accessibility Service-ului în FocusMate, astfel încât blocarea aplicațiilor să funcționeze perfect.

---

## 📋 Funcționalități implementate

### 1️⃣ **Verificare automată la pornire**
- Aplicația verifică automat dacă Accessibility Service e activ când pornește
- Se afișează un mesaj în consolă: `✅ Accessibility Service este ACTIV` sau `⚠️ NU este activ`

### 2️⃣ **Banner prietenos în FocusPage**
- Dacă serviciul NU e activ, apare un banner **portocaliu** vizibil
- Butonul **"Activează"** deschide automat setările de Accessibility
- După activare, banner-ul dispare automat

### 3️⃣ **Persistent între restarts**
- Odată activat de utilizator, serviciul **rămâne activ permanent**
- Funcționează chiar și după restart telefon
- Nu mai e nevoie să activezi serviciul de fiecare dată

---

## 🛠️ Cum funcționează?

### **A. Kotlin (Android)**
Am adăugat în `MainActivity.kt`:

```kotlin
// ✅ Verifică dacă serviciul e activ
private fun isAccessibilityServiceEnabled(serviceClass: Class<out AccessibilityService>): Boolean {
    val enabledServices = Settings.Secure.getString(
        contentResolver,
        Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
    )
    val serviceId = "${packageName}/${serviceClass.name}"
    return enabledServices?.contains(serviceId) == true
}

// ✅ Deschide setările de Accessibility
private fun promptEnableAccessibility() {
    Toast.makeText(this, "Activează FocusMate Accessibility", Toast.LENGTH_LONG).show()
    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
    })
}
```

### **B. MethodChannel pentru Flutter**
```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "focus_mate/accessibility")
    .setMethodCallHandler { call, result ->
        when(call.method) {
            "checkAccessibility" -> {
                val enabled = isAccessibilityServiceEnabled(AppBlockService::class.java)
                result.success(enabled)
            }
            "promptAccessibility" -> {
                promptEnableAccessibility()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
```

### **C. Serviciu Flutter**
Am creat `lib/services/accessibility_service.dart`:

```dart
class AccessibilityService {
  static const MethodChannel _channel = MethodChannel('focus_mate/accessibility');

  // Verifică dacă e activ
  static Future<bool> isEnabled() async {
    final bool enabled = await _channel.invokeMethod('checkAccessibility');
    return enabled;
  }

  // Deschide setările
  static Future<void> promptEnable() async {
    await _channel.invokeMethod('promptAccessibility');
  }
}
```

### **D. UI în FocusPage**
Banner care apare automat când serviciul NU e activ:

```dart
if (!_isAccessibilityEnabled)
  Container(
    // Banner portocaliu cu buton "Activează"
    child: ElevatedButton(
      onPressed: () async {
        await AccessibilityService.promptEnable();
        await Future.delayed(const Duration(seconds: 2));
        _checkAccessibilityService(); // Re-verifică
      },
      child: Text("Activează"),
    ),
  ),
```

---

## 🚀 Cum se folosește?

### **Prima dată (setup inițial)**
1. Deschide aplicația FocusMate
2. Mergi la **Focus Mode**
3. Vei vedea banner-ul portocaliu: **"Service inactiv"**
4. Apasă butonul **"Activează"**
5. Se deschid setările → bifează **"FocusMate"** în lista de Accessibility Services
6. Revino în aplicație → banner-ul dispare! ✅

### **După ce e activat**
- Serviciul rămâne activ **permanent**
- Aplicațiile blocate vor fi blocate automat
- Nu mai trebuie să faci nimic manual
- Funcționează chiar și după restart

---

## 📱 Flow-ul utilizatorului

```
┌─────────────────────────────────────────┐
│  1. Lansează aplicația                  │
│     → Verificare automată în fundal     │
└──────────────────┬──────────────────────┘
                   │
         ┌─────────▼─────────┐
         │ Service activ?    │
         └─────────┬─────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
    ✅ DA                  ❌ NU
        │                     │
        │              ┌──────▼──────────────┐
        │              │ Banner "Activează"  │
        │              │ apare în FocusPage  │
        │              └──────┬──────────────┘
        │                     │
        │              ┌──────▼──────────────┐
        │              │ User apasă buton    │
        │              │ → Se deschid setări │
        │              └──────┬──────────────┘
        │                     │
        │              ┌──────▼──────────────┐
        │              │ User bifează odată  │
        │              │ "FocusMate"         │
        │              └──────┬──────────────┘
        │                     │
        └─────────────────────┘
                   │
         ┌─────────▼─────────┐
         │ ✅ Serviciu activ │
         │ PERMANENT         │
         └───────────────────┘
```

---

## 🔍 Cum verifici manual?

### În Flutter (consolă):
```
✅ Accessibility Service este ACTIV și funcțional!
```

### În Android (logcat):
```
D/AppAccessibilityService: 📋 Loaded 3 blocked apps from SharedPreferences
D/AppAccessibilityService:   - Blocked: com.google.android.youtube
D/AppAccessibilityService:   - Blocked: com.android.chrome
```

---

## 🐛 Debugging

### Dacă serviciul nu se activează:
1. Verifică în **Setări → Accessibility** dacă "FocusMate" apare în listă
2. Asigură-te că switch-ul e pe **ON**
3. Restartează aplicația Flutter

### Dacă aplicațiile nu se blochează:
1. Verifică că serviciul e activ: `AccessibilityService.isEnabled()`
2. Verifică că lista de aplicații blocate e trimisă: `BlockAppManager.setBlockedApps()`
3. Privește logcat pentru mesaje de la `AppAccessibilityService`

---

## ✨ Rezultat final

✅ **Prima dată**: User bifează serviciul o **singură dată** în setări  
✅ **După aceea**: Totul funcționează **automat și permanent**  
✅ **Fără intervenție**: Serviciul rămâne activ chiar și după **restart**  
✅ **UI prietenos**: Banner clar cu instrucțiuni simple  

---

## 📝 Fișiere modificate

- ✅ `android/app/src/main/kotlin/com/example/focus_mate/MainActivity.kt` → Verificare + MethodChannel
- ✅ `lib/services/accessibility_service.dart` → Serviciu Flutter nou
- ✅ `lib/main.dart` → Verificare la pornire
- ✅ `lib/pages/focus_page.dart` → Banner UI + verificare

---

🎉 **Gata! Acum ai un sistem complet funcțional pentru Accessibility Service!**

