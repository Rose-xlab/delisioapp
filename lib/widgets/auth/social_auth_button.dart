

import 'package:flutter/material.dart';

class SocialAuthButton extends StatelessWidget {
    // ignore: prefer_typing_uninitialized_variables
    final onTap;
    final String image;


    const SocialAuthButton({
      super.key,
      required this.onTap,
      required this.image,
      });


    @override
    Widget build(BuildContext context) {
      return SizedBox(
        height: 60,
        width: 60,
        child: Card(
          color: Colors.white, 
          child:InkWell(
            onTap:onTap,
            child: Image.asset(image),
          )
          ),
      );
    }

}