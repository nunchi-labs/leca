// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Khmer Central Khmer (`km`).
class AppLocalizationsKm extends AppLocalizations {
  AppLocalizationsKm([String locale = 'km']) : super(locale);

  @override
  String get appName => 'Leca';

  @override
  String get tagline => 'ថោកជាង · គុណភាពខ្ពស់ · គ្មានដែនកំណត់ឆោត';

  @override
  String get languageToggle => 'EN';

  @override
  String get cityPhnomPenh => 'ភ្នំពេញ';

  @override
  String get citySiemReap => 'សៀមរាប';

  @override
  String get serviceFood => 'អាហារ';

  @override
  String get serviceSend => 'ផ្ញើអ្វីក៏បាន';

  @override
  String get serviceRides => 'ជិះ';

  @override
  String get serviceRent => 'ជួលយាន';

  @override
  String get bornInCambodia => 'គ្រប់ក្រុង ឃុំ និងភូមិក្នុងកម្ពុជា។';

  @override
  String get searchHint => 'ស្វែងរកម្ហូប ឬភោជនីយដ្ឋាន';

  @override
  String popularTitle(int km) {
    return 'ម្ហូបពេញនិយមក្នុងចម្ងាយ $km គីឡូម៉ែត្រ';
  }

  @override
  String get radiusCountry => 'ទូទាំងកម្ពុជា';

  @override
  String get popularCountry => 'ម្ហូបពេញនិយមទូទាំងកម្ពុជា';

  @override
  String radiusLabel(int km) {
    return '$km គីឡូម៉ែត្រ';
  }

  @override
  String get windowHour => 'ម៉ោងនេះ';

  @override
  String get windowDay => 'ថ្ងៃនេះ';

  @override
  String get windowWeek => 'សប្ដាហ៍នេះ';

  @override
  String get windowMonth => 'ខែនេះ';

  @override
  String popularOrders(int count) {
    return '$count ការកម្មង់';
  }

  @override
  String get popularEmpty => 'មិនទាន់មានទិន្នន័យសម្រាប់ពេលនេះទេ';

  @override
  String feePromise(String price) {
    return 'ថ្លៃសេវា ៥% · ថ្លៃដឹកចាប់ពី $price';
  }

  @override
  String etaMins(int mins) {
    return '$mins នាទី';
  }

  @override
  String deliveryFrom(String price) {
    return 'ដឹក $price';
  }

  @override
  String get loadingPlaces => 'កំពុងផ្ទុកភោជនីយដ្ឋាន…';

  @override
  String get emptySearchTitle => 'រកមិនឃើញ';

  @override
  String get emptySearchBody =>
      'គ្មានអ្វីក្នុងរង្វង់នេះទេ។ បង្កើនចំនួនគីឡូម៉ែត្រ។';

  @override
  String get catalogError => 'មិនអាចផ្ទុកភោជនីយដ្ឋានបានទេ។';

  @override
  String get retry => 'ព្យាយាមម្ដងទៀត';

  @override
  String get add => 'បន្ថែម';

  @override
  String get cart => 'រទេះ';

  @override
  String cartItems(int count) {
    return '$count មុខ';
  }

  @override
  String get checkout => 'បញ្ជាទិញ';

  @override
  String get emptyCartTitle => 'រទេះទទេ';

  @override
  String get emptyCartBody => 'ជ្រើសម្ហូបសិន រួចត្រឡប់មកបង់ប្រាក់។';

  @override
  String get backToFood => 'ត្រឡប់ទៅអាហារ';

  @override
  String get noteLabel => 'កំណត់ចំណាំការកម្មង់';

  @override
  String get noteHint => 'ឧទាហរណ៍៖ មិនដាក់ទឹកស៊ីអ៊ីវ បន្ថែមម្ទេស';

  @override
  String get amountLabel => 'ចំនួនទឹកប្រាក់';

  @override
  String get subtotal => 'ម្ហូប';

  @override
  String get deliveryFee => 'ថ្លៃដឹក';

  @override
  String get serviceFee => 'ថ្លៃសេវា';

  @override
  String get serviceFeeNone => '៥% នៃការលក់នេះ។';

