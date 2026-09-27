import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings, onDidReceiveNotificationResponse: (details) {},);
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  runApp(const PrimeRiderApp());
}

class PrimeRiderApp extends StatelessWidget {
  const PrimeRiderApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, title: 'Prime Rider', home: SplashScreen());
  }
}

class SplashScreen extends StatefulWidget {
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> {
  @override void initState(){ super.initState(); checkLogin(); }
  checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? riderId = prefs.getString('riderId');
    String? customId = prefs.getString('customId');
    if(riderId!=null && customId!=null){
      var doc = await FirebaseFirestore.instance.collection('riders').doc(riderId).get();
      if(doc.exists){
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomeScreen(riderData: doc.data()!, riderId: riderId, customId: customId)));
        return;
      }
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> LoginScreen()));
  }
  @override Widget build(BuildContext context){ return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)))); }
}

class LoginScreen extends StatefulWidget {
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final idCtrl = TextEditingController(text: "PHR-101");
  final passCtrl = TextEditingController(text: "123456");
  bool load = false;
  login() async {
    String rid = idCtrl.text.trim().toUpperCase();
    String pass = passCtrl.text.trim();
    if(rid.isEmpty||pass.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ID / Password likho"))); return; }
    setState(()=> load=true);
    try{
      var doc = await FirebaseFirestore.instance.collection('riders').doc(rid).get();
      Map<String,dynamic>? data;
      String actualDocId = rid;
      if(doc.exists){ data = doc.data()!; } else {
        var query = await FirebaseFirestore.instance.collection('riders').where('riderId', isEqualTo: rid).limit(1).get();
        if(query.docs.isEmpty) throw "Rider $rid nahi mila!";
        data = query.docs.first.data();
        actualDocId = query.docs.first.id;
      }
      if(data!.containsKey('password') && data['password']!= null && data['password'].toString().isNotEmpty){
        if(data['password']!= pass) throw "Password ghalat hai!";
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('riderId', actualDocId);
      await prefs.setString('customId', data['riderId']??actualDocId);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> HomeScreen(riderData: data!, riderId: actualDocId, customId: data['riderId']??actualDocId)));
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, duration: Duration(seconds: 4)));
    }
    setState(()=> load=false);
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(child: SingleChildScrollView(padding: EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/logo.png', width: 160, height: 160, fit: BoxFit.cover, errorBuilder: (c,e,s)=> Container(width: 160, height: 160, decoration: BoxDecoration(color: Color(0xFFFFC107), borderRadius: BorderRadius.circular(28)), child: Icon(Icons.delivery_dining, size: 70)))),
        SizedBox(height: 16),
        Text("PRIME RIDER", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
        SizedBox(height: 30),
        TextField(controller: idCtrl, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Rider ID - PHR-101", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.person, color: Color(0xFFFFC107)), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 12),
        TextField(controller: passCtrl, obscureText: true, style: TextStyle(color: Colors.white), decoration: InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white70), prefixIcon: Icon(Icons.lock, color: Color(0xFFFFC107)), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: load?null:login, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFC107)), child: load? CircularProgressIndicator(color: Colors.black) : Text("LOGIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))),
      ]))),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final Map<String,dynamic> riderData; final String riderId; final String customId;
  HomeScreen({required this.riderData, required this.riderId, required this.customId});
  @override State<HomeScreen> createState()=> _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen>{
  bool isOnline=false;
  final mapController = MapController();
  LatLng currentPos = LatLng(29.6968, 72.5545);
  final AudioPlayer audioPlayer = AudioPlayer();
  int newOrdersCount = 0;
  List<Polygon> zonePolygons = [];
  List<Marker> zoneMarkers = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isPopupShowing = false;

  @override void initState(){
    super.initState();
    isOnline=widget.riderData['isOnline']??false;
    loadZonesForMap();
    listenForOrders();
  }

  Future<void> loadZonesForMap() async {
    try{
      String city = (widget.riderData['city']??'Chonawala').toString().trim();
      String riderZone = (widget.riderData['zone']??'').toString().trim();
      print("ZONE LOAD START city=$city zone=$riderZone");

      // Pehle exact city + name se try karo
      QuerySnapshot snap;
      try{
        snap = await FirebaseFirestore.instance.collection('zones').where('city', isEqualTo: city).where('name', isEqualTo: riderZone).get();
      }catch(e){
        snap = await FirebaseFirestore.instance.collection('zones').where('city', isEqualTo: city).get();
      }

      // Agar exact match se kuch nahi mila to sirf city se lao (Chonawala Zone case)
      if(snap.docs.isEmpty){
        snap = await FirebaseFirestore.instance.collection('zones').where('city', isEqualTo: city).get();
      }
      // Agar city se bhi nahi mila to saare zones lao
      if(snap.docs.isEmpty){
        snap = await FirebaseFirestore.instance.collection('zones').get();
      }

      List<Polygon> polys = [];
      List<Marker> marks = [];
      LatLng? zoneCenter;

      for(var doc in snap.docs){
        var z = doc.data() as Map<String,dynamic>;
        String zName = (z['name']??z['zoneName']??'').toString().trim();
        String zCity = (z['city']??'').toString().trim();

        // City filter - agar city match nahi to skip mat karo testing ke liye, lekin ideally city same hona chahiye
        if(zCity.isNotEmpty && zCity.toLowerCase()!= city.toLowerCase()){
          // continue; // isko comment rakha hai taake tera Chonawala wala zone dikhe
        }

        var pointsRaw = (z['points'] as List?)?? [];
        if(pointsRaw.isEmpty) continue;

        List<LatLng> pts = [];
        for(var p in pointsRaw){
          double lat=0, lng=0;
          if(p is Map){
            lat = ((p['lat']?? p['latitude']?? 0) as num).toDouble();
            lng = ((p['lng']?? p['lon']?? p['longitude']?? 0) as num).toDouble();
          } else if(p is GeoPoint){
            lat = (p as GeoPoint).latitude;
            lng = (p as GeoPoint).longitude;
          }
          if(lat!=0 && lng!=0) pts.add(LatLng(lat,lng));
        }

        if(pts.length < 3) continue;

        double avgLat = pts.map((e)=>e.latitude).reduce((a,b)=>a+b)/pts.length;
        double avgLng = pts.map((e)=>e.longitude).reduce((a,b)=>a+b)/pts.length;
        zoneCenter = LatLng(avgLat, avgLng);

        polys.add(Polygon(points: pts, color: Colors.orange.withOpacity(0.25), borderColor: Color(0xFFFFC107), borderStrokeWidth: 3, isFilled: true));
        marks.add(Marker(point: LatLng(avgLat, avgLng), child: Container(padding: EdgeInsets.symmetric(horizontal:6, vertical:3), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)), child: Text(zName.isEmpty? riderZone : zName, style: TextStyle(color: Color(0xFFFFC107), fontSize: 11, fontWeight: FontWeight.bold)))));
      }

      print("ZONE POLYGONS FOUND: ${polys.length}");

      setState((){
        zonePolygons = polys;
        zoneMarkers = marks;
        if(zoneCenter!=null){
          currentPos = zoneCenter!;
          try{ mapController.move(currentPos, 13); }catch(_){}
        }
      });
    }catch(e){
      print("Zone load error $e");
    }
  }

  Future<void> showLoudNotification(String orderId) async {
    if (await Vibration.hasVibrator()?? false) Vibration.vibrate(duration: 1500, pattern: [0,500,200,500]);
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('prime_rider_orders', 'New Orders', importance: Importance.max, priority: Priority.high, playSound: true, enableVibration: true, fullScreenIntent: true);
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(DateTime.now().millisecond, "🔔 NEW ORDER AYA!", "Order $orderId - Jaldi Accept Karo!", details);
  }

  // ===== YE NAYA POPUP FUNCTION HAI - SCREEN PE AYEGA =====
  void showOrderPopupOnScreen(String docId, Map<String,dynamic> orderData) async {
    if(isPopupShowing) return;
    if(!isOnline) return;
    if(!mounted) return;

    setState(()=> isPopupShowing = true);

    // Bell Sound Loop Start
    try{
      await audioPlayer.setReleaseMode(ReleaseMode.loop);
      await audioPlayer.play(AssetSource('sounds/bell.mp3'));
    }catch(e){ print("Bell error $e"); }

    if (await Vibration.hasVibrator()?? false) Vibration.vibrate(duration: 2000, pattern: [0,800,200,800]);
    await showLoudNotification(orderData['orderId']??docId);

    if(!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Icon(Icons.notifications_active, color: Colors.white, size: 22)),
            SizedBox(width: 10),
            Expanded(child: Text("NEW ORDER AYA!", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 18))),
          ]),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: double.infinity, padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Order ID: ${orderData['orderId']??docId}", style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text("Amount: Rs.${orderData['total']??0}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            ])),
            SizedBox(height: 12),
            Row(children: [Icon(Icons.person, size: 16), SizedBox(width: 5), Expanded(child: Text("${orderData['customerName']??'Customer'}", style: TextStyle(fontWeight: FontWeight.bold)))]),
            SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on, size: 16, color: Colors.red), SizedBox(width: 5), Expanded(child: Text("${orderData['address']??'Address nahi'}", style: TextStyle(fontSize: 13)))]),
            SizedBox(height: 6),
            Row(children: [Icon(Icons.store, size: 16), SizedBox(width: 5), Text("Zone: ${orderData['zone']??widget.riderData['zone']}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
            SizedBox(height: 6),
            Row(children: [Icon(Icons.payment, size: 16), SizedBox(width: 5), Text("${orderData['paymentMethod']??'COD'}", style: TextStyle(fontSize: 12))]),
          ])),
          actions: [
            TextButton(onPressed: () async { await audioPlayer.stop(); if(mounted){ Navigator.pop(ctx); setState(()=> isPopupShowing=false); } }, child: Text("REJECT", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                await audioPlayer.stop();
                if(mounted) Navigator.pop(ctx);
                setState(()=> isPopupShowing=false);
                try{
                  await FirebaseFirestore.instance.collection('orders').doc(docId).update({'riderId': widget.riderId, 'riderCustomId': widget.customId, 'riderName': widget.riderData['name']??'Rider', 'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()});
                  if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Order Accepted!"), backgroundColor: Colors.green));
                  Navigator.push(context, MaterialPageRoute(builder: (_)=> OrdersTab(riderId: widget.riderId, customId: widget.customId, city: widget.riderData['city']??'', zone: widget.riderData['zone']??'', audioPlayer: audioPlayer, riderName: widget.riderData['name']??'Rider')));
                }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)); }
              },
              child: Text("ACCEPT - Rs.${orderData['total']??0}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))
            )),
          ],
        ),
      ),
    ).then((_) async {
      await audioPlayer.stop();
      setState(()=> isPopupShowing=false);
    });
  }

  void listenForOrders(){
    String city = widget.riderData['city']??'';
    String zone = widget.riderData['zone']??'';
    FirebaseFirestore.instance.collection('orders').where('city', isEqualTo: city).where('status', whereIn: ['pending','assigned']).limit(50).snapshots().listen((snap) async {
      for(var change in snap.docChanges){
        if(change.type == DocumentChangeType.added){
          var d = change.doc.data() as Map<String,dynamic>?;
          if(d!=null){
            String orderZone = (d['zone']??'').toString();
            if(zone.isEmpty || orderZone==zone || orderZone.isEmpty){
              if(mounted) setState(()=> newOrdersCount++);
              showOrderPopupOnScreen(change.doc.id, d);
            }
          }
        }
      }
    });
  }

  void refreshMap(){ loadZonesForMap(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Zone Refresh Ho Gaya - Only your zone"))); }
  void requestZoneChange(){
    String newZone = "";
    showDialog(context: context, builder: (_)=> AlertDialog(title: Text("Zone Change Request"), content: TextField(onChanged: (v)=> newZone=v, decoration: InputDecoration(labelText: "Naya Zone likho", border: OutlineInputBorder())), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('zoneRequests').add({'riderId': widget.customId, 'oldZone': widget.riderData['zone'], 'newZone': newZone, 'riderName': widget.riderData['name'], 'city': widget.riderData['city'], 'status': 'Pending', 'createdAt': FieldValue.serverTimestamp()}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request Bhej Di"), backgroundColor: Colors.green)); }, child: Text("Send"))]));
  }
  void requestShiftChange(){
    String newShift = "Morning"; String newMobile = "";
    showDialog(context: context, builder: (_)=> AlertDialog(title: Text("Shift / Mobile Change"), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField(value: "Morning", items: ["Morning","Evening","Night"].map((e)=> DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=> newShift=v!, decoration: InputDecoration(labelText: "New Shift", border: OutlineInputBorder())), SizedBox(height: 10), TextField(onChanged: (v)=> newMobile=v, decoration: InputDecoration(labelText: "Naya Mobile", border: OutlineInputBorder()))]), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: Text("Cancel")), ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('shiftRequests').add({'riderId': widget.customId, 'oldShift': widget.riderData['shift'], 'newShift': newShift, 'newMobile': newMobile, 'riderName': widget.riderData['name'], 'status': 'Pending', 'createdAt': FieldValue.serverTimestamp()}); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request Bhej Di"), backgroundColor: Colors.green)); }, child: Text("Send"))]));
  }

  void openPage(Widget page){
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_)=> page));
  }

  @override Widget build(BuildContext context){
    String zone = widget.riderData['zone']??'';
    String city = widget.riderData['city']??'Chonawala';
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(title: Text("Prime Rider - $zone"), backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107),
      leading: IconButton(icon: Icon(Icons.menu), onPressed: ()=> _scaffoldKey.currentState?.openDrawer()),
      actions: [
        Container(margin: EdgeInsets.only(top:8,bottom:8), padding: EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: isOnline?Colors.green:Colors.red, borderRadius: BorderRadius.circular(20)), child: Row(children: [Text(isOnline?"Online":"Offline", style: TextStyle(color: Colors.white, fontSize: 12)), Switch(value: isOnline, activeColor: Colors.white, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, onChanged: (v) async { setState(()=> isOnline=v); await FirebaseFirestore.instance.collection('riders').doc(widget.riderId).update({'isOnline': v}); })])),
        Stack(children: [IconButton(icon: Icon(Icons.notifications, size: 28), onPressed: (){ audioPlayer.stop(); setState(()=> newOrdersCount=0); openPage(OrdersTab(riderId: widget.riderId, customId: widget.customId, city: widget.riderData['city']??'', zone: widget.riderData['zone']??'', audioPlayer: audioPlayer, riderName: widget.riderData['name']??'Rider')); }), if(newOrdersCount>0) Positioned(right: 4, top: 4, child: Container(padding: EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text("$newOrdersCount", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))))]),
        SizedBox(width: 8)
      ]),
      drawer: Drawer(child: ListView(children: [
        DrawerHeader(decoration: BoxDecoration(color: Colors.black), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Image.asset('assets/icon.png', width: 60, height: 60, errorBuilder: (c,e,s)=> Icon(Icons.person, color: Colors.white)), SizedBox(height: 8), Text(widget.riderData['name']??'Rider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("${widget.customId} | ${widget.riderData['mobile']??''}", style: TextStyle(color: Colors.white70, fontSize: 12)), Text("${widget.riderData['city']??''} | ${widget.riderData['zone']??''}", style: TextStyle(color: Color(0xFFFFC107), fontSize: 11, fontWeight: FontWeight.bold))])),
        ListTile(leading: Icon(Icons.map, color: Colors.black), title: Text("Map View (Home)"), onTap: ()=> Navigator.pop(context)),
        ListTile(leading: Stack(children: [Icon(Icons.list_alt, color: Colors.orange), if(newOrdersCount>0) Positioned(right:0,top:0,child: Container(width:8,height:8,decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)))]), title: Text("Orders ${newOrdersCount>0?'($newOrdersCount New)':''}"), onTap: (){ audioPlayer.stop(); setState(()=> newOrdersCount=0); openPage(OrdersTab(riderId: widget.riderId, customId: widget.customId, city: city, zone: zone, audioPlayer: audioPlayer, riderName: widget.riderData['name']??'Rider')); }),
        Divider(),
        ListTile(leading: Icon(Icons.calendar_month, color: Colors.blue), title: Text("My Earning"), subtitle: Text("Date Range + Delivery Earning", style: TextStyle(fontSize:10)), onTap: ()=> openPage(EarningScreen(riderId: widget.riderId, customId: widget.customId))),
        ListTile(leading: Icon(Icons.money, color: Colors.green), title: Text("COD Collection"), subtitle: Text("Total COD", style: TextStyle(fontSize:10)), onTap: ()=> openPage(CODCollectionScreen(riderId: widget.riderId, customId: widget.customId))),
        ListTile(leading: Icon(Icons.receipt_long, color: Colors.orange), title: Text("COD Deposit"), subtitle: Text("Deposit History + Proof", style: TextStyle(fontSize:10)), onTap: ()=> openPage(CODDepositScreen(riderId: widget.riderId, customId: widget.customId))),
        ListTile(leading: Icon(Icons.chat_bubble, color: Color(0xFF0879F9)), title: Text("Live Chat - Admin"), onTap: ()=> openPage(LiveChatScreen(riderId: widget.customId, riderName: widget.riderData['name']??'Rider'))),
        ListTile(leading: Icon(Icons.access_time, color: Colors.purple), title: Text("My Shift / Zone"), onTap: ()=> openPage(ShiftScreen(riderData: widget.riderData, riderId: widget.riderId, customId: widget.customId, onZoneRequest: (){ Navigator.pop(context); requestZoneChange(); }, onShiftRequest: (){ Navigator.pop(context); requestShiftChange(); }))),
        Divider(),
        ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text("Logout"), onTap: () async { SharedPreferences prefs = await SharedPreferences.getInstance(); await prefs.clear(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=> LoginScreen())); }),
      ])),
      body: Stack(children: [
        FlutterMap(mapController: mapController, options: MapOptions(initialCenter: currentPos, initialZoom: 14), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.primerider'),
          if(zonePolygons.isNotEmpty) PolygonLayer(polygons: zonePolygons),
          MarkerLayer(markers: [
            Marker(point: currentPos, width: 50, height: 50, child: Container(decoration: BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)), child: Icon(Icons.delivery_dining, color: Colors.black))),
       ...zoneMarkers
          ])
        ]),
        Positioned(bottom: 20, left: 12, right: 12, child: Container(padding: EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("📍 $city - $zone\nOnly your zone showing", style: TextStyle(color: Color(0xFFFFC107), fontSize: 11)), ElevatedButton.icon(onPressed: refreshMap, icon: Icon(Icons.refresh, size: 16), label: Text("Refresh", style: TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFC107), foregroundColor: Colors.black))])),
        )
      ]),
    );
  }
}

