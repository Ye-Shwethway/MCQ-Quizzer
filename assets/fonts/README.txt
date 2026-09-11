This folder is intended to hold the embedded TTF font used for PDF exports.

Please download a Noto Sans TTF (e.g., NotoSans-Regular.ttf) and place it here with the exact filename:

  assets/fonts/NotoSans-Regular.ttf

You can get it from Google Noto fonts: https://www.google.com/get/noto/ or from https://github.com/googlefonts/noto-fonts

After adding the file, run:

  flutter pub get

Then rebuild the app. The ExportService will use this embedded font to render PDFs with broad Unicode support.