import 'package:flutter/material.dart';

class Demo extends StatefulWidget {
  const Demo({super.key});

  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Demo")),
      body: Center(
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              child: Text("A", style: TextStyle(fontSize: 50)),
            ),
            Text("Asha Karki", style: TextStyle(fontSize: 20)),
            Text("Username", style: TextStyle(fontSize: 20)),
            Container(
              height: 50,
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 225, 225),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  "Hi I'm Using Cuqter",
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 50,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 225, 225),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.message_rounded, color: Colors.black),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.videocam_rounded, color: Colors.black),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.call, color: Colors.black),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            Container(
              height: MediaQuery.of(context).size.height * 0.3,
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 232, 225, 225),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Stack(
                  children: [
                    Text("djbk", style: TextStyle(fontSize: 20)),
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.info_outline),
                        onPressed: () {},
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Information",
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Text(" This future only for Luv Colab", style: TextStyle(fontSize: 20))
                    ),
                ],
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
