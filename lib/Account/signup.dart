import 'package:cuqter/Account/login.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/utils/colors.dart';
import 'package:cuqter/Screen/homepage.dart';

class Sighuppage extends StatefulWidget {
  const Sighuppage({super.key});

  @override
  State<Sighuppage> createState() => _SighuppageState();
}

class _SighuppageState extends State<Sighuppage> {

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  
  

 signUpUser() async {
  // setState(() {
  //   isloading = true;
  // });
   String res = await AuthMethod().signUpUser(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      // file: _image!, Uint8List: null,

    );
    if (res == 'success') {
      print(nameController.text);
      showSnackBar('Account created successfully', context);
      Navigator.push(context, MaterialPageRoute(builder: (context) => Homepage()));
    } else {
      showSnackBar(res, context);
    }
    // setState(() {
    //   isloading = false;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        margin: EdgeInsets.all(20),
        padding: EdgeInsets.all(20),
        // decoration: BoxDecoration(
        //   borderRadius: BorderRadius.circular(20),
        //   color: const Color.fromARGB(255, 135, 225, 239),
        // ),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 600,
            child:  Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 Text('Sign Up',style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),),
                SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Maaraz',
                    label: Text("Enter your Name"),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.email),
                    hintText: 'cuqter@mail.com',
                    label: Text("Enter your Email"),
                    fillColor: const Color.fromARGB(255, 112, 111, 111),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    hintText: '********',
                    label: Text("Enter your password"),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tealGreenDark,
                  ),
                  onPressed: signUpUser,
                  child: Text('Sign Up'),
                ),
                  SizedBox(height: 20),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text("I have an account? ",
                      style: TextStyle(color: AppColors.grey),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => Loginpage()));
                        },
                        child:Text("Login",
                          style: TextStyle(color: AppColors.blueDefault),
                        )
                      ),
                   ],
                 ),
              ]
            ),
          ),
        ),
      ),
    );
  }
}