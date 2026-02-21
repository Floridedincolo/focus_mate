# 🚀 Quick Start - Accessibility Service

## Pentru Utilizatori

### Prima dată când deschizi aplicația:

1. **Deschide FocusMate** 📱
2. **Mergi la Focus Mode** 🎯
3. **Vei vedea un banner portocaliu** 🟠:
   ```
   ⚠️ Service inactiv
   Activează Accessibility pentru a bloca aplicațiile
   [Buton: Activează]
   ```
4. **Apasă butonul "Activează"** 🔘
5. **Se deschid setările Android** ⚙️
6. **Găsește "FocusMate" în listă** 📋
7. **Bifează switch-ul** ✅
8. **Revino în aplicație** ⬅️
9. **Banner-ul a dispărut!** 🎉
10. **Acum poți selecta aplicații de blocat** 🔒

### După prima activare:

✅ **Nu mai trebuie să faci nimic!**  
✅ **Serviciul rămâne activ permanent**  
✅ **Chiar și după restart telefon**  
✅ **Aplicațiile selectate se vor bloca automat**

---

## Pentru Developeri

### Setup rapid:

```bash
# 1. Verifică că toate fișierele există
ls lib/services/accessibility_service.dart  # ✅
ls android/app/src/main/kotlin/com/example/focus_mate/MainActivity.kt  # ✅

# 2. Build & Run
flutter clean
flutter pub get
flutter run

# 3. Verifică în consolă
# La pornire vei vedea:
✅ Accessibility Service este ACTIV și funcțional!
# sau
⚠️ Accessibility Service NU este activ!
```

### Debugging:

```dart
// În orice pagină Flutter:
import '../services/accessibility_service.dart';

// Verifică status:
bool isActive = await AccessibilityService.isEnabled();
print('Service is: ${isActive ? "ACTIVE ✅" : "INACTIVE ❌"}');

// Deschide setările manual:
await AccessibilityService.promptEnable();
```

### Verificare în logcat:

```bash
adb logcat | grep "AppAccessibilityService"

# Vei vedea:
D/AppAccessibilityService: 📋 Loaded 5 blocked apps from SharedPreferences
D/AppAccessibilityService:   - Blocked: com.google.android.youtube
D/AppAccessibilityService: Foreground app: com.google.android.youtube
D/AppAccessibilityService: 🚫 Blocked app detected → HOME + OVERLAY
```

---

## Testing Checklist

### ✅ Test 1: Prima pornire (serviciu inactiv)
- [ ] Deschide aplicația
- [ ] Mergi la Focus Mode
- [ ] Banner portocaliu apare? ✅
- [ ] Butonul "Activează" funcționează? ✅
- [ ] Setările se deschid? ✅

### ✅ Test 2: Activare serviciu
- [ ] Bifează "FocusMate" în Accessibility Settings
- [ ] Revino în aplicație
- [ ] Banner-ul dispare? ✅
- [ ] Poți selecta aplicații de blocat? ✅

### ✅ Test 3: Blocare aplicații
- [ ] Selectează YouTube (sau altă aplicație)
- [ ] Salvează lista
- [ ] Deschide aplicația blocată
- [ ] Se trimite la Home? ✅
- [ ] Overlay-ul apare? ✅

### ✅ Test 4: Persistent după restart
- [ ] Restart aplicație
- [ ] Banner-ul NU apare (serviciul e încă activ)? ✅
- [ ] Aplicațiile se blochează încă? ✅

### ✅ Test 5: Re-verificare
- [ ] Dezactivează serviciul manual din setări
- [ ] Revino în aplicație
- [ ] Banner-ul apare din nou? ✅
- [ ] Re-activează serviciul
- [ ] Banner-ul dispare? ✅

---

## Troubleshooting

### Problema: Banner-ul nu dispare după activare

**Soluție 1**: Așteaptă 2-3 secunde (re-verificare automată)  
**Soluție 2**: Ieși și intră din nou în Focus Mode  
**Soluție 3**: Restart complet aplicație

### Problema: Aplicațiile nu se blochează

**Verifică**:
1. Serviciul e activ? → `AccessibilityService.isEnabled()`
2. Lista e trimisă? → Vezi log-urile `✅ Saved X blocked apps`
3. Permisiuni OK? → Overlay + Accessibility

### Problema: Serviciul se dezactivează singur

**Cauze posibile**:
1. Battery optimization activă → Dezactivează pentru FocusMate
2. Force stop din setări → Evită
3. Clean master apps → Exclude FocusMate

---

## Features Preview

### 🎯 Focus Mode cu verificare automată
```
┌────────────────────────────────┐
│     Focus Mode                 │
│     Stay productive...         │
├────────────────────────────────┤
│ ⚠️ Service inactiv             │
│ Activează Accessibility        │
│ [Activează] ← Un click!        │
├────────────────────────────────┤
│     ⏱️ Timer                    │
│     25:00                      │
│     Ready?                     │
└────────────────────────────────┘
```

### ✅ După activare
```
┌────────────────────────────────┐
│     Focus Mode                 │
│     Stay productive...         │
├────────────────────────────────┤
│     ⏱️ Timer                    │
│     25:00                      │
│     Ready?                     │
├────────────────────────────────┤
│ 🔒 Blocking Active             │
│ YouTube, Chrome                │
│ [Switch: ON]                   │
└────────────────────────────────┘
```

---

## API Reference

### Flutter - AccessibilityService

```dart
import 'package:focus_mate/services/accessibility_service.dart';

// Check if service is enabled
bool isEnabled = await AccessibilityService.isEnabled();

// Open accessibility settings
await AccessibilityService.promptEnable();

// Check and prompt if needed (combo)
bool isActive = await AccessibilityService.checkAndPrompt();
```

### Kotlin - MainActivity

```kotlin
// Check service status
val isEnabled = isAccessibilityServiceEnabled(AppBlockService::class.java)

// Open settings
promptEnableAccessibility()
```

---

## 🎉 Success Indicators

✅ **Console log**: `✅ Accessibility Service este ACTIV`  
✅ **UI**: Banner NU apare  
✅ **Behavior**: Aplicațiile blocate se închid instant  
✅ **Persistent**: Funcționează după restart  

---

## 📝 Final Notes

- ✅ **One-time setup**: Utilizatorul activează o singură dată
- ✅ **Zero maintenance**: Funcționează automat după aceea
- ✅ **Clear UI**: Banner vizibil cu instrucțiuni clare
- ✅ **Developer friendly**: Cod curat, documentat, extensibil

**Perfect pentru licență! 🎓**

