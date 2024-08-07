// import 'package:dhavla_road_project/providers/notification_provider.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart';


// class BaseSettingsScreen extends StatefulWidget {
//   final String role;

//   BaseSettingsScreen({required this.role});

//   @override
//   _BaseSettingsScreenState createState() => _BaseSettingsScreenState();
// }

// class _BaseSettingsScreenState extends State<BaseSettingsScreen> {
//   bool _notificationsEnabled = true;
//   bool _soundEnabled = true;
//   String _selectedTheme = 'Light';

//   @override
//   void initState() {
//     super.initState();
//     _loadSettings();
//   }

//   Future<void> _loadSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _notificationsEnabled =
//           prefs.getBool('${widget.role}_notificationsEnabled') ?? true;
//       _soundEnabled = prefs.getBool('${widget.role}_soundEnabled') ?? true;
//       _selectedTheme =
//           prefs.getString('${widget.role}_selectedTheme') ?? 'Light';
//     });
//   }

//   Future<void> _saveSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(
//         '${widget.role}_notificationsEnabled', _notificationsEnabled);
//     await prefs.setBool('${widget.role}_soundEnabled', _soundEnabled);
//     await prefs.setString('${widget.role}_selectedTheme', _selectedTheme);

//     final notificationProvider =
//         Provider.of<NotificationProvider>(context, listen: false);
//     if (_notificationsEnabled) {
//       await notificationProvider.subscribeToTopics([widget.role.toLowerCase()]);
//     } else {
//       await notificationProvider
//           .unsubscribeFromTopics([widget.role.toLowerCase()]);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('${widget.role} Settings'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Notification Settings',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SwitchListTile(
//               title: Text('Enable Notifications'),
//               value: _notificationsEnabled,
//               onChanged: (bool value) {
//                 setState(() {
//                   _notificationsEnabled = value;
//                 });
//               },
//             ),
//             SwitchListTile(
//               title: Text('Enable Notification Sounds'),
//               value: _soundEnabled,
//               onChanged: (bool value) {
//                 setState(() {
//                   _soundEnabled = value;
//                 });
//               },
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Theme',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             DropdownButton<String>(
//               value: _selectedTheme,
//               onChanged: (String? newValue) {
//                 setState(() {
//                   _selectedTheme = newValue!;
//                 });
//               },
//               items: <String>['Light', 'Dark']
//                   .map<DropdownMenuItem<String>>((String value) {
//                 return DropdownMenuItem<String>(
//                   value: value,
//                   child: Text(value),
//                 );
//               }).toList(),
//             ),
//             SizedBox(height: 16),
//             Center(
//               child: ElevatedButton(
//                 onPressed: () async {
//                   await _saveSettings();
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text('Settings saved')),
//                   );
//                 },
//                 child: Text('Save Settings'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