  @override
  String driverMinutes(String name, int minutes) {
    return '$name នៅចម្ងាយ $minutes នាទី';
  }

  @override
  String deliveryMinutes(int minutes) {
    return 'ការដឹកនៅចម្ងាយ $minutes នាទី';
  }

  @override
  String get total => 'សរុប';

  @override
  String get payTitle => 'បង់ប្រាក់';

  @override
  String get scanToPay => 'ស្កេនកូដ QR ដើម្បីបង់';

  @override
  String get payWith => 'បង់តាម';

  @override
  String get stripePay => 'បង់តាម Stripe';

  @override
  String get stripeHint =>
      'Stripe Checkout សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay។ ដាក់ STRIPE_PK ពេលមានសោពិត។';

  @override
  String get stripeHintLive =>
      'Stripe រួចរាល់សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay — ស្កេន ឬប៉ះដើម្បីបង់។';

  @override
  String get stripeBrands => 'Visa · Mastercard · Discover · UnionPay · Alipay';

  @override
  String khqrHint(String bank) {
    return 'ស្កេនដោយ $bank ឬ Bakong។ KHQR បង្កើតក្នុងឧបករណ៍ — មិនទាន់ភ្ជាប់គណនីពិត។';
  }

  @override
  String get otherHint => 'QR ទូទៅ សម្រាប់កម្មវិធីស្កេនផ្សេង។';

  @override
  String get loadingQr => 'កំពុងបង្កើតកូដ QR…';

  @override
  String get errorQr => 'មិនអាចបង្កើតកូដ QR បានទេ។';

  @override
  String get invalidAmount => 'ចំនួនទឹកប្រាក់មិនត្រឹមត្រូវ។';

  @override
  String get iPaid => 'ខ្ញុំបានបង់ហើយ';

  @override
  String get paidTitle => 'បានទទួលការកម្មង់';

  @override
  String get paidBody =>
      'រក្សាវិក្កយបត្រក្នុងកម្មវិធីធនាគារ។ Leca មិនកាន់ប្រាក់នេះទេ។';

  @override
  String get close => 'បិទ';

  @override
  String get sendTitle => 'ផ្ញើអ្វីក៏បាន';

  @override
  String get sendBody =>
      'ផ្ញើកញ្ចប់ ឯកសារ ម្ហូប ឬអ្វីដែលស្របច្បាប់។ អ្នកណាក៏អាចដឹកបាន។';

  @override
  String get sendAnythingTitle => 'ផ្ញើឥឡូវ';

  @override
  String get sendAnythingDetail => 'គ្មានប្រភេទហាមឃាត់លើកលែងតែច្បាប់។';

  @override
  String get ridesTitle => 'ជិះ';

  @override
  String get ridesBody =>
      'កក់ការជិះ។ យានស្របច្បាប់ណាក៏បាន ទាំងមានអ្នកបើក និងបើកផ្ទាល់។';

  @override
  String get rentBody =>
      'ជួលយានធម្មតា ឬស្វយ័ត។ បញ្ជីខាងក្រោមជាឧទាហរណ៍ មិនមែនបញ្ជីបិទ។';

  @override
  String get regularVehicles => 'យានធម្មតា';

  @override
  String get autonomousVehicles => 'យានស្វយ័ត';

  @override
  String get autonomousHint => 'គ្មានអ្នកបើក — រថយន្តបើកដោយខ្លួនឯង។';

  @override
  String get withOrWithoutDriver => 'មានអ្នកបើក ឬបើកផ្ទាល់';

  @override
  String get vehicleExamplesNote =>
      'ឧទាហរណ៍ — យានស្របច្បាប់ផ្សេងទៀតអាចជួលបាន ទាំងមានអ្នកបើក និងគ្មាន។';

  @override
  String get ok => 'យល់ព្រម';

  @override
  String get authMockBanner =>
      'Telegram, WeChat, Facebook, X, Google, អ៊ីមែល ឬ WhatsApp។ បើគ្មានម៉ាស៊ីនមេ ឧបករណ៍នេះប្រើការសាកល្បងក្នុងម៉ាស៊ីន។';

