#!/usr/bin/env bash
# Builds the Smart Rakat Counter APK and installs it on a Wear OS watch over ADB.
# Usage: ./install.sh [--tr] [--help] [ip:port]
set -euo pipefail

PKG=com.tamer.rekat
TR=0
ADDR=""

for arg in "$@"; do
  case "$arg" in
    --tr) TR=1 ;;
    -h|--help) HELP=1 ;;
    *:*) ADDR="$arg" ;;
    *) echo "Unknown argument / Bilinmeyen argüman: $arg" >&2; exit 2 ;;
  esac
done

# t "english" "türkçe" -> prints the one for the chosen language
t() { if [ "$TR" = 1 ]; then printf '%s\n' "$2"; else printf '%s\n' "$1"; fi; }
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$(t "$1" "$2")"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$(t "$1" "$2")" >&2; }
die() { printf '\033[1;31m%s\033[0m\n' "$(t "$1" "$2")" >&2; exit 1; }
ask() { # ask VAR "en prompt" "tr prompt"
  local _v
  read -r -p "$(t "$2" "$3") " _v || die "No input (stdin closed). Run in an interactive terminal." \
                                         "Girdi yok (stdin kapalı). Etkileşimli bir terminalde çalıştırın."
  printf -v "$1" '%s' "$_v"
}

if [ "${HELP:-0}" = 1 ]; then
  t "Usage: ./install.sh [--tr] [ip:port]

Builds the app and installs it on a Wear OS 3+ watch (Galaxy Watch4 or newer) via ADB.
  --tr       Turkish messages
  ip:port    Connect to this address first (adb connect), e.g. 192.168.1.42:37115
  --help     Show this help

Needs: adb, Java 17+, Android SDK (ANDROID_HOME or local.properties)." \
"Kullanım: ./install.sh [--tr] [ip:port]

Uygulamayı derler ve ADB ile Wear OS 3+ saate (Galaxy Watch4 ve sonrası) kurar.
  --tr       Türkçe mesajlar
  ip:port    Önce bu adrese bağlan (adb connect), ör. 192.168.1.42:37115
  --help     Bu yardımı göster

Gerekenler: adb, Java 17+, Android SDK (ANDROID_HOME ya da local.properties)."
  exit 0
fi

cd "$(dirname "$0")"

# 1. adb + Android SDK
step "Checking adb" "adb kontrol ediliyor"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ]; then
  for d in "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do
    [ -d "$d" ] && SDK="$d" && break
  done
