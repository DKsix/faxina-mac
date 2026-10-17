#!/bin/zsh
# Compila a Faxina.app (precisa só das Ferramentas de Linha de Comando: xcode-select --install)
#   ./build.sh            compila em build/Faxina.app
#   ./build.sh instalar   compila e copia pra /Applications
#   ./build.sh zip        compila e gera build/Faxina.zip (pra publicar numa release)
set -e
cd "${0:A:h}"
VERSAO="1.0"
APP="build/Faxina.app"
TMP="build/tmp"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$TMP/AppIcon.iconset"

# universal: roda em Mac com chip Apple e em Mac Intel
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library -target "$arch-apple-macos13.0" \
    Sources/*.swift -o "$TMP/Faxina-$arch"
done
lipo -create "$TMP"/Faxina-* -output "$APP/Contents/MacOS/Faxina"

swiftc -O -swift-version 5 Ferramentas/icone.swift -o "$TMP/icone"
"$TMP/icone" "$TMP/AppIcon.iconset"
iconutil -c icns "$TMP/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>Faxina</string>
  <key>CFBundleIdentifier</key><string>com.eduardomoraes.faxina</string>
  <key>CFBundleName</key><string>Faxina</string>
  <key>CFBundleDisplayName</key><string>Faxina</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSAO</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>pt-BR</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>A Faxina pede ao Finder pra esvaziar a Lixeira quando você manda.</string>
</dict></plist>
EOF

codesign --force --sign - "$APP"
rm -rf "$TMP"
print -r -- "✓ $APP"

if [[ $1 == zip ]]; then
  ditto -c -k --keepParent "$APP" build/Faxina.zip
  shasum -a 256 build/Faxina.zip | tee build/Faxina.zip.sha256
fi

if [[ $1 == instalar ]]; then
  pkill -x Faxina 2>/dev/null || true
  rm -rf /Applications/Faxina.app
  ditto "$APP" /Applications/Faxina.app
  print -r -- "✓ instalada em /Applications/Faxina.app"
fi
