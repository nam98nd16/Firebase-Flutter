import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
// Import the firebase_core plugin
// ignore: import_of_legacy_library_into_null_safe
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Set default `_initialized` and `_error` state to false
  bool _initialized = false;
  bool _error = false;
  late UserCredential userCredential;

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      // Wait for Firebase to initialize and set `_initialized` state to true
      await Firebase.initializeApp();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      // Set `_error` state to true if Firebase initialization fails
      print("err" + e.toString());
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void initState() {
    initializeFlutterFire();
    super.initState();
  }

  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser!.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _error
                ? Text(
                    'Something went wrong',
                  )
                : !_initialized
                    ? Text("Loading")
                    : TextButton(
                        onPressed: () async {
                          userCredential = await signInWithGoogle();
                          print("user" + userCredential.toString());
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ChatPage(title: "Chat")),
                          );
                        },
                        child: Text("Sign in with Google")),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  ChatPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  CollectionReference messages =
      FirebaseFirestore.instance.collection('messages');
  String token = "";
  List retrievedMessages = [];
  TextEditingController controller = new TextEditingController();

  @override
  void initState() {
    super.initState();
    getToken();
    handleIncomingMessages();
    retrieveMessages();
  }

  void getToken() async {
    token = (await messaging.getToken())!;
    print("token " + token);
  }

  void handleIncomingMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print(
            'Message also contained a notification: ${message.notification!.title}');
      }
    });
  }

  void retrieveMessages() {
    retrievedMessages = [];
    messages.get().then((QuerySnapshot querySnapshot) {
      querySnapshot.docs.forEach((doc) {
        print(doc["message"]);
        retrievedMessages.add(doc);
        setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Hello ${FirebaseAuth.instance.currentUser?.displayName}"),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: 50,
                    child: TextFormField(
                      controller: controller,
                      decoration: new InputDecoration(
                          hintText: "Send a message to yourself ..."),
                    ),
                  ),
                ),
                TextButton(
                    onPressed: () async {
                      await messages.add({
                        "message": controller.text,
                        "senderUID": FirebaseAuth.instance.currentUser!.uid,
                        "receiverUID": FirebaseAuth.instance.currentUser!.uid,
                      });
                      retrieveMessages();
                    },
                    child: Text("Send"))
              ],
            ),
            Expanded(
              child: SizedBox(
                height: 500,
                child: ListView(
                  children: retrievedMessages
                      .map((msg) => Card(
                            child: Column(
                              children: [
                                Text("Sender UID: ${msg['senderUID']}"),
                                Text("Receiver UID: ${msg['receiverUID']}"),
                                Text("Message: ${msg['message']}"),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  setState(() {});
                  Navigator.pop(context);
                },
                child: Text("Sign out"))
          ],
        ),
      ),
    );
  }
}
