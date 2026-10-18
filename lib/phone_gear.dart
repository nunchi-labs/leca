import 'phone.dart';

/// Web keeps the handset quiet. The installed app opens the microphone.
PhoneGear openPhoneGear() => SilentGear();