  @override
  String get authLiveBanner =>
      'ចូលដោយ Telegram, WeChat, Facebook, X, Google, អ៊ីមែល ឬ WhatsApp។';

  @override
  String get authTelegram => 'បន្តជាមួយ Telegram (សាកល្បង)';

  @override
  String get authTelegramLive => 'បន្តជាមួយ Telegram';

  @override
  String get authX => 'បន្តជាមួយ X (សាកល្បង)';

  @override
  String get authXLive => 'បន្តជាមួយ X';

  @override
  String get authWhatsappLabel => 'WhatsApp';

  @override
  String get authWhatsappSend => 'ផ្ញើលេខកូដ WhatsApp';

  @override
  String get authWhatsappUnconfigured =>
      'ម៉ាស៊ីនមិនទាន់កំណត់ការចូល WhatsApp ទេ។';

  @override
  String get authWechat => 'បន្តជាមួយ WeChat (សាកល្បង)';

  @override
  String get authWechatLive => 'បន្តជាមួយ WeChat';

  @override
  String get authDevCode => 'លេខកូដសាកល្បង';

  @override
  String get authProviderUnconfigured => 'ម៉ាស៊ីនមិនទាន់កំណត់ការចូលនេះទេ។';

  @override
  String get authSmsUnconfigured => 'ម៉ាស៊ីនមិនទាន់កំណត់ការចូលដោយទូរស័ព្ទទេ។';

  @override
  String get authPhoneInvalid => 'បញ្ចូលលេខទូរស័ព្ទយ៉ាងតិច ៨ ខ្ទង់។';

  @override
  String get authCodeInvalid => 'លេខកូដមិនត្រឹមត្រូវ។';

  @override
  String get authHandleEmpty => 'បញ្ចូលគណនី។';

  @override
  String get authFailed => 'មិនអាចចូលបានទេ។';

  @override
  String get authGoogle => 'បន្តជាមួយ Google (សាកល្បង)';

  @override
  String get authGoogleLive => 'បន្តជាមួយ Google';

  @override
  String get authFacebook => 'បន្តជាមួយ Facebook (សាកល្បង)';

  @override
  String get authFacebookLive => 'បន្តជាមួយ Facebook';

  @override
  String get authPhoneLabel => 'លេខទូរស័ព្ទ';

  @override
  String get authPhoneHint => '០១២ ៣៤៥ ៦៧៨';

  @override
  String get authCodeHint => 'លេខកូដ ៤ ខ្ទង់';

  @override
  String get authVerify => 'ផ្ទៀងផ្ទាត់';

  @override
  String get authSendCode => 'ផ្ញើលេខកូដ';

  @override
  String get authEmailLabel => 'អ៊ីមែល';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authPasswordHint => 'ពាក្យសម្ងាត់ យ៉ាងតិច ៨ តួ';

  @override
  String get authNameHint => 'ឈ្មោះរបស់អ្នក';

  @override
  String get authEmailSignIn => 'ចូលដោយអ៊ីមែល';

  @override
  String get authCreateAccount => 'បង្កើតគណនី';

  @override
  String get authNeedAccount => 'មិនទាន់មានគណនី?';

  @override
  String get authHaveAccount => 'មានគណនីហើយ?';

  @override
  String get authEmailInvalid => 'បញ្ចូលអ៊ីមែលឲ្យបានត្រឹមត្រូវ។';

  @override
  String get authPasswordShort => 'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងតិច ៨ តួ។';

  @override
  String get authEmailTaken => 'អ៊ីមែលនេះមានគណនីហើយ។';

  @override
  String get authCredentialsInvalid => 'អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ។';

  @override
  String get deskLead =>
      'គ្រប់គ្រងទំនិញ តម្លៃ និងហាង។ កុំព្យូទ័រនេះអាចទទួលការដឹកបាន។ វាមិនចេញទៅដឹកទេ។';

  @override
  String get deskOrder => 'ទទួលការដឹក';

  @override
  String get deliverTo => 'ដឹកទៅ';

  @override
  String get accountTitle => 'គណនី';