class EarningScreen extends StatefulWidget {
  final String riderId; final String customId;
  EarningScreen({required this.riderId, required this.customId});
  @override State<EarningScreen> createState()=> _EarningScreenState();
}
class _EarningScreenState extends State<EarningScreen> {
  DateTime? rangeStart; DateTime? rangeEnd;
  DateTime focusedDate = DateTime.now();
  CalendarFormat calFormat = CalendarFormat.month;
  RangeSelectionMode rangeMode = RangeSelectionMode.toggledOn;

  @override void initState(){ rangeStart = DateTime.now().subtract(Duration(days: 7)); rangeEnd = DateTime.now(); super.initState(); }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black, leading: BackButton(color: Color(0xFFFFC107)), title: Text("My Earning", style: TextStyle(color: Color(0xFFFFC107)))),
      body: Column(children: [
        Container(color: Colors.white10, child: TableCalendar(
          firstDay: DateTime(2023), lastDay: DateTime.now(),
          focusedDay: focusedDate,
          rangeStartDay: rangeStart, rangeEndDay: rangeEnd,
          rangeSelectionMode: rangeMode,
          calendarFormat: calFormat,
          onFormatChanged: (f){ setState(()=> calFormat=f); },
          onRangeSelected: (start,end,focused){ setState((){ rangeStart=start; rangeEnd=end; focusedDate=focused; }); },
          onDaySelected: (sel,foc){ setState((){ focusedDate=foc; }); },
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: Colors.white),
            weekendTextStyle: TextStyle(color: Colors.white),
            rangeStartDecoration: BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
            rangeEndDecoration: BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
            rangeHighlightColor: Color(0xFFFFC107).withOpacity(0.3),
            selectedDecoration: BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle)
          ),
          headerStyle: HeaderStyle(titleTextStyle: TextStyle(color: Colors.white), formatButtonVisible: true, formatButtonTextStyle: TextStyle(color: Colors.white), formatButtonDecoration: BoxDecoration(border: Border.all(color: Colors.white), borderRadius: BorderRadius.circular(6)), leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white), rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white)),
        )),
        Padding(padding: EdgeInsets.all(10), child: Text(rangeStart!=null && rangeEnd!=null? "Selected: ${DateFormat('dd MMM').format(rangeStart!)} - ${DateFormat('dd MMM yyyy').format(rangeEnd!)}" : "Select 2 dates (start - end)", style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold))),
        Expanded(child: _buildDeliveryList())
      ]),
    );
  }

  Widget _buildDeliveryList(){
    if(rangeStart==null || rangeEnd==null) return Center(child: Text("2 dates select karo", style: TextStyle(color: Colors.white70)));
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').where('riderId', isEqualTo: widget.riderId).where('status', isEqualTo: 'delivered').snapshots(),
      builder: (c,snap){
        if(snap.connectionState==ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)));
        if(!snap.hasData) return Center(child: Text("Loading...", style: TextStyle(color: Colors.white70)));
        var filtered = snap.data!.docs.where((d){
          var ts = (d.data() as Map)['deliveredAt'] as Timestamp?;
          if(ts==null) return false;
          DateTime dt = ts.toDate();
          DateTime start = DateTime(rangeStart!.year, rangeStart!.month, rangeStart!.day);
          DateTime end = DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day, 23,59,59);
          return dt.isAfter(start.subtract(Duration(seconds:1))) && dt.isBefore(end.add(Duration(seconds:1)));
        }).toList();

        double totalEarn = 0;
        for(var d in filtered){
          var mapData = d.data() as Map<String,dynamic>;
          double fee;
          if(mapData['deliveryFee']!= null){
            fee = (mapData['deliveryFee'] as num).toDouble();
          } else {
            fee = ((mapData['total']??0) as num).toDouble() * 0.15;
          }
          totalEarn += fee;
        }

        return Column(children: [
          Container(margin: EdgeInsets.all(10), padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Color(0xFFFFC107), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Delivery Earning", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)), Text("${filtered.length} Orders", style: TextStyle(color: Colors.black87, fontSize: 11))]), Text("Rs.${totalEarn.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black))])),
          Expanded(child: filtered.isEmpty? Center(child: Text("No delivered orders in this range", style: TextStyle(color: Colors.white70))) : ListView.builder(itemCount: filtered.length, itemBuilder: (c,i){
            var o = filtered[i].data() as Map<String,dynamic>;
            double earn = 0;
            if(o['deliveryFee']!= null){ earn = (o['deliveryFee'] as num).toDouble(); } else { earn = ((o['total']??0) as num).toDouble() * 0.15; }
            return Card(color: Colors.white10, child: ListTile(title: Text(o['orderId']??'', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text("${o['address']??''} | ${o['deliveredAt']!=null? DateFormat('dd MMM hh:mm a').format((o['deliveredAt'] as Timestamp).toDate()):''}", style: TextStyle(color: Colors.white70, fontSize: 11)), trailing: Text("Rs.${earn.toStringAsFixed(0)}", style: TextStyle(color: Color(0xFFFFC107), fontWeight: FontWeight.bold))));
          }))
        ]);
      },
    );
  }
}

