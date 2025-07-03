

import 'package:flutter/material.dart';

import 'package:crisp_chat/crisp_chat.dart';

class CrispChatPage extends StatefulWidget {
  const CrispChatPage({super.key});

  @override
  State<CrispChatPage> createState() => _CrispChatPageState();
}

class _CrispChatPageState extends State<CrispChatPage> {
  final String websiteID = "707afe1c-55ba-449d-9244-48b0fd1c3792"; // Replace with your actual Website ID
  late CrispConfig _crispConfig;

  @override
  void initState() {
    super.initState();

    // Optional: Configure Crisp User details
    final crispUser = User(
      email: "opegude.n3t@gmail.com",
      nickName: "John Mako",
      phone: "+22456789031",
      avatar: "https://img.icons8.com/?size=48&id=23308&format=png",
      company: Company(
        name: "Delisio Corp",
        url: "https://robertochurministries.org",
        companyDescription: "A sample company providing excellent services.",
        employment: Employment(title: "Lead Developer", role: "Software Engineer"),
        geoLocation: GeoLocation(city: "New York", country: "USA"),
      ),
    );

    // Initialize CrispConfig
    _crispConfig = CrispConfig(
      websiteID: websiteID,
      // tokenId: "your_user_token_id_optional",
      sessionSegment: "beta_testers",
      user: crispUser,
      enableNotifications: true,
    );

    // Optionally, set additional session data
    FlutterCrispChat.setSessionString(key: "custom_data_point", value: "some_important_value");
    FlutterCrispChat.setSessionInt(key: "user_score", value: 120);
    FlutterCrispChat.setSessionSegments(segments: ["registered_user", "newsletter_subscriber"], overwrite: false);
  }

  void _openChat() async {
    await FlutterCrispChat.openCrispChat(config: _crispConfig);
    String? sessionId = await FlutterCrispChat.getSessionIdentifier();
    if (sessionId != null) {
      print('Crisp Session ID: $sessionId');
    }
  }

  void _resetSession() async {
    await FlutterCrispChat.resetCrispChatSession();
    print('Crisp session has been reset.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crisp Chat Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: _openChat,
              child: const Text('Open Crisp Chat'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _resetSession,
              child: const Text('Reset Crisp Session'),
            ),
          ],
        ),
      ),
    );
  }
}