  @override
  String get earnTitle => 'រកប្រាក់ជាមួយ Leca';

  @override
  String get earnBody =>
      'បើកអាជីវកម្មស្របច្បាប់ណាក៏បាន បើកបរ ឬដាក់យានឲ្យជួល។ មួយកម្មវិធី — មិនមែនកម្មវិធីអ្នកបើកដាច់ដោយឡែក។';

  @override
  String get openBusiness => 'បើកអាជីវកម្ម';

  @override
  String get driveCta => 'បើកបរ';

  @override
  String get listVehicle => 'ដាក់យាន';

  @override
  String get myBusinesses => 'អាជីវកម្មរបស់ខ្ញុំ';

  @override
  String get emptyBusinesses => 'មិនទាន់មានអាជីវកម្ម។';

  @override
  String get myVehicles => 'យានរបស់ខ្ញុំ';

  @override
  String get emptyVehicles => 'មិនទាន់មានយានដាក់។';

  @override
  String get withDriver => 'មានអ្នកបើក';

  @override
  String get selfDrive => 'បើកផ្ទាល់';

  @override
  String get drivingOn => 'អ្នកកំពុងនៅលើបណ្ដាញ — អាចទទួលការជិះ';

  @override
  String get drivingOff => 'អ្នកនៅក្រៅបណ្ដាញ';

  @override
  String get signOut => 'ចាកចេញ';

  @override
  String get businessKindHint =>
      'ភោជនីយដ្ឋាន កុំព្យូទ័រ ទំនិញទារក ឱសថស្ថាន ឬប្រភេទស្របច្បាប់ណាក៏បាន។ មិនមែនបញ្ជីបិទ។';

  @override
  String get businessKind => 'ប្រភេទអាជីវកម្ម';

  @override
  String get businessName => 'ឈ្មោះអាជីវកម្ម';

  @override
  String get businessInvalid => 'បញ្ចូលប្រភេទ និងឈ្មោះ។';

  @override
  String get saveBusiness => 'រក្សាទុកអាជីវកម្ម';

  @override
  String get driveBody =>
      'ចូលបណ្ដាញបានបន្ទាប់ពីឯកសារដៃគូ និងការបណ្ដុះបណ្ដាលគ្រប់។ អ្នកជាដៃគូឯករាជ្យ មិនមែននិយោជិត។';

  @override
  String get driveVehicleNote => 'យានដែលអ្នកបើក (ឧ. ទូកទូក)';

  @override
  String get goOnline => 'ចូលបណ្ដាញ';

  @override
  String get listVehicleBody =>
      'ដាក់យានដែលអ្នកជាម្ចាស់។ ប្រភេទស្របច្បាប់ណាក៏បាន មានអ្នកបើក ឬបើកផ្ទាល់។';

  @override
  String get vehicleKind => 'ប្រភេទយាន';

  @override
  String get autonomousToggle => 'ស្វយ័ត';

  @override
  String get vehicleInvalid => 'បញ្ចូលប្រភេទយាន។';

  @override
  String get saveVehicle => 'រក្សាទុកយាន';

  @override
  String get jobsCta => 'ទទួលការងារ';

  @override
  String get jobsTitle => 'ការងារ';

  @override
  String get jobsBody =>
      'ទទួលការជិះ ដឹកម្ហូប ផ្ញើអ្វីស្របច្បាប់។ មិនមែនបញ្ជីបិទ។';

  @override
  String get jobsOffline => 'ចូលបណ្ដាញសិន រួចទទួលការងារ។';

  @override
  String get emptyJobs => 'មិនទាន់មានការងារបើក។';

  @override
  String get emptyAcceptedJobs => 'មិនទាន់មានការងារបានទទួល។';

  @override
  String get loadingJobs => 'កំពុងផ្ទុកការងារ…';

  @override
  String get jobsError => 'មិនអាចផ្ទុកការងារបានទេ។';

  @override
  String get acceptJob => 'ទទួល';

  @override
  String get declineJob => 'បដិសេធ';

  @override
  String get jobAccepted => 'បានទទួល';

  @override
  String get jobDeclined => 'បានបដិសេធ';

