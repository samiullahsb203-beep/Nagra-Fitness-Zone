
// Full app (simplified) - includes Firebase stubs; add google-services.json to android/app for Firebase to initialize.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class AppState extends ChangeNotifier {
  User? user;
  Map<String, dynamic>? profile;
  void setUser(User? u){ user = u; notifyListeners(); }
  void setProfile(Map<String,dynamic>? p){ profile = p; notifyListeners(); }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Gym Management',
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Color(0xFF0F1115)),
        home: EntryPoint(),
      ),
    );
  }
}

class EntryPoint extends StatefulWidget { @override _EntryPointState createState() => _EntryPointState(); }
class _EntryPointState extends State<EntryPoint> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  void initState(){
    super.initState();
    _auth.userChanges().listen((u) async {
      final app = Provider.of<AppState>(context, listen:false);
      app.setUser(u);
      if (u != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(u.uid).get();
        app.setProfile(doc.exists ? doc.data() : {'role':'member'});
      } else {
        app.setProfile(null);
      }
    });
  }
  @override
  Widget build(BuildContext context){
    final app = Provider.of<AppState>(context);
    if (app.user == null) return AuthScreen();
    final role = app.profile?['role'] ?? 'member';
    if (role == 'admin') return AdminHome();
    return MemberHome();
  }
}

class AuthScreen extends StatefulWidget { @override _AuthScreenState createState() => _AuthScreenState(); }
class _AuthScreenState extends State<AuthScreen>{
  bool isLogin = true; final _email = TextEditingController(); final _pwd = TextEditingController();
  final _name = TextEditingController(); final _phone = TextEditingController(); bool loading=false;
  @override Widget build(BuildContext context){
    return Scaffold(
      body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Column(children:[
        SizedBox(height:20),
        Text(isLogin ? 'Sign In' : 'Register', style: TextStyle(fontSize:28,fontWeight: FontWeight.bold)),
        SizedBox(height:16),
        if(!isLogin) TextField(controller: _name, decoration: InputDecoration(labelText:'Name')),
        TextField(controller: _email, decoration: InputDecoration(labelText:'Email')),
        TextField(controller: _pwd, decoration: InputDecoration(labelText:'Password'), obscureText: true),
        if(!isLogin) TextField(controller: _phone, decoration: InputDecoration(labelText:'Phone')),
        SizedBox(height:12),
        ElevatedButton(onPressed: loading?null:() async {
          setState(()=>loading=true);
          try{
            if(isLogin){
              await FirebaseAuth.instance.signInWithEmailAndPassword(email:_email.text.trim(), password:_pwd.text.trim());
            } else {
              final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email:_email.text.trim(), password:_pwd.text.trim());
              await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
                'name': _name.text.trim(),
                'phone': _phone.text.trim(),
                'role': 'member',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } catch(e){
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          }
          setState(()=>loading=false);
        }, child: Text(isLogin?'Login':'Register')),
        TextButton(onPressed: ()=>setState(()=>isLogin=!isLogin), child: Text(isLogin?'Create an account':'Have an account? Sign in'))
      ],),),),
    );
  }
}

class AdminHome extends StatefulWidget { @override _AdminHomeState createState()=> _AdminHomeState(); }
class _AdminHomeState extends State<AdminHome>{
  int _page=0;
  @override Widget build(BuildContext context){
    final pages = [AdminMembersPage(), AdminVideoPage(), AdminSettingsPage()];
    return Scaffold(
      appBar: AppBar(title: Text('Admin Panel')),
      body: pages[_page],
      bottomNavigationBar: BottomNavigationBar(currentIndex: _page, items: [
        BottomNavigationBarItem(icon: Icon(Icons.people), label:'Members'),
        BottomNavigationBarItem(icon: Icon(Icons.video_collection), label:'Video'),
        BottomNavigationBarItem(icon: Icon(Icons.settings), label:'Settings'),
      ], onTap: (i)=>setState(()=>_page=i)),
    );
  }
}

