import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class EditUserBottomSheet extends StatefulWidget {
  final int? index;
  final Map<String, dynamic>? user;

  EditUserBottomSheet({this.index, this.user});

  @override
  _EditUserBottomSheetState createState() => _EditUserBottomSheetState();
}

class _EditUserBottomSheetState extends State<EditUserBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameController.text = widget.user!['name'];
      _emailController.text = widget.user!['email'] ?? '';
      _roleController.text = widget.user!['role'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.user == null ? 'Add User' : 'Edit User',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter name';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _roleController,
                  decoration: InputDecoration(labelText: 'Role'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter role';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final newUser = {
                            'name': _nameController.text,
                            'email': _emailController.text,
                            'role': _roleController.text,
                          };

                          if (widget.index == null) {
                            Provider.of<UserProvider>(context, listen: false)
                                .addUser(newUser);
                          } else {
                            Provider.of<UserProvider>(context, listen: false)
                                .updateUser(widget.index!, newUser);
                          }

                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(widget.index == null ? 'Add' : 'Update'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:provider/provider.dart';
// import '../../providers/user_provider.dart'; // Assuming you have a UserProvider

// class EditUserBottomSheet extends StatefulWidget {
//   final int? index;
//   final Map<String, dynamic>? user;

//   EditUserBottomSheet({this.index, this.user});

//   @override
//   _EditUserBottomSheetState createState() => _EditUserBottomSheetState();
// }

// class _EditUserBottomSheetState extends State<EditUserBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _roleController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.user != null) {
//       _nameController.text = widget.user!['name'];
//       _emailController.text = widget.user!['email'] ?? '';
//       _roleController.text = widget.user!['role'] ?? '';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: MediaQuery.of(context).viewInsets,
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.user == null ? 'Add User' : 'Edit User',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(labelText: 'Name'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: InputDecoration(labelText: 'Email'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter email';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _roleController,
//                   decoration: InputDecoration(labelText: 'Role'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter role';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           final newUser = {
//                             'name': _nameController.text,
//                             'email': _emailController.text,
//                             'role': _roleController.text,
//                           };

//                           if (widget.index == null) {
//                             Provider.of<UserProvider>(context, listen: false)
//                                 .addUser(newUser);
//                           } else {
//                             Provider.of<UserProvider>(context, listen: false)
//                                 .updateUser(widget.index!, newUser);
//                           }

//                           Navigator.of(context).pop();
//                         }
//                       },
//                       child: Text(widget.index == null ? 'Add' : 'Update'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';

// class EditUserBottomSheet extends StatefulWidget {
//   final int? index;
//   final Map<String, dynamic>? user;

//   EditUserBottomSheet({this.index, this.user});

//   @override
//   _EditUserBottomSheetState createState() => _EditUserBottomSheetState();
// }

// class _EditUserBottomSheetState extends State<EditUserBottomSheet> {
//   final _formKey = GlobalKey<FormState>();
//   final _nameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _roleController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     if (widget.user != null) {
//       _nameController.text = widget.user!['name'];
//       _emailController.text = widget.user!['email'] ?? '';
//       _roleController.text = widget.user!['role'] ?? '';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: MediaQuery.of(context).viewInsets,
//       child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   widget.user == null ? 'Add User' : 'Edit User',
//                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _nameController,
//                   decoration: InputDecoration(labelText: 'Name'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter name';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _emailController,
//                   decoration: InputDecoration(labelText: 'Email'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter email';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 TextFormField(
//                   controller: _roleController,
//                   decoration: InputDecoration(labelText: 'Role'),
//                   validator: (value) {
//                     if (value == null || value.isEmpty) {
//                       return 'Please enter role';
//                     }
//                     return null;
//                   },
//                 ),
//                 SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                       },
//                       child: Text('Cancel'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_formKey.currentState!.validate()) {
//                           final newUser = {
//                             'name': _nameController.text,
//                             'email': _emailController.text,
//                             'role': _roleController.text,
//                           };

//                           if (widget.index == null) {
//                             // Add user logic here
//                           } else {
//                             // Update user logic here
//                           }

//                           Navigator.of(context).pop();
//                         }
//                       },
//                       child: Text(widget.index == null ? 'Add' : 'Update'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