  @override
  String get acceptedJobs => 'ការងារបានទទួល';

  @override
  String get openJobs => 'ការងារបើក';

  @override
  String get driverSignup => 'ចុះឈ្មោះអ្នកបើក';

  @override
  String get driverSignupBody =>
      'រូបមុខ និងអត្តសញ្ញាណប័ណ្ណត្រូវត្រូវគ្នា។ នៅកម្ពុជា ត្រូវមានប័ណ្ណបើកបរកម្ពុជា ផ្លាក បណ្ណសម្គាល់យាន ធានារ៉ាប់រងពាណិជ្ជកម្ម ស្លាក Leca និងការបណ្ដុះបណ្ដាល។ ម៉ូតូមិនត្រូវការលិខិតត្រួតពិនិត្យ និងវិញ្ញាបនបត្រដឹកជញ្ជូនទេ។ ទូកទូក និងរម៉កមិនត្រូវការវិញ្ញាបនបត្រដឹកជញ្ជូនទេ។';

  @override
  String get legalName => 'ឈ្មោះពេញ';

  @override
  String get nameOnId => 'ឈ្មោះលើអត្តសញ្ញាណប័ណ្ណ';

  @override
  String get idNumber => 'លេខអត្តសញ្ញាណ';

  @override
  String get selfiePhoto => 'រូបមុខ';

  @override
  String get idCardPhoto => 'អត្តសញ្ញាណប័ណ្ណ';

  @override
  String get pickPhoto => 'បន្ថែមរូប';

  @override
  String get saveDriver => 'ផ្ញើ';

  @override
  String get driverVerified => 'អត្តសញ្ញាណបានផ្ទៀងផ្ទាត់';

  @override
  String get driverUnverified => 'មិនទាន់ផ្ទៀងផ្ទាត់អត្តសញ្ញាណ';

  @override
  String get identityNameMismatch => 'ឈ្មោះមិនដូចនឹងលើអត្តសញ្ញាណប័ណ្ណ។';

  @override
  String get identityIdInvalid => 'បញ្ចូលលេខអត្តសញ្ញាណយ៉ាងតិច ៦ ខ្ទង់។';

  @override
  String get identityPhotoInvalid => 'ប្រើរូបពិត — JPEG, PNG ឬ WebP។';

  @override
  String get identityPhotoSame => 'រូបមុខ និងអត្តសញ្ញាណប័ណ្ណត្រូវខុសគ្នា។';

  @override
  String get identityPhotoMissing => 'បន្ថែមរូបទាំងពីរ។';

  @override
  String get chat => 'ជជែក';

  @override
  String get chatHint => 'សារ';

  @override
  String get sendMessage => 'ផ្ញើ';

  @override
  String get replyAsBusiness => 'ឆ្លើយជាអាជីវកម្ម';

  @override
  String get emptyChat => 'មិនទាន់មានសារ។ អាចសរសេរបានតាំងពីថ្ងៃដំបូង។';

  @override
  String get replyFast => 'ឆ្លើយរហ័ស';

  @override
  String get replySlow => 'ឆ្លើយយឺត';

  @override
  String get replyNew => 'មិនទាន់មានពេលឆ្លើយ';

  @override
  String workingHours(String open, String close) {
    return 'ម៉ោងធ្វើការ $open–$close';
  }

  @override
  String get addItem => 'បន្ថែមទំនិញ';

  @override
  String get itemDescription => 'ការពិពណ៌នាខ្លី';

  @override
  String get itemPrice => 'តម្លៃ (USD)';

  @override
  String get saveItem => 'រក្សាទុកទំនិញ';

  @override
  String get itemInvalid => 'បន្ថែមរូប ការពិពណ៌នាខ្លី និងតម្លៃ។';

  @override
  String get emptyItems => 'មិនទាន់មានទំនិញ។';

  @override
  String get forSale => 'លក់';

  @override
  String get forRent => 'ជួល';

  @override
  String get appPrice => 'តម្លៃកម្មវិធី';

  @override
  String get driverPrice => 'តម្លៃអ្នកបើក';

  @override
  String get proposeFare => 'ស្នើ';

