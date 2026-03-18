
class user {

final String uid;
final String email;
final String name;
final String profilepic;
final String bio;

user({
  required this.uid,
  required this.email,
  required this.name,
  required this.profilepic,
  this.bio = "",
  required String password,
});


Map<String, dynamic> toJson() => {
  "uid": uid,
  "email": email,
  "name": name,
  "profilepic": profilepic,
  "bio": bio,
};
}