#!/bin/bash

# 1. 빌드 준비
echo "🚀 안드로이드 빌드 및 배포를 시작합니다..."

# 2. pubspec.yaml에서 버전 추출 (예: 1.0.0+1 -> 1.0.0)
VERSION=$(grep 'version: ' pubspec.yaml | sed 's/version: //' | cut -d '+' -f 1 | xargs)
DATE=$(date +%Y%m%d)
FILENAME="Macmahon_v${VERSION}_${DATE}.apk"

echo "📍 버전: $VERSION"
echo "📅 날짜: $DATE"
echo "📦 파일명: $FILENAME"

# 3. 플러터 APK 빌드
flutter build apk --release

if [ $? -ne 0 ]; then
    echo "❌ 빌드에 실패했습니다."
    exit 1
fi

# 4. 결과물 경로 설정
SOURCE_APK="build/app/outputs/flutter-apk/app-release.apk"
ONEDRIVE_PATH="/Users/jae_hak/Library/CloudStorage/OneDrive-개인/Macmahon_system"
GDRIVE_PATH="/Users/jae_hak/Library/CloudStorage/GoogleDrive-vulcanus1981@gmail.com/내 드라이브/Macmahon_systeom"

# 5. 폴더 생성 및 복사
# 클라우드 경로에 폴더가 없을 경우 생성 (이미 있으면 무시)
mkdir -p "$ONEDRIVE_PATH" 2>/dev/null
mkdir -p "$GDRIVE_PATH" 2>/dev/null

cp "$SOURCE_APK" "$ONEDRIVE_PATH/$FILENAME"
cp "$SOURCE_APK" "$GDRIVE_PATH/$FILENAME"

echo "✨ 배포가 완료되었습니다!"
echo "📂 OneDrive: $ONEDRIVE_PATH/$FILENAME"
echo "📂 GoogleDrive: $GDRIVE_PATH/$FILENAME"