  @override
  String get allowFare => 'យល់ព្រមតម្លៃនេះ';

  @override
  String get fareWaiting =>
      'អ្នកជិះមិនទាន់យល់ព្រមតម្លៃនេះ។ តម្លៃកម្មវិធីនៅតែប្រើ។';

  @override
  String get saleHint => 'ឡាន ម៉ូតូ កង់ ទូកទូក — ជួល ឬទិញ មានអ្នកបើក ឬអត់។';

  @override
  String get shopTitle => 'ហាង';

  @override
  String get ridesPartnerBody =>
      'ការជិះផ្គូផ្គងជាមួយអ្នកបើកកម្ពុជាឯករាជ្យ។ Leca មិនកាន់កាប់យានទេ។ តម្លៃបង្ហាញមុន ហើយមិនបញ្ចុះក្រោយពេលអ្នកជិះយល់ព្រម។';

  @override
  String get rentPartnerBody =>
      'ជួល ឬទិញយានដែលម្ចាស់ដាក់ឯង។ Leca មិនដំណើរការកងយានទេ។';

  @override
  String get rentExamplesKh =>
      'ឧទាហរណ៍យានរបស់ដៃគូ។ Leca មិនកាន់កាប់ និងមិនដំណើរការយានទេ។';

  @override
  String get platformFleetBlocked =>
      'Leca មិនដំណើរការយានស្វយ័ត ឬកងយានផ្ទាល់ខ្លួននៅកម្ពុជាទេ។';

  @override
  String get ownerConfirm => 'ខ្ញុំជាម្ចាស់យាននេះ។ Leca មិនមែនម្ចាស់។';

  @override
  String get ownerRequired => 'បញ្ជាក់ថាអ្នកជាម្ចាស់យាន។';

  @override
  String get licenceNumber => 'លេខប័ណ្ណបើកបរកម្ពុជា';

  @override
  String get plateNumber => 'ផ្លាកលេខ';

  @override
  String get plateLabel => 'ផ្លាក';

  @override
  String get registrationNumber => 'លេខបណ្ណសម្គាល់យានយន្ត';

  @override
  String get inspectionNumber => 'លេខលិខិតត្រួតពិនិត្យបច្ចេកទេស';

  @override
  String get domesticCertNumber => 'លេខវិញ្ញាបនបត្រដឹកជញ្ជូនក្នុងស្រុក';

  @override
  String get insuranceNumber => 'លេខធានារ៉ាប់រងពាណិជ្ជកម្ម';

  @override
  String get logoConfirm => 'ខ្ញុំនឹងដាក់ស្លាកសញ្ញា Leca លើយាន';

  @override
  String get partnerConfirm =>
      'ខ្ញុំជាដៃគូឯករាជ្យ មិនមែននិយោជិត។ ចំណូលនៅជាមួយខ្ញុំ។';

  @override
  String get trainTraffic => 'ខ្ញុំបានរៀនច្បាប់ចរាចរណ៍ផ្លូវគោក';

  @override
  String get trainDriving => 'ខ្ញុំបានរៀនការបើកបរ';

  @override
  String get trainService => 'ខ្ញុំបានរៀនសេវាអតិថិជន';

  @override
  String get trainConduct => 'ខ្ញុំបានរៀនក្រមសីលធម៌';

  @override
  String get onlineBlocked =>
      'បំពេញឯកសារដៃគូ និងការបណ្ដុះបណ្ដាលសិន ទើបចូលបណ្ដាញបាន។';

  @override
  String get licenceInvalid => 'បញ្ចូលលេខប័ណ្ណបើកបរកម្ពុជា។';

  @override
  String get plateInvalid => 'បញ្ចូលផ្លាកលេខ។';

  @override
  String get registrationInvalid => 'បញ្ចូលលេខបណ្ណសម្គាល់យានយន្ត។';

  @override
  String get inspectionInvalid => 'បញ្ចូលលេខលិខិតត្រួតពិនិត្យបច្ចេកទេស។';

  @override
  String get transportCertInvalid =>
      'បញ្ចូលលេខវិញ្ញាបនបត្រដឹកជញ្ជូនក្នុងស្រុក។';