fi
ADB=$(command -v adb || true)
if [ -z "$ADB" ] && [ -n "$SDK" ] && [ -x "$SDK/platform-tools/adb" ]; then ADB="$SDK/platform-tools/adb"; fi
if [ -z "$ADB" ]; then
  die "adb not found. Install it:
  macOS: brew install --cask android-platform-tools
  Linux: sudo apt install adb   (or your distro's android-tools package)" \
      "adb bulunamadı. Kurun:
  macOS: brew install --cask android-platform-tools
  Linux: sudo apt install adb   (ya da dağıtımınızın android-tools paketi)"
fi
echo "$ADB"

# 2. Java 17+ and SDK for Gradle
step "Checking Java and Android SDK" "Java ve Android SDK kontrol ediliyor"
if [ -z "${JAVA_HOME:-}" ] && [ "$(uname)" = Darwin ]; then
  JAVA_HOME=$(/usr/libexec/java_home -v 17+ 2>/dev/null || true)
fi
[ -n "${JAVA_HOME:-}" ] && export JAVA_HOME
JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
command -v "$JAVA" >/dev/null || die "Java not found. Install JDK 17+:
  macOS: brew install openjdk@17, then export JAVA_HOME=\$(/usr/libexec/java_home -v 17)
  Linux: sudo apt install openjdk-17-jdk" \
                                    "Java bulunamadı. JDK 17+ kurun:
  macOS: brew install openjdk@17, sonra export JAVA_HOME=\$(/usr/libexec/java_home -v 17)
  Linux: sudo apt install openjdk-17-jdk"
JV=$("$JAVA" -version 2>&1 | awk -F'"' '/version/{split($2,a,"."); print (a[1]=="1" ? a[2] : a[1]); exit}')
[ "${JV:-0}" -ge 17 ] 2>/dev/null || die "Java 17+ required, found: ${JV:-unknown}. Set JAVA_HOME to a JDK 17+." \
                                         "Java 17+ gerekli, bulunan: ${JV:-bilinmiyor}. JAVA_HOME'u JDK 17+ olarak ayarlayın."
echo "Java $JV"
if [ ! -f local.properties ]; then
  [ -n "$SDK" ] && [ -d "$SDK" ] || die "Android SDK not found. Set ANDROID_HOME or create local.properties with: sdk.dir=/path/to/Android/sdk
Building needs the full SDK, not only platform-tools: install Android Studio, or cmdline-tools and then
  sdkmanager \"platforms;android-34\" \"build-tools;34.0.0\" && sdkmanager --licenses" \
                                        "Android SDK bulunamadı. ANDROID_HOME'u ayarlayın ya da local.properties dosyasına şunu yazın: sdk.dir=/Android/sdk/yolu
Derleme için yalnız platform-tools yetmez, tam SDK gerekir: Android Studio'yu ya da cmdline-tools'u kurun, sonra
  sdkmanager \"platforms;android-34\" \"build-tools;34.0.0\" && sdkmanager --licenses"
  export ANDROID_HOME="$SDK"
fi

# 3. Build
step "Building APK (./gradlew assembleDebug)" "APK derleniyor (./gradlew assembleDebug)"
./gradlew assembleDebug
APK=$(/bin/ls build/outputs/apk/debug/*.apk 2>/dev/null | head -n1 || true)
[ -n "$APK" ] || die "APK not found under build/outputs/apk/debug." "build/outputs/apk/debug altında APK bulunamadı."
echo "$APK"

# 4. Watch connection
step "Looking for the watch" "Saat aranıyor"
[ -n "$ADDR" ] && { "$ADB" connect "$ADDR" || true; }
devices() { "$ADB" devices | awk 'NR>1 && $2=="device"{print $1}'; }
unauth() { # warn if a device is waiting for the USB/ADB debugging prompt on the watch
  [ -z "$("$ADB" devices | awk 'NR>1 && $2=="unauthorized"{print $1}')" ] ||
    warn "A device is 'unauthorized': accept the USB/ADB debugging prompt on the watch, then run again." \
         "Bir cihaz 'unauthorized' durumda: saatte çıkan USB/ADB hata ayıklama iznini onaylayın, sonra tekrar çalıştırın."
}
unauth

if [ -z "$(devices)" ]; then
  t "No watch connected. On the watch:
  1. Settings > About watch > Software information > tap 'Software version' 5-7 times in a row (Developer options).
  2. Settings > Developer options: turn on 'ADB debugging' and 'Wireless debugging'.
  3. Wireless debugging > 'Pair new device': note the ip:port and the pairing code.
  Watch and computer must be on the same Wi-Fi." \
"Bağlı saat yok. Saatte:
  1. Ayarlar > Saat hakkında > Yazılım bilgileri > 'Yazılım sürümü'ne art arda 5-7 kez dokunun (Geliştirici seçenekleri açılır).
  2. Ayarlar > Geliştirici seçenekleri: 'ADB hata ayıklama' ve 'Kablosuz hata ayıklama'yı açın.
  3. Kablosuz hata ayıklama > 'Yeni cihaz eşle': ekrandaki ip:port ve eşleme kodunu not edin.
  Saat ve bilgisayar aynı Wi-Fi ağında olmalı."
  ask PAIR_ADDR "Pairing ip:port (from 'Pair new device'):" "Eşleme ip:port ('Yeni cihaz eşle' ekranından):"
  ask PAIR_CODE "Pairing code:" "Eşleme kodu:"
  "$ADB" pair "$PAIR_ADDR" "$PAIR_CODE" || die "Pairing failed. Check the code and try again." "Eşleme başarısız. Kodu kontrol edip tekrar deneyin."
  sleep 3  # after pairing adb often connects by itself over mDNS
  if [ -z "$(devices)" ]; then
    ask CONN_ADDR "Now the ip:port on the main 'Wireless debugging' screen (not the pairing one):" \
                  "Şimdi 'Kablosuz hata ayıklama' ana ekranındaki ip:port (eşleme ekranındaki değil):"
    "$ADB" connect "$CONN_ADDR" || true
    sleep 1
  fi
  [ -n "$(devices)" ] || { unauth; die "Could not connect to the watch. Run again with: ./install.sh <ip:port>" \
                             "Saate bağlanılamadı. Tekrar deneyin: ./install.sh --tr <ip:port>"; }
fi

# Several devices: prefer the watch(es), ask if still ambiguous
ALL=(); while IFS= read -r d; do ALL+=("$d"); done < <(devices)  # no mapfile: macOS ships bash 3.2
[ "${#ALL[@]}" -gt 0 ] || die "No device connected." "Bağlı cihaz yok."
WATCHES=(); SEEN=" "
for d in "${ALL[@]}"; do
  "$ADB" -s "$d" shell getprop ro.build.characteristics 2>/dev/null | command grep -q watch || continue
  # the same watch can be listed twice (mDNS name and ip:port): keep one per ro.serialno
  s=$("$ADB" -s "$d" shell getprop ro.serialno 2>/dev/null | tr -d '\r' || true)
  case "$SEEN" in *" ${s:-$d} "*) continue ;; esac
  SEEN="$SEEN${s:-$d} "; WATCHES+=("$d")
done
[ "${#WATCHES[@]}" -gt 0 ] || WATCHES=("${ALL[@]}")
if [ "${#WATCHES[@]}" -eq 1 ]; then
  SERIAL="${WATCHES[0]}"
else
  for i in "${!WATCHES[@]}"; do echo "  $((i+1))) ${WATCHES[$i]}"; done
  ask N "Which device? (number):" "Hangi cihaz? (numara):"
  [[ "$N" =~ ^[0-9]+$ ]] && [ "$N" -ge 1 ] && [ "$N" -le "${#WATCHES[@]}" ] || die "Invalid choice." "Geçersiz seçim."
  SERIAL="${WATCHES[$((N-1))]}"
fi
echo "$SERIAL"

# 5. Install + permission
step "Installing on $SERIAL" "$SERIAL cihazına kuruluyor"
"$ADB" -s "$SERIAL" install -r "$APK" || die "Install failed. If an older build signed with another key is on the watch: adb -s $SERIAL uninstall $PKG" \
                                             "Kurulum başarısız. Saatte başka anahtarla imzalanmış eski bir sürüm varsa: adb -s $SERIAL uninstall $PKG"
"$ADB" -s "$SERIAL" shell pm grant "$PKG" android.permission.BODY_SENSORS 2>/dev/null \
  || warn "Could not grant BODY_SENSORS; the app will ask for it on first launch." \
          "BODY_SENSORS izni verilemedi; uygulama ilk açılışta isteyecek."

# 6. Done
step "Done" "Tamam"
t "Installed. Open 'Rakat Counter' from the watch's app list.
You can also add its tile: long-press the watch face's tiles area (or swipe left to the end) > Add tile." \
"Kuruldu. Saatin uygulama listesinden 'Rekat Sayacı'nı açın.
Kutucuğunu da ekleyebilirsiniz: kutucuklar arasında sona kaydırın (ya da bir kutucuğa basılı tutun) > Kutucuk ekle."