class CODCollectionScreen extends StatefulWidget {
  final String riderId; final String customId;
  CODCollectionScreen({required this.riderId, required this.customId});
  @override State<CODCollectionScreen> createState()=> _CODCollectionScreenState();
}
class _CODCollectionScreenState extends State<CODCollectionScreen>{
  DateTime? rangeStart; DateTime? rangeEnd;
  @override void initState(){ rangeStart=DateTime.now().subtract(Duration(days: 7)); rangeEnd=DateTime.now(); super.initState(); }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black, leading: BackButton(color: Color(0xFFFFC107)), title: Text("COD Collection", style: TextStyle(color: Color(0xFFFFC107))), actions: [IconButton(icon: Icon(Icons.calendar_month, color: Color(0xFFFFC107)), onPressed: () async { DateTimeRange? picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: rangeStart!, end: rangeEnd!)); if(picked!=null) setState((){ rangeStart=picked.start; rangeEnd=picked.end; }); })]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('riderId', isEqualTo: widget.riderId).where('status', isEqualTo: 'delivered').snapshots(),
        builder: (c,snap){
          if(!snap.hasData) return Center(child: CircularProgressIndicator());
          var allDocs = snap.data!.docs.where((d){
            var ts = (d.data() as Map)['deliveredAt'] as Timestamp?;
            if(ts==null) return false;
            DateTime dt = ts.toDate();
            DateTime start = DateTime(rangeStart!.year, rangeStart!.month, rangeStart!.day);
            DateTime end = DateTime(rangeEnd!.year, rangeEnd!.month, rangeEnd!.day, 23,59,59);
            return dt.isAfter(start.subtract(Duration(seconds:1))) && dt.isBefore(end.add(Duration(seconds:1)));
          }).toList();
          var codDocs = allDocs.where((d){ var pm = ((d.data() as Map)['paymentMethod']??'').toString().toLowerCase(); return pm.contains('cash') || pm.contains('cod'); }).toList();
          int totalCod = 0;
          for(var d in codDocs){ totalCod += ((d.data() as Map<String,dynamic>)['total'] as num?)?.toInt()??0; }

          return Column(children: [
            Container(margin: EdgeInsets.all(12), padding: EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Total COD Collected", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("${DateFormat('dd MMM').format(rangeStart!)} - ${DateFormat('dd MMM yyyy').format(rangeEnd!)}", style: TextStyle(color: Colors.white70, fontSize: 11))]), Text("Rs.$totalCod", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal:12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text("Deposit Karo"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: (){
                    Navigator.push(context, MaterialPageRoute(builder: (_)=> CODDepositFormScreen(riderId: widget.riderId, customId: widget.customId, totalCod: totalCod)));
                  },
                ),
              ),
            ),
            Expanded(child: codDocs.isEmpty? Center(child: Text("No COD orders", style: TextStyle(color: Colors.white70))) : ListView.builder(itemCount: codDocs.length, itemBuilder: (c,i){ var o = codDocs[i].data() as Map<String,dynamic>; return Card(color: Colors.white10, child: ListTile(title: Text(o['orderId']??'', style: TextStyle(color: Colors.white)), subtitle: Text(o['address']??'', style: TextStyle(color: Colors.white70, fontSize:11)), trailing: Text("Rs.${o['total']??0}", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)))); }))
          ]);
        }
      ),
    );
  }
}