  @override
  String get insuranceInvalid => 'បញ្ចូលលេខធានារ៉ាប់រងពាណិជ្ជកម្ម។';

  @override
  String get logoRequired => 'យានត្រូវមានស្លាកសញ្ញា Leca។';

  @override
  String get partnerRequired => 'បញ្ជាក់ថាអ្នកជាដៃគូឯករាជ្យ។';

  @override
  String get trainingRequired => 'បញ្ចប់ការបណ្ដុះបណ្ដាលទាំងបួនសិន។';

  @override
  String get partnerNotice =>
      'អ្នកបើកជាដៃគូកម្ពុជាឯករាជ្យ។ Leca មិនកាន់កាប់តាក់ស៊ី រ៉ឺម៉ក ឬយានសាធារណៈផ្សេងទេ។';

  @override
  String get sellerName => 'ឈ្មោះអ្នកលក់';

  @override
  String get sellerPhone => 'ទូរស័ព្ទអ្នកលក់';

  @override
  String get sellerId => 'លេខអត្តសញ្ញាណអ្នកលក់';

  @override
  String get sellerKycInvalid =>
      'បញ្ចូលឈ្មោះ ទូរស័ព្ទ និងលេខអត្តសញ្ញាណអ្នកលក់។';

  @override
  String sellerLine(String name, String phone) {
    return '$name · $phone';
  }

  @override
  String get itemDescriptionKm => 'ការពិពណ៌នាជាភាសាខ្មែរ';

  @override
  String get itemKhmer => 'ព័ត៌មានទំនិញត្រូវមានអក្សរខ្មែរ។';

  @override
  String get payMethods =>
      'បង់តាម ABA Pay, Bakong, ACLEDA, Wing Bank, សាច់ប្រាក់ ឬ Visa, Mastercard, Discover, UnionPay និង Alipay តាម Stripe។ Leca មិនកាន់សមតុល្យ។';

  @override
  String get consumerReport => 'តវ៉ា';

  @override
  String get consumerReportDone => 'ការតវ៉ាត្រូវបានកត់ត្រា។ Leca នឹងពិនិត្យ។';

  @override
  String get takedown => 'ដកទំនិញ';

  @override
  String get takedownDone => 'ទំនិញត្រូវបានដក។';

  @override
  String get driverPhoto => 'រូបអ្នកបើក';

  @override
  String get staffIdLabel => 'បណ្ណបុគ្គលិក';

  @override
  String get shareFamily => 'ចែកការជិះនេះទៅគ្រួសារ';

  @override
  String get shareAuthorities => 'ចែកការជិះនេះទៅអាជ្ញាធរ';

  @override
  String get shareCopied => 'បានចម្លង។ ផ្ញើទៅអ្នកទទួល។';

  @override
  String get shareTripHint =>
      'រួមមានអ្នកបើក ផ្លាក ក្រុង ម៉ោង និងទីតាំងបើឧបករណ៍ផ្ដល់។';

  @override
  String get reportSafety => 'រាយការណ៍';

  @override
  String get reportIntoxication => 'បើកបរក្រោមឥទ្ធិពល';

  @override
  String get reportViolence => 'អំពើហិង្សា';

  @override
  String get reportHarassment => 'ការបៀតបៀនផ្លូវភេទ';

  @override
  String get reportActed =>
      'Leca បានកត់ត្រា ហើយផ្អាកដៃគូនេះពីការជិះថ្មី។ ពួកគេអាចប្តឹងបាន។';

  @override
  String get licencePhoto => 'រូបប័ណ្ណបើកបរ';

  @override
  String get registrationPhoto => 'រូបប័ណ្ណចុះឈ្មោះ';

  @override
  String get insurancePhoto => 'រូបធានារ៉ាប់រង';

  @override
  String get reviewPending =>
      'មនុស្សកំពុងមើលឯកសារនេះ។ ការចូលបណ្តាញរង់ចាំការនោះ។';

  @override
  String get reviewApproved => 'មនុស្សបានយល់ព្រមឯកសារនេះ។';

  @override
  String get reviewRejected => 'ឯកសារនេះមិនត្រូវបានយល់ព្រម។';