class AdminMembersPage extends StatefulWidget { @override _AdminMembersPageState createState()=> _AdminMembersPageState(); }
class _AdminMembersPageState extends State<AdminMembersPage>{
  final _search = TextEditingController();
  @override Widget build(BuildContext context){
    return Column(children: [
      Padding(padding: EdgeInsets.all(8), child: Row(children:[
        Expanded(child: TextField(controller: _search, decoration: InputDecoration(hintText:'Search'))),
        IconButton(icon: Icon(Icons.add), onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=>MemberForm())))
      ])),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('members').orderBy('joiningDate', descending:true).snapshots(),
        builder: (context, snap){
          if(!snap.hasData) return Center(child:CircularProgressIndicator());
          final docs = snap.data!.docs.where((d){
            final q=_search.text.toLowerCase();
            return q.isEmpty || d['name'].toString().toLowerCase().contains(q) || d['phone'].toString().contains(q);
          }).toList();
          return ListView.builder(itemCount: docs.length, itemBuilder: (ctx,i){
            final d = docs[i];
            return Card(child: ListTile(
              title: Text(d['name'] ?? ''),
              subtitle: Text('${d['phone'] ?? ''}\\nJoined: ${_fmt(d['joiningDate'])}'),
              isThreeLine: true,
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
                Text(d['feesStatus'] ?? 'unpaid', style: TextStyle(color: d['feesStatus']=='paid'?Colors.green:Colors.red)),
                PopupMenuButton<String>(onSelected: (v) async {
                  if(v=='edit') Navigator.push(context, MaterialPageRoute(builder: (_)=>MemberForm(editDoc: d)));
                  else if(v=='delete') await FirebaseFirestore.instance.collection('members').doc(d.id).delete();
                  else if(v=='mark_paid') await FirebaseFirestore.instance.collection('members').doc(d.id).update({'feesStatus':'paid'});
                }, itemBuilder: (_)=>[
                  PopupMenuItem(value:'edit', child: Text('Edit')),
                  PopupMenuItem(value:'mark_paid', child: Text('Mark Paid')),
                  PopupMenuItem(value:'delete', child: Text('Delete')),
                ])
              ]),
            ));
          });
        },
      ))
    ]);
  }
  String _fmt(Timestamp? t){ if(t==null) return '-'; return DateFormat.yMMMd().format(t.toDate()); }
}

class MemberForm extends StatefulWidget { final QueryDocumentSnapshot? editDoc; MemberForm({this.editDoc}); @override _MemberFormState createState()=> _MemberFormState(); }
class _MemberFormState extends State<MemberForm>{
  final _name = TextEditingController(); final _phone = TextEditingController(); final _fees = TextEditingController();
  DateTime? _joining; String _status='unpaid';
  @override void initState(){
    super.initState();
    if(widget.editDoc!=null){
      final d = widget.editDoc!;
      _name.text = d['name'] ?? '';
      _phone.text = d['phone'] ?? '';
      _fees.text = (d['feesAmount'] ?? '').toString();
      _status = d['feesStatus'] ?? 'unpaid';
      final t = d['joiningDate'] as Timestamp?;
      if(t!=null) _joining = t.toDate();
    }
  }
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text(widget.editDoc==null?'Add Member':'Edit Member')), body: Padding(padding: EdgeInsets.all(12), child: Column(children:[
      TextField(controller: _name, decoration: InputDecoration(labelText:'Name')),
      TextField(controller: _phone, decoration: InputDecoration(labelText:'Phone')),
      TextField(controller: _fees, decoration: InputDecoration(labelText:'Fees Amount'), keyboardType: TextInputType.number),
      Row(children:[ Text(_joining==null?'No date':DateFormat.yMMMd().format(_joining!)), Spacer(), TextButton(onPressed: () async {
        final dt = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if(dt!=null) setState(()=>_joining=dt);
      }, child: Text('Select Date')) ]),
      DropdownButton<String>(value: _status, items: ['paid','unpaid'].map((e)=>DropdownMenuItem(value:e, child: Text(e))).toList(), onChanged: (v)=>setState(()=>_status=v!)),
      SizedBox(height:12),
      ElevatedButton(onPressed: () async {
        final data = {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'feesAmount': double.tryParse(_fees.text.trim()) ?? 0,
          'feesStatus': _status,
          'joiningDate': _joining==null?FieldValue.serverTimestamp():Timestamp.fromDate(_joining!),
        };
        if(widget.editDoc==null) await FirebaseFirestore.instance.collection('members').add(data);
        else await FirebaseFirestore.instance.collection('members').doc(widget.editDoc!.id).update(data);
        Navigator.pop(context);
      }, child: Text('Save'))
    ])));
  }
}