class CODDepositScreen extends StatelessWidget {
  final String riderId; final String customId;
  CODDepositScreen({required this.riderId, required this.customId});
  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(backgroundColor: Colors.black, leading: BackButton(color: Color(0xFFFFC107)), title: Text("COD Deposit History", style: TextStyle(color: Color(0xFFFFC107))), actions: [IconButton(icon: Icon(Icons.add, color: Color(0xFFFFC107)), onPressed: ()=> Navigator.push(context, MaterialPageRoute(builder: (_)=> CODDepositFormScreen(riderId: riderId, customId: customId, totalCod: 0))))]),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('codDeposits').where('riderId', isEqualTo: riderId).orderBy('createdAt', descending: true).snapshots(),
        builder: (c,snap){
          if(!snap.hasData) return Center(child: CircularProgressIndicator());
          if(snap.data!.docs.isEmpty) return Center(child: Text("No deposits yet", style: TextStyle(color: Colors.white70)));
          return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (c,i){
            var d = snap.data!.docs[i].data() as Map<String,dynamic>;
            return Card(color: Colors.white10, margin: EdgeInsets.all(8), child: ListTile(
              leading: d['proofUrl']!=null? Image.network(d['proofUrl'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s)=> Icon(Icons.receipt, color: Colors.white)): Icon(Icons.receipt, color: Colors.white),
              title: Text("Rs.${d['amount']??0} - ${d['method']??'Easypaisa'}", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Trx: ${d['trxId']??''}", style: TextStyle(color: Colors.white70, fontSize:11)), Text("Date: ${d['date']??''} | Status: ${d['status']??''}", style: TextStyle(color: Colors.orangeAccent, fontSize:10))]),
            ));
          });
        }
      ),
    );
  }
}