  @override
  String get appealHint => 'របាយការណ៍បានផ្អាកអ្នក។ សរសេរមូលហេតុដែលគួរលុបចោល។';

  @override
  String get appealSend => 'ប្តឹង';

  @override
  String get appealEmpty => 'សរសេរការប្តឹង។';

  @override
  String get upfrontFare => 'តម្លៃបង្ហាញមុន';

  @override
  String get noWallet =>
      'ប្រាក់ចូលធនាគារ តាម Stripe សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay ឬជាសាច់ប្រាក់។ Leca មិនមានកាបូបប្រាក់ ឬ Bitcoin។';

  @override
  String get cashHint =>
      'បង់ជារៀល ឬដុល្លារទៅដៃគូ ឬអ្នកលក់។ Leca មិនទទួលសាច់ប្រាក់នេះទេ។';

  @override
  String get dropoff => 'ទម្លាក់';

  @override
  String autoFare(String km, int minutes) {
    return '$km គ.ម · $minutes នាទី';
  }

  @override
  String fareProof(String proof) {
    return 'ភស្តុតាង $proof';
  }

  @override
  String get talkVoice => 'សំឡេង';

  @override
  String get talkVideo => 'វីដេអូ';

  @override
  String get talkProof => 'ការជជែកនេះផ្ទៀងផ្ទាត់បាន';

  @override
  String get talkIroh =>
      'អក្សរ សំឡេង និងវីដេអូភ្ជាប់តាម iroh។ អ្នកនៅក្នុងការជជែកមិនបាច់ផ្លាស់អាសយដ្ឋាន។';

  @override
  String get talkWith => 'ជជែក';

  @override
  String get whoDriver => 'អ្នកបើក';

  @override
  String get whoCustomer => 'អតិថិជន';

  @override
  String yourPrice(String who) {
    return 'តម្លៃ$who';
  }

  @override
  String proposedBy(String who, String price) {
    return '$who ស្នើ $price។ តម្លៃកម្មវិធីនៅអនុវត្តរហូតដល់ម្ខាងទៀតយល់ព្រម។';
  }

  @override
  String get agreedPrice => 'តម្លៃព្រមព្រៀង';

  @override
  String priceAllowed(String price) {
    return 'យល់ព្រម $price';
  }

  @override
  String get priceInChat => 'តម្លៃចរចានៅទីនេះ។ ម្ខាងស្នើ ម្ខាងទៀតយល់ព្រម។';

  @override
  String get roadRouted => 'ចម្ងាយតាមផ្លូវ និងចរាចរណ៍ថ្ងៃនេះ។';

  @override
  String get rentLength => 'រយៈពេល';

  @override
  String rentHours(int n) {
    return '$n ម៉ោង';
  }

  @override
  String rentDays(int n) {
    return '$n ថ្ងៃ';
  }

  @override
  String rentWeeks(int n) {
    return '$n សប្តាហ៍';
  }

  @override
  String get authMoreWays => 'វិធីផ្សេងទៀត';

  @override
  String get authFewerWays => 'បង្រួម';

  @override
  String get counterFare => 'តថ្លៃវិញ';

  @override
  String get endFare => 'បញ្ចប់ការតថ្លៃ';

  @override
  String fareEnded(String price) {
    return 'ការតថ្លៃបានបញ្ចប់។ អនុវត្ត $price។';
  }

  @override
  String get fareYourTurn => 'ការស្នើរបស់ម្ខាងទៀត។ យល់ព្រម តថ្លៃវិញ ឬបញ្ចប់។';

  @override
  String get trainAll => 'ខ្ញុំបានបញ្ចប់ការបណ្តុះបណ្តាលទាំងបួន';

  @override
  String get signupReady => 'គ្រប់គ្រាន់ហើយ។ រក្សាទុកដើម្បីទទួលលេខបុគ្គលិក។';

  @override
  String signupNext(String step) {
    return 'បន្ទាប់៖ $step';
  }

  @override
  String talkInCall(String name, String kind) {
    return '$name បានចាប់ផ្ដើម $kind';
  }
}
