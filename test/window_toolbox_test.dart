import 'package:test/test.dart';
import 'package:window_toolbox/src/win32_util.dart';

void main() {
  test('Parse and make negative LPARAM X', () {
    final lparam = 0x3BFF775;
    final (x, y) = splitLParam(lparam);
    expect(x, equals(-2187));
    expect(y, equals(959));

    final madeLParam = makeLParam(x, y);
    expect(madeLParam, equals(lparam));
  });
  test('Parse and make negative LPARAM Y', () {
    final lparam = 0xF77503BF;
    final (x, y) = splitLParam(lparam);
    expect(x, equals(959));
    expect(y, equals(-2187));

    final madeLParam = makeLParam(x, y);
    expect(madeLParam & 0xFFFFFFFF, equals(lparam & 0xFFFFFFFF));
  });
}