class CODDepositFormScreen extends StatefulWidget {
  final String riderId; final String customId; final int totalCod;
  CODDepositFormScreen({required this.riderId, required this.customId, required this.totalCod});
  @override State<CODDepositFormScreen> createState()=> _CODDepositFormScreenState();
}
class _CODDepositFormScreenState extends State<CODDepositFormScreen>{
  final amountCtrl = TextEditingController();
  final trxCtrl = TextEditingController();
  String method = "Easypaisa";
  File? pickedImage;
  bool loading = false;
  final picker = ImagePicker();

  @override void initState(){ super.initState(); if(widget.totalCod>0) amountCtrl.text = widget.totalCod.toString(); }
  pickImage() async {
    var x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if(x!=null) setState(()=> pickedImage = File(x.path));
  }
  submit() async {
    if(amountCtrl.text.isEmpty || trxCtrl.text.isEmpty){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Amount aur Trx ID likho"))); return; }
    if(pickedImage==null){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Proof pic upload karo"))); return; }
    setState(()=> loading=true);
    try{
      await FirebaseFirestore.instance.collection('codDeposits').add({
        'riderId': widget.riderId,
        'customId': widget.customId,
        'amount': int.tryParse(amountCtrl.text)??0,
        'trxId': trxCtrl.text.trim(),
        'method': method,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'Pending Verification',
        'proofLocal': pickedImage!.path,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deposit submit ho gaya!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red)); }
    setState(()=> loading=false);
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("Deposit Proof"), backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107)),
      body: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(children: [
        TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Amount Deposited", prefixText: "Rs. ", border: OutlineInputBorder())),
        SizedBox(height:12),
        TextField(controller: trxCtrl, decoration: InputDecoration(labelText: "Trx ID", hintText: "Easypaisa Transaction ID", border: OutlineInputBorder())),
        SizedBox(height:12),
        DropdownButtonFormField(value: method, items: ["Easypaisa", "JazzCash", "Bank"].map((e)=> DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v)=> setState(()=> method=v!), decoration: InputDecoration(labelText: "Method", border: OutlineInputBorder())),
        SizedBox(height:12),
        GestureDetector(onTap: pickImage, child: Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey)), child: pickedImage==null? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload, size: 40), Text("Upload Screenshot")]) : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(pickedImage!, fit: BoxFit.cover, width: double.infinity)))),
        SizedBox(height:20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: loading?null:submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: loading? CircularProgressIndicator(color: Colors.white) : Text("Submit Deposit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

class OrdersTab extends StatefulWidget{
  final String riderId; final String customId; final String city; final String zone; final AudioPlayer audioPlayer; final String riderName;
  OrdersTab({required this.riderId, required this.customId, required this.city, required this.zone, required this.audioPlayer, required this.riderName});
  @override State<OrdersTab> createState()=> _OrdersTabState();
}
class _OrdersTabState extends State<OrdersTab>{
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("Orders - ${widget.zone}"), backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').where('city', isEqualTo: widget.city).limit(50).snapshots(),
        builder: (context, snap){
          if(snap.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)));
          if(!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text("Koi order nahi"));
          var allDocs = snap.data!.docs;
          allDocs.sort((a,b){ var ta = (a.data() as Map)['createdAt']; var tb = (b.data() as Map)['createdAt']; if(ta is Timestamp && tb is Timestamp) return tb.compareTo(ta); return 0; });
          var filteredForZone = allDocs.where((d){ var data = d.data() as Map<String,dynamic>; String z = (data['zone']??'').toString(); if(widget.zone.isEmpty) return true; return z==widget.zone || z.isEmpty; }).toList();
          var pendingOrders = filteredForZone.where((d){ var s = (d.data() as Map)['status']; return s=='pending' || s=='assigned'; }).toList();
          var myOrders = allDocs.where((d){ var dData = d.data() as Map<String,dynamic>; return (dData['riderId']==widget.riderId || dData['riderCustomId']==widget.customId) && dData['status']!='delivered'; }).toList();
          var combined = [...pendingOrders,...myOrders];
          var seen = <String>{};
          combined = combined.where((d)=> seen.add(d.id)).toList();
          if(combined.isEmpty) return Center(child: Text("Koi pending order nahi"));
          return ListView.builder(padding: EdgeInsets.all(12), itemCount: combined.length, itemBuilder: (c,i){
            DocumentSnapshot doc = combined[i];
            var o = doc.data() as Map<String,dynamic>;
            var id = doc.id;
            bool isMyOrder = o['riderId']==widget.riderId || o['riderCustomId']==widget.customId;
            bool alreadyAccepted = o['riderId']!=null &&!isMyOrder;
            return Card(color: isMyOrder? Colors.green[50] : Colors.white, elevation: 3, child: Padding(padding: EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: isMyOrder? Colors.green : Color(0xFFFFC107), child: Icon(isMyOrder? Icons.check : Icons.shopping_bag, color: isMyOrder? Colors.white : Colors.black)), title: Text("${o['orderId']??id} - Rs.${o['total']??0}", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${o['customerName']??''} | ${o['address']??''}\nZone: ${o['zone']??''} | ${o['status']}", style: TextStyle(fontSize: 12)), isThreeLine: true),
              if(isMyOrder) Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Customer: ${o['customerName']??'Customer'}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text("Phone: ${o['customerPhone']?? o['phone']?? 'N/A'}", style: TextStyle(fontSize: 11))])),
              SizedBox(height: 8),
              Row(children: [
                if(alreadyAccepted) Text("Taken", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                else Expanded(child: ElevatedButton(onPressed: () async {
                    widget.audioPlayer.stop();
                    if(isMyOrder){
                      await FirebaseFirestore.instance.collection('orders').doc(id).update({'status': 'delivered', 'deliveredAt': FieldValue.serverTimestamp()});
                      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delivered!"), backgroundColor: Colors.green)); Future.delayed(Duration(milliseconds: 800), (){ if(Navigator.canPop(context)) Navigator.pop(context); }); }
                    } else {
                      await FirebaseFirestore.instance.collection('orders').doc(id).update({'riderId': widget.riderId, 'riderCustomId': widget.customId, 'riderName': widget.riderName, 'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()});
                      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Order Accepted!"), backgroundColor: Colors.green));
                    }
                  }, child: Text(isMyOrder? "Delivered" : "Accept"), style: ElevatedButton.styleFrom(backgroundColor: isMyOrder? Colors.blue : Colors.green, foregroundColor: Colors.white))),
                if(isMyOrder) SizedBox(width: 8),
                if(isMyOrder) Expanded(child: ElevatedButton.icon(icon: Icon(Icons.chat, size:16), label: Text("Chat", style: TextStyle(fontSize:11)), style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107)), onPressed: (){ Navigator.push(context, MaterialPageRoute(builder: (_)=> RiderCustomerChatScreen(orderDocId: id, orderDisplayId: o['orderId']??id, customerName: o['customerName']??'Customer', riderName: widget.customId, customerPhone: o['customerPhone']??''))); })),
              ])
            ])));
          });
        },
      ),
    );
  }
}

