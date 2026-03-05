# alert_dashboard

Flutter version 3.41.3  
Dart version 3.11.1  
DevTools version 2.54.1  

List of commands to be aware of--  
  
flutter devices -- To list all connectable devices  
flutter doctor -- To check health  
flutter doctor -v -- To check total health  
flutter run -- To run the application on a device(Device list will show up)  
flutter run -d <device_name> -- To run the application in certain device  
flutter clean -- To clean the packages  
flutter pub get -- To restore cleaned packages  

Goto ROOT and run  
flutter pub get -- To download dependencies  
and then run     
flutter run -d <device_name> -- to run on wirelessly connected mobile device OR  
Device name can be get by `flutter devices` command  
flutter run -- to run on Web browser  

Open `api_service.dart` and `auth_service.dart` and in the baseURL put your `PC IP` by using `ipconfig` in CMD or PowerShell if you are using wireless debugging on mobile, if testing on Web Browser, then it will be `localhost`