class AdminVideoPage extends StatefulWidget { @override _AdminVideoPageState createState()=> _AdminVideoPageState(); }
class _AdminVideoPageState extends State<AdminVideoPage>{
  final _title = TextEditingController(); final _price = TextEditingController();
  @override Widget build(BuildContext context){
    return SingleChildScrollView(padding: EdgeInsets.all(12), child: Column(children:[
      Text('Daily Workout Video', style: TextStyle(fontWeight: FontWeight.bold)),
      StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('meta').doc('daily').snapshots(), builder:(c,s){
        if(!s.hasData) return Text('No video');
        final url = s.data!['dailyVideoUrl'] as String?;
        return Column(children: [ if(url!=null) Text('Current video available'), SizedBox(height:8), ElevatedButton(onPressed: (){
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload via extending code.')));
        }, child: Text('Upload/Change Video')) ]);
      }),
      Divider(),
      Text('Packages', style: TextStyle(fontWeight: FontWeight.bold)),
      TextField(controller: _title, decoration: InputDecoration(labelText:'Package Title')),
      TextField(controller: _price, decoration: InputDecoration(labelText:'Price'), keyboardType: TextInputType.number),
      ElevatedButton(onPressed: () async {
        final p = {'title': _title.text.trim(), 'price': double.tryParse(_price.text.trim()) ?? 0, 'createdAt': FieldValue.serverTimestamp()};
        await FirebaseFirestore.instance.collection('packages').add(p);
        _title.clear(); _price.clear();
      }, child: Text('Add Package')),
      StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('packages').orderBy('createdAt', descending: true).snapshots(), builder:(c,s){
        if(!s.hasData) return SizedBox();
        final docs = s.data!.docs;
        return Column(children: docs.map((d)=>ListTile(title: Text(d['title']), subtitle: Text('Price: ${d['price']}'), trailing: IconButton(icon: Icon(Icons.delete), onPressed: ()=>d.reference.delete()))).toList());
      })
    ]));
  }
}

class AdminSettingsPage extends StatefulWidget { @override _AdminSettingsPageState createState()=> _AdminSettingsPageState(); }
class _AdminSettingsPageState extends State<AdminSettingsPage>{
  final _uid = TextEditingController();
  @override Widget build(BuildContext context){
    return Padding(padding: EdgeInsets.all(12), child: Column(children:[
      Text('Assign Admin by User UID', style: TextStyle(fontWeight: FontWeight.bold)),
      TextField(controller: _uid, decoration: InputDecoration(labelText:'User UID')),
      ElevatedButton(onPressed: () async {
        final uid = _uid.text.trim(); if(uid.isEmpty) return;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'role':'admin'});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated.')));
      }, child: Text('Make Admin')),
      SizedBox(height:20),
      ElevatedButton(onPressed: () async { await FirebaseAuth.instance.signOut(); }, child: Text('Logout'))
    ]));
  }
}

class MemberHome extends StatelessWidget{
  @override Widget build(BuildContext context){
    return Scaffold(appBar: AppBar(title: Text('Member')), body: SingleChildScrollView(padding: EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      Text('Today\\'s Workout', style: TextStyle(fontSize:20, fontWeight: FontWeight.bold)),
      StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('meta').doc('daily').snapshots(), builder:(c,s){
        if(!s.hasData || !(s.data!.exists)) return Text('No video today');
        final url = s.data!['dailyVideoUrl'] as String?; if(url==null) return Text('No video today');
        return ListTile(title: Text('Daily Video'), subtitle: Text('Tap to open'), trailing: Icon(Icons.play_arrow), onTap: (){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video URL: $url'))); });
      }),
      Divider(),
      Text('Available Packages', style: TextStyle(fontSize:18, fontWeight: FontWeight.bold)),
      StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('packages').orderBy('createdAt', descending: true).snapshots(), builder:(c,s){
        if(!s.hasData) return CircularProgressIndicator();
        final docs = s.data!.docs;
        return Column(children: docs.map((d)=>Card(child: ListTile(title: Text(d['title']), subtitle: Text('Price: ${d['price']}')))).toList());
      }),
      SizedBox(height:20), ElevatedButton(onPressed: ()=>FirebaseAuth.instance.signOut(), child: Text('Logout'))
    ])));
  }
}