class LiveChatScreen extends StatefulWidget{
  final String riderId; final String riderName;
  LiveChatScreen({required this.riderId, required this.riderName});
  @override State<LiveChatScreen> createState()=> _LiveChatScreenState();
}
class _LiveChatScreenState extends State<LiveChatScreen>{
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  sendMsg() async {
    if(msgCtrl.text.trim().isEmpty) return;
    String msg = msgCtrl.text.trim();
    msgCtrl.clear();
    await FirebaseFirestore.instance.collection('chats').add({'riderId': widget.riderId, 'riderName': widget.riderName, 'message': msg, 'sender': 'rider', 'createdAt': FieldValue.serverTimestamp(), 'isRead': false, 'receiver': 'admin'});
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("Live Chat - Admin"), backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107)),
      body: Column(children: [
        Expanded(child: StreamBuilder(stream: FirebaseFirestore.instance.collection('chats').where('riderId', isEqualTo: widget.riderId).snapshots(), builder: (c,snap){
            if(!snap.hasData) return Center(child: CircularProgressIndicator());
            var docs = snap.data!.docs;
            docs.sort((a,b){ var ta = a.data()['createdAt']; var tb = b.data()['createdAt']; if(ta==null) return -1; if(tb==null) return 1; return (ta as Timestamp).compareTo(tb as Timestamp); });
            WidgetsBinding.instance.addPostFrameCallback((_) { if(scrollCtrl.hasClients) scrollCtrl.jumpTo(scrollCtrl.position.maxScrollExtent); });
            return ListView.builder(controller: scrollCtrl, padding: EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (c,i){ var m = docs[i].data(); bool isMe = m['sender']=='rider'; return Align(alignment: isMe? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical: 4), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isMe? Colors.black : Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Text(m['message']??'', style: TextStyle(color: isMe? Color(0xFFFFC107) : Colors.black)))); });
          })),
        Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: "Admin ko message...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))))), SizedBox(width: 8), CircleAvatar(backgroundColor: Colors.black, child: IconButton(icon: Icon(Icons.send, color: Color(0xFFFFC107)), onPressed: sendMsg)),])),
      ]),
    );
  }
}

