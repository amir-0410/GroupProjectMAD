import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'config.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tagger',
      theme: ThemeData.dark(),
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  Future<void> _signUpWithEmail() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog(
          "Sign Up Failed", "Please enter both email and password.");
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } catch (e) {
      _showErrorDialog("Sign Up Failed", e.toString());
    }
  }

  Future<void> _signInWithEmail() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog("Login Failed", "Please enter both email and password.");
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } catch (e) {
      _showErrorDialog("Login Failed", e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Tagger',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signInWithEmail,
                child: Text('Login'),
              ),
              TextButton(
                onPressed: _signUpWithEmail,
                child: Text('Create an Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  User? _user;
  List<String> searchResults = [];
  List<String> popularTags = [
    '#BreakingNews',
    '#TechNews',
    '#SportsNews',
    '#WorldNews'
  ];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  void _fetchUserDetails() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> fetchTweets(String query) async {
    await Future.delayed(Duration(seconds: 2)); // Prevent rapid API calls

    try {
      final response = await http.get(
        Uri.parse(
            "https://api.twitter.com/2/tweets/search/recent?query=${Uri.encodeComponent(query)}"),
        headers: {
          "Authorization": "Bearer ${Config.bearerToken}",
        },
      );

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          searchResults = (data['data'] as List<dynamic>)
              .take(10) // Limit results
              .map((tweet) => tweet['text'].toString())
              .toList();
        });
      } else {
        throw Exception("Failed to load tweets");
      }
    } catch (error) {
      print("Error fetching tweets: $error");
    }
  }

  @override
  Widget build(BuildContext context) {
    String email = _user?.email ?? "Not Logged In";
    String username = email.split('@')[0];

    return Scaffold(
      appBar: AppBar(
        title: Text('Tagger - Search'),
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search Tagger',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => fetchTweets(searchController.text),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text('Popular Tags',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 10.0,
              children: popularTags
                  .map((tag) => ActionChip(
                        label: Text(tag),
                        onPressed: () => fetchTweets(tag),
                      ))
                  .toList(),
            ),
            SizedBox(height: 20),
            Expanded(
              child: searchResults.isEmpty
                  ? Center(child: Text('Search for tweets using a tag.'))
                  : ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(searchResults[index]),
                          onTap: () {
                            launchUrl(Uri.parse(
                                "https://twitter.com/search?q=${Uri.encodeComponent(searchController.text)}"));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    String email = user?.email ?? "Not Logged In";
    String username = email.split('@')[0];

    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueGrey),
            child: Text('Menu',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ),
          ListTile(
            title: Text('Home'),
            onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(),
                )),
          ),
          ListTile(
            title: Text('Profile'),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(),
                )),
          ),
          ListTile(
            title: Text('Settings'),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (context) => SettingsPage())),
          ),
          ListTile(
            title: Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => LoginPage()));
            },
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  User? _user;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  void _fetchUserDetails() {
    setState(() {
      _user = FirebaseAuth.instance.currentUser;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    String email = _user?.email ?? "Not Logged In";
    String username = email.split('@')[0];

    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _image != null
                      ? FileImage(_image!)
                      : AssetImage('assets/profile_placeholder.png')
                          as ImageProvider,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text('Username: $username', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text('Email: $email', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _logout,
                child: Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notification Preferences'),
            ),
            ListTile(
              leading: Icon(Icons.lock),
              title: Text('Privacy Settings'),
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text('About Tagger'),
            ),
          ],
        ),
      ),
    );
  }
}
