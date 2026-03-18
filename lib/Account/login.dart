import 'package:cuqter/Account/signup.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:cuqter/resources/auth_method.dart';
import 'package:cuqter/utils/picker.dart';
import 'package:flutter/material.dart';
import 'package:cuqter/utils/colors.dart';

class Loginpage extends StatefulWidget {
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

// ignore: camel_case_types
class _LoginpageState extends State<Loginpage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;

  void loginuser() async {
    String res = await AuthMethod().loginuser(
      email: emailController.text,
      password: passwordController.text,
    );
    if (res == 'success') {
      showSnackBar('Login successful', context);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Homepage()),
      );
      emailController.clear();
      passwordController.clear();
    } else {
      showSnackBar(res, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 600,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Login',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.email),
                  hintText: 'cuqter@mail.com',
                  label: Text("Enter your Email"),
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
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                onPressed: () {
                  loginuser();
                },
                child: Text('Login'),
              ),

              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: AppColors.grey),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => Sighuppage()),
                      );
                    },
                    child: Text(
                      "Sign Up",
                      style: TextStyle(color: AppColors.blueDefault),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