class RiderCustomerChatScreen extends StatefulWidget {
  final String orderDocId; final String orderDisplayId; final String customerName; final String riderName; final String customerPhone;
  RiderCustomerChatScreen({required this.orderDocId, required this.orderDisplayId, required this.customerName, required this.riderName, required this.customerPhone});
  @override State<RiderCustomerChatScreen> createState()=> _RiderCustomerChatScreenState();
}
class _RiderCustomerChatScreenState extends State<RiderCustomerChatScreen>{
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  sendMsg() async {
    if(msgCtrl.text.trim().isEmpty) return;
    String txt = msgCtrl.text.trim();
    msgCtrl.clear();
    await FirebaseFirestore.instance.collection('order_chats').doc(widget.orderDocId).collection('messages').add({'message': txt, 'sender': 'rider', 'senderName': widget.riderName, 'createdAt': FieldValue.serverTimestamp(), 'isRead': false});
  }
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107), title: Text(widget.customerName)),
      body: Column(children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('order_chats').doc(widget.orderDocId).collection('messages').orderBy('createdAt').snapshots(), builder: (c,snap){
          if(!snap.hasData) return Center(child: Text("No chat yet"));
          var docs = snap.data!.docs;
          return ListView.builder(controller: scrollCtrl, padding: EdgeInsets.all(12), itemCount: docs.length, itemBuilder: (c,i){ var m = docs[i].data() as Map<String,dynamic>; bool isMe = m['sender']=='rider'; return Align(alignment: isMe? Alignment.centerRight: Alignment.centerLeft, child: Container(margin: EdgeInsets.symmetric(vertical:4), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: isMe? Colors.black: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)), child: Text(m['message']??'', style: TextStyle(color: isMe? Color(0xFFFFC107): Colors.black)))); });
        })),
        Padding(padding: EdgeInsets.all(8), child: Row(children: [Expanded(child: TextField(controller: msgCtrl, decoration: InputDecoration(hintText: "Customer ko likho...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(25))))), SizedBox(width:8), CircleAvatar(backgroundColor: Colors.black, child: IconButton(icon: Icon(Icons.send, color: Color(0xFFFFC107)), onPressed: sendMsg))]))
      ]),
    );
  }
}

class ShiftScreen extends StatelessWidget{
  final Map<String,dynamic> riderData; final String riderId; final String customId; final VoidCallback onZoneRequest; final VoidCallback onShiftRequest;
  ShiftScreen({required this.riderData, required this.riderId, required this.customId, required this.onZoneRequest, required this.onShiftRequest});
  @override Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text("My Shift / Zone"), backgroundColor: Colors.black, foregroundColor: Color(0xFFFFC107)),
      body: ListView(padding: EdgeInsets.all(16), children: [
        Card(child: ListTile(leading: Icon(Icons.access_time, color: Color(0xFF0879F9)), title: Text("My Shift"), subtitle: Text(riderData['shift']??'Morning', style: TextStyle(fontWeight: FontWeight.bold)), trailing: ElevatedButton(onPressed: onShiftRequest, child: Text("Change")))),
        Card(child: ListTile(leading: Icon(Icons.location_on, color: Colors.orange), title: Text("Zone - ${riderData['zone']??''}"), subtitle: Text("City: ${riderData['city']??''}"), trailing: ElevatedButton(onPressed: onZoneRequest, child: Text("Request Change"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange)))),
      ]),
    );
  }
}