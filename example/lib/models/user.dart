class User {
  final String name;

  final String address;

  final List<User> users;

  User({
    required this.name,
    required this.address,
    this.users = const <User>[],
  });

  @override
  String toString() {
    return '$name, $address ${users.map((e) => e.toString())}';
  }
}
