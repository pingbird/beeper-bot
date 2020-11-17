import 'dart:html';

void tabBarSetup() {
  final tabBar = querySelector('#tab-bar');
  final tabView = querySelector('#tab-view');
  for (var i = 0; i < tabBar.children.length; i++) {
    tabBar.children[i].onClick.listen((event) {
      for (var j = 0; j < tabBar.children.length; j++) {
        if (j == i) {
          tabView.children[j].classes.add('active');
          tabBar.children[j].classes.add('active');
        } else {
          tabView.children[j].classes.remove('active');
          tabBar.children[j].classes.remove('active');
        }
      }
    });
  }
}

void main() {
  tabBarSetup();
}