import 'package:monet_studio/padding.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum BrandColors {
  white,
  black,
  gray,
  starbucksGreen,
  cocaColaRed,
  mcdonaldsYellow,
  tiffanyBlue,
  facebookBlue,
  googleBlue,
  googleRed,
  googleYellow,
  googleGreen,
  microsoftBlue,
  microsoftRed,
  microsoftGreen,
  microsoftYellow,
  appleBlack,
  appleGray,
  netflixRed,
  spotifyGreen,
  instagramPink,
  slackPurple,
  amazonOrange,
  ibmBlue,
  linkedinBlue,
  youtubeRed,
  discordBlurple,
  notionBlack,
  johnDeereGreen,
  cadburyPurple,
  barbiePink,
  telosnexBlue;

  String get name {
    switch (this) {
      case BrandColors.white:
        return 'White';
      case BrandColors.black:
        return 'Black';
      case BrandColors.gray:
        return 'Gray';
      case BrandColors.starbucksGreen:
        return 'Starbucks Green';
      case BrandColors.cocaColaRed:
        return 'Coca-Cola Red';
      case BrandColors.mcdonaldsYellow:
        return 'McDonald\'s Yellow';
      case BrandColors.tiffanyBlue:
        return 'Tiffany Blue';
      case BrandColors.facebookBlue:
        return 'Facebook Blue';
      case BrandColors.googleBlue:
        return 'Google Blue';
      case BrandColors.googleRed:
        return 'Google Red';
      case BrandColors.googleYellow:
        return 'Google Yellow';
      case BrandColors.googleGreen:
        return 'Google Green';
      case BrandColors.microsoftBlue:
        return 'Microsoft Blue';
      case BrandColors.microsoftRed:
        return 'Microsoft Red';
      case BrandColors.microsoftGreen:
        return 'Microsoft Green';
      case BrandColors.microsoftYellow:
        return 'Microsoft Yellow';
      case BrandColors.appleBlack:
        return 'Apple Black';
      case BrandColors.appleGray:
        return 'Apple Gray';
      case BrandColors.netflixRed:
        return 'Netflix Red';
      case BrandColors.spotifyGreen:
        return 'Spotify Green';
      case BrandColors.instagramPink:
        return 'Instagram Pink';
      case BrandColors.slackPurple:
        return 'Slack Purple';
      case BrandColors.amazonOrange:
        return 'Amazon Orange';
      case BrandColors.ibmBlue:
        return 'IBM Blue';
      case BrandColors.linkedinBlue:
        return 'LinkedIn Blue';
      case BrandColors.youtubeRed:
        return 'YouTube Red';
      case BrandColors.discordBlurple:
        return 'Discord Blurple';
      case BrandColors.notionBlack:
        return 'Notion Black';
      case BrandColors.johnDeereGreen:
        return 'John Deere Green';
      case BrandColors.cadburyPurple:
        return 'Cadbury Purple';
      case BrandColors.barbiePink:
        return 'Barbie Pink';
      case BrandColors.telosnexBlue:
        return 'Telosnex Blue';
    }
  }

  Color get color {
    switch (this) {
      case BrandColors.white:
        return const Color(0xffffffff);
      case BrandColors.black:
        return const Color(0xff000000);
      case BrandColors.gray:
        return const Color(0xff808080);
      case BrandColors.starbucksGreen:
        return const Color(0xff006241);
      case BrandColors.cocaColaRed:
        return const Color(0xfff40009);
      case BrandColors.mcdonaldsYellow:
        return const Color(0xffffc72c);
      case BrandColors.tiffanyBlue:
        return const Color(0xff0abab5);
      case BrandColors.facebookBlue:
        return const Color(0xff4267b2);
      case BrandColors.googleBlue:
        return const Color(0xff4285f4);
      case BrandColors.googleRed:
        return const Color(0xffea4335);
      case BrandColors.googleYellow:
        return const Color(0xfffbbc05);
      case BrandColors.googleGreen:
        return const Color(0xff34a853);
      case BrandColors.microsoftBlue:
        return const Color(0xff00a4ef);
      case BrandColors.microsoftRed:
        return const Color(0xfff25022);
      case BrandColors.microsoftGreen:
        return const Color(0xff7fba00);
      case BrandColors.microsoftYellow:
        return const Color(0xffffb900);
      case BrandColors.appleBlack:
        return const Color(0xff1d1d1f);
      case BrandColors.appleGray:
        return const Color(0xff86868b);
      case BrandColors.netflixRed:
        return const Color(0xffe50914);
      case BrandColors.spotifyGreen:
        return const Color(0xff1db954);
      case BrandColors.instagramPink:
        return const Color(0xffe1306c);
      case BrandColors.slackPurple:
        return const Color(0xff4a154b);
      case BrandColors.amazonOrange:
        return const Color(0xffff9900);
      case BrandColors.ibmBlue:
        return const Color(0xff0f62fe);
      case BrandColors.linkedinBlue:
        return const Color(0xff0a66c2);
      case BrandColors.youtubeRed:
        return const Color(0xffff0000);
      case BrandColors.discordBlurple:
        return const Color(0xff5865f2);
      case BrandColors.notionBlack:
        return const Color(0xff191919);
      case BrandColors.johnDeereGreen:
        return const Color(0xff367c2b);
      case BrandColors.cadburyPurple:
        return const Color(0xff482683);
      case BrandColors.barbiePink:
        return const Color(0xffe0218a);
      case BrandColors.telosnexBlue:
        return const Color(0xff0066AA);
    }
  }
}

class BrandColorsPopupMenuButton extends HookConsumerWidget {
  final Function(Color) onChanged;
  const BrandColorsPopupMenuButton({super.key, required this.onChanged});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<BrandColors>(
      onSelected: (value) {},
      tooltip: 'Sample Colors',
      itemBuilder: (context) {
        return BrandColors.values.map((e) {
          return PopupMenuItem<BrandColors>(
            onTap: () => onChanged(e.color),
            value: e,
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: e.color,
                  ),
                  width: 16,
                  height: 16,
                ),
                const HorizontalPadding(),
                Text(
                  e.name,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          );
        }).toList();
      },
      icon: const Icon(Icons.palette),
    );
  }
}
