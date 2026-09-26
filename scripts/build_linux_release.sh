#!/usr/bin/env bash

# Gera somente o pacote Linux distribuível. Não cria APK nem executa build
# Android. O .tar.gz contém a pasta bundle completa, pronta para extrair.
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(sed -n 's/^version: \([^+[:space:]]*\).*/\1/p' "$project_root/pubspec.yaml" | head -n 1)"
version="${version:-dev}"
output_dir="$project_root/dist"
bundle_dir="$project_root/build/linux/x64/release/bundle"
archive="$output_dir/curujao-estudos-linux-x64-$version.tar.gz"

cd "$project_root"
for command in cmake ninja pkg-config clang++; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Dependência ausente: %s\n' "$command" >&2
    printf 'No Ubuntu/Debian, instale com:\n' >&2
    printf '  sudo apt-get install -y cmake ninja-build pkg-config libgtk-3-dev clang\n' >&2
    exit 1
  fi
done

flutter pub get
flutter build linux --release

mkdir -p "$output_dir"
rm -f "$archive"
tar -C "$(dirname "$bundle_dir")" -czf "$archive" "$(basename "$bundle_dir")"

printf 'Pacote Linux criado: %s\n' "$archive"
