import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

int _brandIconSeq = 0;

String _nextBrandId(String prefix) => '${prefix}_${_brandIconSeq++}';

/// Official Instagram app mark with brand gradient.
class InstagramBrandIcon extends StatelessWidget {
  const InstagramBrandIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final gid = _nextBrandId('ig');
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <defs>
    <radialGradient id="$gid" cx="30%" cy="107%" r="150%">
      <stop offset="0%" stop-color="#fdf497"/>
      <stop offset="5%" stop-color="#fdf497"/>
      <stop offset="45%" stop-color="#fd5949"/>
      <stop offset="60%" stop-color="#d6249f"/>
      <stop offset="90%" stop-color="#285AEB"/>
    </radialGradient>
  </defs>
  <rect width="24" height="24" rx="6" fill="url(#$gid)"/>
  <rect x="3.6" y="3.6" width="16.8" height="16.8" rx="4.4" fill="none" stroke="#fff" stroke-width="1.8"/>
  <circle cx="12" cy="12" r="4.2" fill="none" stroke="#fff" stroke-width="1.8"/>
  <circle cx="17.2" cy="6.8" r="1.15" fill="#fff"/>
</svg>
''';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Official Messenger glyph with brand gradient.
class MessengerBrandIcon extends StatelessWidget {
  const MessengerBrandIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final gid = _nextBrandId('msg');
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <defs>
    <linearGradient id="$gid" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#00B2FF"/>
      <stop offset="50%" stop-color="#006AFF"/>
      <stop offset="100%" stop-color="#A033FF"/>
    </linearGradient>
  </defs>
  <path fill="url(#$gid)" d="M12 2C6.36 2 2 6.13 2 11.7c0 2.91 1.19 5.44 3.14 7.19.16.15.26.35.27.57l.05 1.78a.8.8 0 0 0 1.12.71l1.99-.88c.17-.07.35-.09.53-.04.91.25 1.88.38 2.9.38 5.64 0 10-4.13 10-9.71S17.64 2 12 2zm6 7.46-2.94 4.66a1.5 1.5 0 0 1-2.17.4l-2.34-1.75a.6.6 0 0 0-.72 0l-3.16 2.4c-.42.32-.97-.18-.69-.63l2.94-4.66a1.5 1.5 0 0 1 2.17-.4l2.34 1.75c.21.16.51.16.72 0l3.16-2.4c.42-.32.97.18.69.63z"/>
</svg>
''';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Channel brand mark for inbox / timeline surfaces.
Widget socialChannelBrandIcon(String channel, {double size = 16}) {
  switch (channel) {
    case 'instagram':
      return InstagramBrandIcon(size: size);
    case 'messenger':
      return MessengerBrandIcon(size: size);
    case 'whatsapp':
      return Image.asset(
        'assets/images/whatsapp_logo.png',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          Icons.chat,
          size: size,
          color: const Color(0xFF25D366),
        ),
      );
    default:
      return Icon(Icons.forum_outlined, size: size);
  }
}
