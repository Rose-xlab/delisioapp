// lib/screens/auth/login_screen.dart
import 'package:kitchenassistant/widgets/auth/social_auth_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/auth/auth_form.dart';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  //supabase instance
  final supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  String? _userId;
  Session? _session;


 @override
 void initState(){
   super.initState();

   supabase.auth.onAuthStateChange.listen((data){
     debugPrint(data.toString());




     setState(() {
       _userId = data.session?.user.id;
       _session = data.session;

     });
   });
 }

  


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  Future<AuthResponse> signInWithGoogle() async {

  const webClientId = '601707002682-2gna6etmp9k6jak25v5m7n3mrar683t4.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: webClientId,
  );

  final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
  if (googleUser == null) {
    throw Exception('Sign in aborted by user');
  }
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
  final idToken = googleAuth.idToken;
  if (idToken == null) {
    throw Exception('No ID Token found.');
  }

  final accessToken = googleAuth.accessToken;
  if(accessToken == null){
    throw Exception('No ACCESS TOKEN found');
  }
  // Authenticate with Supabase using the ID token
  final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
    provider:OAuthProvider.google,
    idToken: idToken,
    accessToken: accessToken
  );
  return response;
}



//////////////// FACEBOOK LOGIN //////////////

  Future<void> signInWithFacebook() async {
     try{
       final LoginResult result = await FacebookAuth.instance.login(); // by default we request the email and the public profile
      // or FacebookAuth.i.login()
      if (result.status == LoginStatus.success) {
          // you are logged
          final AccessToken accessToken = result.accessToken!;
           debugPrint("====================TOKEN:$accessToken");
      } else {
          debugPrint(result.status.toString());
          debugPrint(result.message);
      }
     }
     catch(e){
        debugPrint(e.toString());
     }
  }




  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Provider.of<AuthProvider>(context, listen: false).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    //get screen width
   final screenWidth = MediaQuery.sizeOf(context).width;

   if(_userId != null){
     Navigator.of(context).pushReplacementNamed('/main');
   }


    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24,horizontal: screenWidth > 600 ? 100 : 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userId ??  'Login to continue your cooking journey',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  AuthForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    isLogin: true,
                    onSubmit: _login,
                    isLoading: _isLoading,
                    errorMessage: _errorMessage,
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/signup');
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),

                  ////divider
            
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(

                        flex: 1,
                        child: Divider(thickness: 1,color: Colors.grey[300]),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text("or continue with",style: TextStyle(color: Colors.grey[500]),),
                        ),
                      Expanded(
                        flex: 1,
                        child:Divider(thickness: 1,color: Colors.grey[300],)
                        )
                      
                    ],
                  ),

                  const SizedBox(height: 10,),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social one");
                          var res = signInWithGoogle();
                          debugPrint("============================== ${res.toString()}");
                        },
                        image: "assets/google_logo.png",
                      ),
                      const SizedBox(width: 10,),
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social two");
                          signInWithFacebook();
                        },
                        image: "assets/facebook_logo.png",
                      ),

                      const SizedBox(width: 10,),
                      SocialAuthButton(
                        onTap: (){
                          debugPrint("Social three");
                        },
                        image: "assets/apple_logo.png",
                      ),
                    ],
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}