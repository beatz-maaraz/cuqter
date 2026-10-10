
import 'package:share_plus/share_plus.dart';
void test(XFile file) {
  SharePlus.instance.share(ShareParams(text: '', files: [file]));
}
