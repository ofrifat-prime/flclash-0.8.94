import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/pages/editor.dart';
import 'package:flutter_monaco/flutter_monaco.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps editor languages to Monaco languages', () {
    expect(
      editorMonacoLanguageFor(const [Language.javaScript]),
      MonacoLanguage.javascript,
    );
    expect(editorMonacoLanguageFor(const [Language.json]), MonacoLanguage.json);
    expect(editorMonacoLanguageFor(const [Language.yaml]), MonacoLanguage.yaml);
    expect(editorMonacoLanguageFor(const []), MonacoLanguage.yaml);
  });

  test('builds Monaco options with current editor defaults', () {
    final options = editorMonacoOptions(
      language: MonacoLanguage.json,
      readOnly: true,
      fontSize: 15,
      fontFamily: 'JetBrainsMono',
    );

    expect(options.language, MonacoLanguage.json);
    expect(options.theme, MonacoTheme.vs);
    expect(options.readOnly, true);
    expect(options.fontSize, 15);
    expect(options.fontFamily, 'JetBrainsMono');
    expect(options.lineNumbers, true);
    expect(options.minimap, false);
    expect(options.wordWrap, true);
    expect(options.scrollBeyondLastLine, false);
  });
}
