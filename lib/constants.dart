import 'package:flutter/material.dart';

List<List<String>> sweetSayings = [
  ["Your presence,", "lights up the whole room"],
  ["We admire", "Your strong personality."],
  ["We’ll help you", "In any way we can,"],
  ["You are Strong", "and courageous"]
];

List<String> articleTitle = [
  "Pakistani women are inspiring country",
  "We have to end Violance",
  "Be a change",
  "You are strong"
];
List<String> imageSliders = [
  "https://media.istockphoto.com/photos/silhouette-of-super-strong-successful-businesswoman-picture-id1249879109?k=20&m=1249879109&s=612x612&w=0&h=I-joEMjqkq1wCJZJeLWUCd1d2HcB5WxBShdkA9YM0cg=",
  "https://media.istockphoto.com/vectors/young-woman-looks-at-the-mirror-and-sees-her-happy-reflection-vector-id1278815846?k=20&m=1278815846&s=612x612&w=0&h=JUTmV9Of-_ILOfXBfV9Cmp_41yuTliSdFIcZy5LKuss=",
  "https://media.istockphoto.com/vectors/mental-health-or-psychology-concept-with-flowering-human-head-vector-id1268669581?k=20&m=1268669581&s=612x612&w=0&h=YVLTKCZXKugEn40aqOkir4vcoFeTUAQToa1i3AFYRNU=",
  "https://media.istockphoto.com/photos/confidence-and-strength-concept-picture-id1086700012?k=20&m=1086700012&s=612x612&w=0&h=1wWVN3AB7BH7o3y2A2b-NG3HB9H6Dwkc9OLz2lxgwAY=",
];

List<List<String>> articles = [
  [
    """In Fiji and Tanzania, women market vendors came together to change the culture of their workplace which is the market.
When Varanisese Maisamoa joined the Rakiraki market in Fiji in 2007, she immediately noticed the way that the women market vendors were struggling every day. There was no security, little water supply and not enough lighting.

“I realized that they had been in this situation for 15, 20 years or more, and nobody had ever listened to their plea,” Maisamoa says. 

In the Mchikichini market in Dar es Salaam, Tanzania, Betty Mtehemu learned that many women were suffering in silence, unable to speak up to protect themselves and their community, some even leaving the industry due to the gender-based violence.

“I found that everyone was minding their own business, no one helped you when you faced acts of gender-based violence,” says Mtehemu, a market vendor and Chair of the National Women’s Association for Informal Market Traders.  “Women would sell their food and not get paid, they were abused by men, and everyone was quiet! There were no measures against gender-based violence.”

But with awareness sessions on the prevention of sexual harassment, domestic abuse and economic violence and support and legal advice from the local organization Equality for Growth, a grantee of the UN Trust Fund to End Violence against Women, managed by UN Women, there’s been a shift.""",
    """

“It is very important for us women to work with each other,” says Mtehemu. “When we can all speak in a single voice together as women, especially about the challenges faced by a woman, we can face those challenges as a team”.

Now, the women vendors know what options they have when they are faced with gender-based violence. They formed Women Unions in the market, with committees within each union, and they know how to report and monitor incidents of violence.

In Fiji, after Maisamoa attended leadership and financial literacy workshops, she formed the Rakiraki Market Vendors Association.  The workshops were part of UN Women’s Markets for Change project, funded by the Government of Australia and implemented in partnership with UNDP.

When the market was damaged by a devastating cyclone in 2016, Maisamoa and the Market Vendor’s Association contributed to making sure the reconstructed market will be cyclone-resilient, including a rain water harvesting system, flood-resistant drainage and a gender-responsive design.

“Today I am proud of what the association has achieved in terms of improving the safety of the women vendors’ working place. I’m looking forward to a market that is safer, better ventilated, with facilities such as changing areas for babies, improved toilets and a female market security attendant,” Maisamoa says.
"""
  ]
];

class AppColors {
  static const Color primaryDark = Color(0xFF3A004D);
  static const Color primaryPurple = Color(0xFF8B4F67);
  static const Color softLavender = Color(0xFFAE4BB0);
  static const Color mutedBlushLavender = Color(0xFFD4B8D0);
  static const Color lightBackground = Color(0xFFF0E0EB);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color emergencyRed = Color(0xFFEF4444);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color textDark = Color(0xFF2B2230);
  static const Color mutedText = Color(0xFF6F6274);
  static const Color white = Color(0xFFFFFFFF);

  // Compatibility Mappings
  static const Color background = lightBackground;       
  static const Color secondarySurface = Color(0xFFEADBEC); 
  static const Color cardSurface = white;      
  static const Color primary = primaryDark;          
  static const Color accent = softLavender;           
  static const Color success = successGreen;          
  static const Color emergency = emergencyRed;        
  static const Color warning = warningOrange;          
  static const Color muted = mutedText;            
  static const Color secondary = primaryPurple;        
  static const Color lightAccent = softLavender;      

  // Glassmorphic Decoration helper
  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color? color,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(0.35),
      borderRadius: borderRadius ?? BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withOpacity(0.4),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}


