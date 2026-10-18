import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_km.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('km'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In km, this message translates to:
  /// **'Leca'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In km, this message translates to:
  /// **'ថោកជាង · គុណភាពខ្ពស់ · គ្មានដែនកំណត់ឆោត'**
  String get tagline;

  /// No description provided for @languageToggle.
  ///
  /// In km, this message translates to:
  /// **'EN'**
  String get languageToggle;

  /// No description provided for @cityPhnomPenh.
  ///
  /// In km, this message translates to:
  /// **'ភ្នំពេញ'**
  String get cityPhnomPenh;

  /// No description provided for @citySiemReap.
  ///
  /// In km, this message translates to:
  /// **'សៀមរាប'**
  String get citySiemReap;

  /// No description provided for @serviceFood.
  ///
  /// In km, this message translates to:
  /// **'អាហារ'**
  String get serviceFood;

  /// No description provided for @serviceSend.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើអ្វីក៏បាន'**
  String get serviceSend;

  /// No description provided for @serviceRides.
  ///
  /// In km, this message translates to:
  /// **'ជិះ'**
  String get serviceRides;

  /// No description provided for @serviceRent.
  ///
  /// In km, this message translates to:
  /// **'ជួលយាន'**
  String get serviceRent;

  /// No description provided for @bornInCambodia.
  ///
  /// In km, this message translates to:
  /// **'គ្រប់ក្រុង ឃុំ និងភូមិក្នុងកម្ពុជា។'**
  String get bornInCambodia;

  /// No description provided for @searchHint.
  ///
  /// In km, this message translates to:
  /// **'ស្វែងរកម្ហូប ឬភោជនីយដ្ឋាន'**
  String get searchHint;

  /// No description provided for @popularTitle.
  ///
  /// In km, this message translates to:
  /// **'ម្ហូបពេញនិយមក្នុងចម្ងាយ {km} គីឡូម៉ែត្រ'**
  String popularTitle(int km);

  /// No description provided for @radiusCountry.
  ///
  /// In km, this message translates to:
  /// **'ទូទាំងកម្ពុជា'**
  String get radiusCountry;

  /// No description provided for @popularCountry.
  ///
  /// In km, this message translates to:
  /// **'ម្ហូបពេញនិយមទូទាំងកម្ពុជា'**
  String get popularCountry;

  /// No description provided for @radiusLabel.
  ///
  /// In km, this message translates to:
  /// **'{km} គីឡូម៉ែត្រ'**
  String radiusLabel(int km);

  /// No description provided for @windowHour.
  ///
  /// In km, this message translates to:
  /// **'ម៉ោងនេះ'**
  String get windowHour;

  /// No description provided for @windowDay.
  ///
  /// In km, this message translates to:
  /// **'ថ្ងៃនេះ'**
  String get windowDay;

  /// No description provided for @windowWeek.
  ///
  /// In km, this message translates to:
  /// **'សប្ដាហ៍នេះ'**
  String get windowWeek;

  /// No description provided for @windowMonth.
  ///
  /// In km, this message translates to:
  /// **'ខែនេះ'**
  String get windowMonth;

  /// No description provided for @popularOrders.
  ///
  /// In km, this message translates to:
  /// **'{count} ការកម្មង់'**
  String popularOrders(int count);

  /// No description provided for @popularEmpty.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានទិន្នន័យសម្រាប់ពេលនេះទេ'**
  String get popularEmpty;

  /// No description provided for @feePromise.
  ///
  /// In km, this message translates to:
  /// **'ថ្លៃសេវា ៥% · ថ្លៃដឹកចាប់ពី {price}'**
  String feePromise(String price);

  /// No description provided for @etaMins.
  ///
  /// In km, this message translates to:
  /// **'{mins} នាទី'**
  String etaMins(int mins);

  /// No description provided for @deliveryFrom.
  ///
  /// In km, this message translates to:
  /// **'ដឹក {price}'**
  String deliveryFrom(String price);

  /// No description provided for @loadingPlaces.
  ///
  /// In km, this message translates to:
  /// **'កំពុងផ្ទុកភោជនីយដ្ឋាន…'**
  String get loadingPlaces;

  /// No description provided for @emptySearchTitle.
  ///
  /// In km, this message translates to:
  /// **'រកមិនឃើញ'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchBody.
  ///
  /// In km, this message translates to:
  /// **'គ្មានអ្វីក្នុងរង្វង់នេះទេ។ បង្កើនចំនួនគីឡូម៉ែត្រ។'**
  String get emptySearchBody;

  /// No description provided for @catalogError.
  ///
  /// In km, this message translates to:
  /// **'មិនអាចផ្ទុកភោជនីយដ្ឋានបានទេ។'**
  String get catalogError;

  /// No description provided for @retry.
  ///
  /// In km, this message translates to:
  /// **'ព្យាយាមម្ដងទៀត'**
  String get retry;

  /// No description provided for @add.
  ///
  /// In km, this message translates to:
  /// **'បន្ថែម'**
  String get add;

  /// No description provided for @cart.
  ///
  /// In km, this message translates to:
  /// **'រទេះ'**
  String get cart;

  /// No description provided for @cartItems.
  ///
  /// In km, this message translates to:
  /// **'{count} មុខ'**
  String cartItems(int count);

  /// No description provided for @checkout.
  ///
  /// In km, this message translates to:
  /// **'បញ្ជាទិញ'**
  String get checkout;

  /// No description provided for @emptyCartTitle.
  ///
  /// In km, this message translates to:
  /// **'រទេះទទេ'**
  String get emptyCartTitle;

  /// No description provided for @emptyCartBody.
  ///
  /// In km, this message translates to:
  /// **'ជ្រើសម្ហូបសិន រួចត្រឡប់មកបង់ប្រាក់។'**
  String get emptyCartBody;

  /// No description provided for @backToFood.
  ///
  /// In km, this message translates to:
  /// **'ត្រឡប់ទៅអាហារ'**
  String get backToFood;

  /// No description provided for @noteLabel.
  ///
  /// In km, this message translates to:
  /// **'កំណត់ចំណាំការកម្មង់'**
  String get noteLabel;

  /// No description provided for @noteHint.
  ///
  /// In km, this message translates to:
  /// **'ឧទាហរណ៍៖ មិនដាក់ទឹកស៊ីអ៊ីវ បន្ថែមម្ទេស'**
  String get noteHint;

  /// No description provided for @amountLabel.
  ///
  /// In km, this message translates to:
  /// **'ចំនួនទឹកប្រាក់'**
  String get amountLabel;

  /// No description provided for @subtotal.
  ///
  /// In km, this message translates to:
  /// **'ម្ហូប'**
  String get subtotal;

  /// No description provided for @deliveryFee.
  ///
  /// In km, this message translates to:
  /// **'ថ្លៃដឹក'**
  String get deliveryFee;

  /// No description provided for @serviceFee.
  ///
  /// In km, this message translates to:
  /// **'ថ្លៃសេវា'**
  String get serviceFee;

  /// No description provided for @serviceFeeNone.
  ///
  /// In km, this message translates to:
  /// **'៥% នៃការលក់នេះ។'**
  String get serviceFeeNone;

  /// No description provided for @driverMinutes.
  ///
  /// In km, this message translates to:
  /// **'{name} នៅចម្ងាយ {minutes} នាទី'**
  String driverMinutes(String name, int minutes);

  /// No description provided for @deliveryMinutes.
  ///
  /// In km, this message translates to:
  /// **'ការដឹកនៅចម្ងាយ {minutes} នាទី'**
  String deliveryMinutes(int minutes);

  /// No description provided for @total.
  ///
  /// In km, this message translates to:
  /// **'សរុប'**
  String get total;

  /// No description provided for @payTitle.
  ///
  /// In km, this message translates to:
  /// **'បង់ប្រាក់'**
  String get payTitle;

  /// No description provided for @scanToPay.
  ///
  /// In km, this message translates to:
  /// **'ស្កេនកូដ QR ដើម្បីបង់'**
  String get scanToPay;

  /// No description provided for @payWith.
  ///
  /// In km, this message translates to:
  /// **'បង់តាម'**
  String get payWith;

  /// No description provided for @stripePay.
  ///
  /// In km, this message translates to:
  /// **'បង់តាម Stripe'**
  String get stripePay;

  /// No description provided for @stripeHint.
  ///
  /// In km, this message translates to:
  /// **'Stripe Checkout សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay។ ដាក់ STRIPE_PK ពេលមានសោពិត។'**
  String get stripeHint;

  /// No description provided for @stripeHintLive.
  ///
  /// In km, this message translates to:
  /// **'Stripe រួចរាល់សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay — ស្កេន ឬប៉ះដើម្បីបង់។'**
  String get stripeHintLive;

  /// No description provided for @stripeBrands.
  ///
  /// In km, this message translates to:
  /// **'Visa · Mastercard · Discover · UnionPay · Alipay'**
  String get stripeBrands;

  /// No description provided for @khqrHint.
  ///
  /// In km, this message translates to:
  /// **'ស្កេនដោយ {bank} ឬ Bakong។ KHQR បង្កើតក្នុងឧបករណ៍ — មិនទាន់ភ្ជាប់គណនីពិត។'**
  String khqrHint(String bank);

  /// No description provided for @otherHint.
  ///
  /// In km, this message translates to:
  /// **'QR ទូទៅ សម្រាប់កម្មវិធីស្កេនផ្សេង។'**
  String get otherHint;

  /// No description provided for @loadingQr.
  ///
  /// In km, this message translates to:
  /// **'កំពុងបង្កើតកូដ QR…'**
  String get loadingQr;

  /// No description provided for @errorQr.
  ///
  /// In km, this message translates to:
  /// **'មិនអាចបង្កើតកូដ QR បានទេ។'**
  String get errorQr;

  /// No description provided for @invalidAmount.
  ///
  /// In km, this message translates to:
  /// **'ចំនួនទឹកប្រាក់មិនត្រឹមត្រូវ។'**
  String get invalidAmount;

  /// No description provided for @iPaid.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានបង់ហើយ'**
  String get iPaid;

  /// No description provided for @paidTitle.
  ///
  /// In km, this message translates to:
  /// **'បានទទួលការកម្មង់'**
  String get paidTitle;

  /// No description provided for @paidBody.
  ///
  /// In km, this message translates to:
  /// **'រក្សាវិក្កយបត្រក្នុងកម្មវិធីធនាគារ។ Leca មិនកាន់ប្រាក់នេះទេ។'**
  String get paidBody;

  /// No description provided for @close.
  ///
  /// In km, this message translates to:
  /// **'បិទ'**
  String get close;

  /// No description provided for @sendTitle.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើអ្វីក៏បាន'**
  String get sendTitle;

  /// No description provided for @sendBody.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើកញ្ចប់ ឯកសារ ម្ហូប ឬអ្វីដែលស្របច្បាប់។ អ្នកណាក៏អាចដឹកបាន។'**
  String get sendBody;

  /// No description provided for @sendAnythingTitle.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើឥឡូវ'**
  String get sendAnythingTitle;

  /// No description provided for @sendAnythingDetail.
  ///
  /// In km, this message translates to:
  /// **'គ្មានប្រភេទហាមឃាត់លើកលែងតែច្បាប់។'**
  String get sendAnythingDetail;

  /// No description provided for @ridesTitle.
  ///
  /// In km, this message translates to:
  /// **'ជិះ'**
  String get ridesTitle;

  /// No description provided for @ridesBody.
  ///
  /// In km, this message translates to:
  /// **'កក់ការជិះ។ យានស្របច្បាប់ណាក៏បាន ទាំងមានអ្នកបើក និងបើកផ្ទាល់។'**
  String get ridesBody;

  /// No description provided for @rentBody.
  ///
  /// In km, this message translates to:
  /// **'ជួលយានធម្មតា ឬស្វយ័ត។ បញ្ជីខាងក្រោមជាឧទាហរណ៍ មិនមែនបញ្ជីបិទ។'**
  String get rentBody;

  /// No description provided for @regularVehicles.
  ///
  /// In km, this message translates to:
  /// **'យានធម្មតា'**
  String get regularVehicles;

  /// No description provided for @autonomousVehicles.
  ///
  /// In km, this message translates to:
  /// **'យានស្វយ័ត'**
  String get autonomousVehicles;

  /// No description provided for @autonomousHint.
  ///
  /// In km, this message translates to:
  /// **'គ្មានអ្នកបើក — រថយន្តបើកដោយខ្លួនឯង។'**
  String get autonomousHint;

  /// No description provided for @withOrWithoutDriver.
  ///
  /// In km, this message translates to:
  /// **'មានអ្នកបើក ឬបើកផ្ទាល់'**
  String get withOrWithoutDriver;

  /// No description provided for @vehicleExamplesNote.
  ///
  /// In km, this message translates to:
  /// **'ឧទាហរណ៍ — យានស្របច្បាប់ផ្សេងទៀតអាចជួលបាន ទាំងមានអ្នកបើក និងគ្មាន។'**
  String get vehicleExamplesNote;

  /// No description provided for @ok.
  ///
  /// In km, this message translates to:
  /// **'យល់ព្រម'**
  String get ok;

  /// No description provided for @authMockBanner.
  ///
  /// In km, this message translates to:
  /// **'មុខ ឬ passkey គឺជាវិធីចូលលឿនបំផុត។ បើគ្មានម៉ាស៊ីនមេ ឧបករណ៍នេះប្រើការសាកល្បងក្នុងម៉ាស៊ីន។'**
  String get authMockBanner;

  /// No description provided for @authLiveBanner.
  ///
  /// In km, this message translates to:
  /// **'មុខ ឬ passkey គឺជាវិធីចូលលឿនបំផុត។'**
  String get authLiveBanner;

  /// No description provided for @authOtherWays.
  ///
  /// In km, this message translates to:
  /// **'វិធីផ្សេង'**
  String get authOtherWays;

  /// No description provided for @authTelegram.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Telegram (សាកល្បង)'**
  String get authTelegram;

  /// No description provided for @authTelegramLive.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Telegram'**
  String get authTelegramLive;

  /// No description provided for @authX.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ X (សាកល្បង)'**
  String get authX;

  /// No description provided for @authXLive.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ X'**
  String get authXLive;

  /// No description provided for @authWhatsappLabel.
  ///
  /// In km, this message translates to:
  /// **'WhatsApp'**
  String get authWhatsappLabel;

  /// No description provided for @authWhatsappSend.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើលេខកូដ WhatsApp'**
  String get authWhatsappSend;

  /// No description provided for @authWhatsappUnconfigured.
  ///
  /// In km, this message translates to:
  /// **'ម៉ាស៊ីនមិនទាន់កំណត់ការចូល WhatsApp ទេ។'**
  String get authWhatsappUnconfigured;

  /// No description provided for @authWechat.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ WeChat (សាកល្បង)'**
  String get authWechat;

  /// No description provided for @authWechatLive.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ WeChat'**
  String get authWechatLive;

  /// No description provided for @authDevCode.
  ///
  /// In km, this message translates to:
  /// **'លេខកូដសាកល្បង'**
  String get authDevCode;

  /// No description provided for @authProviderUnconfigured.
  ///
  /// In km, this message translates to:
  /// **'ម៉ាស៊ីនមិនទាន់កំណត់ការចូលនេះទេ។'**
  String get authProviderUnconfigured;

  /// No description provided for @authSmsUnconfigured.
  ///
  /// In km, this message translates to:
  /// **'ម៉ាស៊ីនមិនទាន់កំណត់ការចូលដោយទូរស័ព្ទទេ។'**
  String get authSmsUnconfigured;

  /// No description provided for @authPhoneInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខទូរស័ព្ទយ៉ាងតិច ៨ ខ្ទង់។'**
  String get authPhoneInvalid;

  /// No description provided for @authCodeInvalid.
  ///
  /// In km, this message translates to:
  /// **'លេខកូដមិនត្រឹមត្រូវ។'**
  String get authCodeInvalid;

  /// No description provided for @authHandleEmpty.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលគណនី។'**
  String get authHandleEmpty;

  /// No description provided for @authFailed.
  ///
  /// In km, this message translates to:
  /// **'មិនអាចចូលបានទេ។'**
  String get authFailed;

  /// No description provided for @authGoogle.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Google (សាកល្បង)'**
  String get authGoogle;

  /// No description provided for @authGoogleLive.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Google'**
  String get authGoogleLive;

  /// No description provided for @authFacebook.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Facebook (សាកល្បង)'**
  String get authFacebook;

  /// No description provided for @authFacebookLive.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ Facebook'**
  String get authFacebookLive;

  /// No description provided for @authPhoneLabel.
  ///
  /// In km, this message translates to:
  /// **'លេខទូរស័ព្ទ'**
  String get authPhoneLabel;

  /// No description provided for @authPhoneHint.
  ///
  /// In km, this message translates to:
  /// **'០១២ ៣៤៥ ៦៧៨'**
  String get authPhoneHint;

  /// No description provided for @authCodeHint.
  ///
  /// In km, this message translates to:
  /// **'លេខកូដ ៤ ខ្ទង់'**
  String get authCodeHint;

  /// No description provided for @authVerify.
  ///
  /// In km, this message translates to:
  /// **'ផ្ទៀងផ្ទាត់'**
  String get authVerify;

  /// No description provided for @authSendCode.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើលេខកូដ'**
  String get authSendCode;

  /// No description provided for @authEmailLabel.
  ///
  /// In km, this message translates to:
  /// **'អ៊ីមែល'**
  String get authEmailLabel;

  /// No description provided for @authEmailHint.
  ///
  /// In km, this message translates to:
  /// **'you@example.com'**
  String get authEmailHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In km, this message translates to:
  /// **'ពាក្យសម្ងាត់ យ៉ាងតិច ៨ តួ'**
  String get authPasswordHint;

  /// No description provided for @authNameHint.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះរបស់អ្នក'**
  String get authNameHint;

  /// No description provided for @authKeyLabel.
  ///
  /// In km, this message translates to:
  /// **'ឧបករណ៍នេះ'**
  String get authKeyLabel;

  /// No description provided for @authKeyExplain.
  ///
  /// In km, this message translates to:
  /// **'ឧបករណ៍នេះរក្សាសោ ដែលអ្នកដទៃប្រើដើម្បីនិយាយផ្ទាល់។ ឈ្មោះមិនបាច់មានទេ។'**
  String get authKeyExplain;

  /// No description provided for @authKeyNameHint.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះ បើចង់ដាក់'**
  String get authKeyNameHint;

  /// No description provided for @authKeySignIn.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយឧបករណ៍នេះ'**
  String get authKeySignIn;

  /// No description provided for @authFace.
  ///
  /// In km, this message translates to:
  /// **'បន្តដោយមុខ'**
  String get authFace;

  /// No description provided for @authFaceUnavailable.
  ///
  /// In km, this message translates to:
  /// **'ឧបករណ៍នេះមិនមានការស្គាល់មុខទេ។'**
  String get authFaceUnavailable;

  /// No description provided for @authFaceDenied.
  ///
  /// In km, this message translates to:
  /// **'ការស្គាល់មុខត្រូវបានបដិសេធ។'**
  String get authFaceDenied;

  /// No description provided for @authPasskey.
  ///
  /// In km, this message translates to:
  /// **'បន្តជាមួយ passkey'**
  String get authPasskey;

  /// No description provided for @authPasskeyUnavailable.
  ///
  /// In km, this message translates to:
  /// **'ឧបករណ៍នេះមិនមាន passkey ទេ។'**
  String get authPasskeyUnavailable;

  /// No description provided for @authPasskeyCancelled.
  ///
  /// In km, this message translates to:
  /// **'ការចូលដោយ passkey ត្រូវបានបោះបង់។'**
  String get authPasskeyCancelled;

  /// No description provided for @authEmailSignIn.
  ///
  /// In km, this message translates to:
  /// **'ចូលដោយអ៊ីមែល'**
  String get authEmailSignIn;

  /// No description provided for @authCreateAccount.
  ///
  /// In km, this message translates to:
  /// **'បង្កើតគណនី'**
  String get authCreateAccount;

  /// No description provided for @authNeedAccount.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានគណនី?'**
  String get authNeedAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In km, this message translates to:
  /// **'មានគណនីហើយ?'**
  String get authHaveAccount;

  /// No description provided for @authEmailInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលអ៊ីមែលឲ្យបានត្រឹមត្រូវ។'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordShort.
  ///
  /// In km, this message translates to:
  /// **'ពាក្យសម្ងាត់ត្រូវមានយ៉ាងតិច ៨ តួ។'**
  String get authPasswordShort;

  /// No description provided for @authEmailTaken.
  ///
  /// In km, this message translates to:
  /// **'អ៊ីមែលនេះមានគណនីហើយ។'**
  String get authEmailTaken;

  /// No description provided for @authCredentialsInvalid.
  ///
  /// In km, this message translates to:
  /// **'អ៊ីមែល ឬពាក្យសម្ងាត់មិនត្រឹមត្រូវ។'**
  String get authCredentialsInvalid;

  /// No description provided for @deskLead.
  ///
  /// In km, this message translates to:
  /// **'គ្រប់គ្រងទំនិញ តម្លៃ និងហាង។ កុំព្យូទ័រនេះអាចទទួលការដឹកបាន។ វាមិនចេញទៅដឹកទេ។'**
  String get deskLead;

  /// No description provided for @deskOrder.
  ///
  /// In km, this message translates to:
  /// **'ទទួលការដឹក'**
  String get deskOrder;

  /// No description provided for @deliverTo.
  ///
  /// In km, this message translates to:
  /// **'ដឹកទៅ'**
  String get deliverTo;

  /// No description provided for @accountTitle.
  ///
  /// In km, this message translates to:
  /// **'គណនី'**
  String get accountTitle;

  /// No description provided for @earnTitle.
  ///
  /// In km, this message translates to:
  /// **'រកប្រាក់ជាមួយ Leca'**
  String get earnTitle;

  /// No description provided for @earnBody.
  ///
  /// In km, this message translates to:
  /// **'បើកអាជីវកម្មស្របច្បាប់ណាក៏បាន បើកបរ ឬដាក់យានឲ្យជួល។ មួយកម្មវិធី — មិនមែនកម្មវិធីអ្នកបើកដាច់ដោយឡែក។'**
  String get earnBody;

  /// No description provided for @openBusiness.
  ///
  /// In km, this message translates to:
  /// **'បើកអាជីវកម្ម'**
  String get openBusiness;

  /// No description provided for @driveCta.
  ///
  /// In km, this message translates to:
  /// **'បើកបរ'**
  String get driveCta;

  /// No description provided for @listVehicle.
  ///
  /// In km, this message translates to:
  /// **'ដាក់យាន'**
  String get listVehicle;

  /// No description provided for @myBusinesses.
  ///
  /// In km, this message translates to:
  /// **'អាជីវកម្មរបស់ខ្ញុំ'**
  String get myBusinesses;

  /// No description provided for @emptyBusinesses.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានអាជីវកម្ម។'**
  String get emptyBusinesses;

  /// No description provided for @myVehicles.
  ///
  /// In km, this message translates to:
  /// **'យានរបស់ខ្ញុំ'**
  String get myVehicles;

  /// No description provided for @emptyVehicles.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានយានដាក់។'**
  String get emptyVehicles;

  /// No description provided for @withDriver.
  ///
  /// In km, this message translates to:
  /// **'មានអ្នកបើក'**
  String get withDriver;

  /// No description provided for @selfDrive.
  ///
  /// In km, this message translates to:
  /// **'បើកផ្ទាល់'**
  String get selfDrive;

  /// No description provided for @drivingOn.
  ///
  /// In km, this message translates to:
  /// **'អ្នកកំពុងនៅលើបណ្ដាញ — អាចទទួលការជិះ'**
  String get drivingOn;

  /// No description provided for @drivingOff.
  ///
  /// In km, this message translates to:
  /// **'អ្នកនៅក្រៅបណ្ដាញ'**
  String get drivingOff;

  /// No description provided for @signOut.
  ///
  /// In km, this message translates to:
  /// **'ចាកចេញ'**
  String get signOut;

  /// No description provided for @businessKindHint.
  ///
  /// In km, this message translates to:
  /// **'ភោជនីយដ្ឋាន កុំព្យូទ័រ ទំនិញទារក ឱសថស្ថាន ឬប្រភេទស្របច្បាប់ណាក៏បាន។ មិនមែនបញ្ជីបិទ។'**
  String get businessKindHint;

  /// No description provided for @businessKind.
  ///
  /// In km, this message translates to:
  /// **'ប្រភេទអាជីវកម្ម'**
  String get businessKind;

  /// No description provided for @businessName.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះអាជីវកម្ម'**
  String get businessName;

  /// No description provided for @businessInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលប្រភេទ និងឈ្មោះ។'**
  String get businessInvalid;

  /// No description provided for @saveBusiness.
  ///
  /// In km, this message translates to:
  /// **'រក្សាទុកអាជីវកម្ម'**
  String get saveBusiness;

  /// No description provided for @driveBody.
  ///
  /// In km, this message translates to:
  /// **'ចូលបណ្ដាញបានបន្ទាប់ពីឯកសារដៃគូ និងការបណ្ដុះបណ្ដាលគ្រប់។ អ្នកជាដៃគូឯករាជ្យ មិនមែននិយោជិត។'**
  String get driveBody;

  /// No description provided for @driveVehicleNote.
  ///
  /// In km, this message translates to:
  /// **'យានដែលអ្នកបើក (ឧ. ទូកទូក)'**
  String get driveVehicleNote;

  /// No description provided for @goOnline.
  ///
  /// In km, this message translates to:
  /// **'ចូលបណ្ដាញ'**
  String get goOnline;

  /// No description provided for @listVehicleBody.
  ///
  /// In km, this message translates to:
  /// **'ដាក់យានដែលអ្នកជាម្ចាស់។ ប្រភេទស្របច្បាប់ណាក៏បាន មានអ្នកបើក ឬបើកផ្ទាល់។'**
  String get listVehicleBody;

  /// No description provided for @vehicleKind.
  ///
  /// In km, this message translates to:
  /// **'ប្រភេទយាន'**
  String get vehicleKind;

  /// No description provided for @autonomousToggle.
  ///
  /// In km, this message translates to:
  /// **'ស្វយ័ត'**
  String get autonomousToggle;

  /// No description provided for @vehicleInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលប្រភេទយាន។'**
  String get vehicleInvalid;

  /// No description provided for @saveVehicle.
  ///
  /// In km, this message translates to:
  /// **'រក្សាទុកយាន'**
  String get saveVehicle;

  /// No description provided for @jobsCta.
  ///
  /// In km, this message translates to:
  /// **'ទទួលការងារ'**
  String get jobsCta;

  /// No description provided for @jobsTitle.
  ///
  /// In km, this message translates to:
  /// **'ការងារ'**
  String get jobsTitle;

  /// No description provided for @jobsBody.
  ///
  /// In km, this message translates to:
  /// **'ទទួលការជិះ ដឹកម្ហូប ផ្ញើអ្វីស្របច្បាប់។ មិនមែនបញ្ជីបិទ។'**
  String get jobsBody;

  /// No description provided for @jobsOffline.
  ///
  /// In km, this message translates to:
  /// **'ចូលបណ្ដាញសិន រួចទទួលការងារ។'**
  String get jobsOffline;

  /// No description provided for @emptyJobs.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានការងារបើក។'**
  String get emptyJobs;

  /// No description provided for @emptyAcceptedJobs.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានការងារបានទទួល។'**
  String get emptyAcceptedJobs;

  /// No description provided for @loadingJobs.
  ///
  /// In km, this message translates to:
  /// **'កំពុងផ្ទុកការងារ…'**
  String get loadingJobs;

  /// No description provided for @jobsError.
  ///
  /// In km, this message translates to:
  /// **'មិនអាចផ្ទុកការងារបានទេ។'**
  String get jobsError;

  /// No description provided for @acceptJob.
  ///
  /// In km, this message translates to:
  /// **'ទទួល'**
  String get acceptJob;

  /// No description provided for @declineJob.
  ///
  /// In km, this message translates to:
  /// **'បដិសេធ'**
  String get declineJob;

  /// No description provided for @jobAccepted.
  ///
  /// In km, this message translates to:
  /// **'បានទទួល'**
  String get jobAccepted;

  /// No description provided for @jobDeclined.
  ///
  /// In km, this message translates to:
  /// **'បានបដិសេធ'**
  String get jobDeclined;

  /// No description provided for @acceptedJobs.
  ///
  /// In km, this message translates to:
  /// **'ការងារបានទទួល'**
  String get acceptedJobs;

  /// No description provided for @openJobs.
  ///
  /// In km, this message translates to:
  /// **'ការងារបើក'**
  String get openJobs;

  /// No description provided for @driverSignup.
  ///
  /// In km, this message translates to:
  /// **'ចុះឈ្មោះអ្នកបើក'**
  String get driverSignup;

  /// No description provided for @driverSignupBody.
  ///
  /// In km, this message translates to:
  /// **'រូបមុខ និងអត្តសញ្ញាណប័ណ្ណត្រូវត្រូវគ្នា។ នៅកម្ពុជា ត្រូវមានប័ណ្ណបើកបរកម្ពុជា ផ្លាក បណ្ណសម្គាល់យាន ធានារ៉ាប់រងពាណិជ្ជកម្ម ស្លាក Leca និងការបណ្ដុះបណ្ដាល។ ម៉ូតូមិនត្រូវការលិខិតត្រួតពិនិត្យ និងវិញ្ញាបនបត្រដឹកជញ្ជូនទេ។ ទូកទូក និងរម៉កមិនត្រូវការវិញ្ញាបនបត្រដឹកជញ្ជូនទេ។'**
  String get driverSignupBody;

  /// No description provided for @legalName.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះពេញ'**
  String get legalName;

  /// No description provided for @nameOnId.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះលើអត្តសញ្ញាណប័ណ្ណ'**
  String get nameOnId;

  /// No description provided for @idNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខអត្តសញ្ញាណ'**
  String get idNumber;

  /// No description provided for @selfiePhoto.
  ///
  /// In km, this message translates to:
  /// **'រូបមុខ'**
  String get selfiePhoto;

  /// No description provided for @idCardPhoto.
  ///
  /// In km, this message translates to:
  /// **'អត្តសញ្ញាណប័ណ្ណ'**
  String get idCardPhoto;

  /// No description provided for @pickPhoto.
  ///
  /// In km, this message translates to:
  /// **'បន្ថែមរូប'**
  String get pickPhoto;

  /// No description provided for @saveDriver.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើ'**
  String get saveDriver;

  /// No description provided for @driverVerified.
  ///
  /// In km, this message translates to:
  /// **'អត្តសញ្ញាណបានផ្ទៀងផ្ទាត់'**
  String get driverVerified;

  /// No description provided for @driverUnverified.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់ផ្ទៀងផ្ទាត់អត្តសញ្ញាណ'**
  String get driverUnverified;

  /// No description provided for @identityNameMismatch.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះមិនដូចនឹងលើអត្តសញ្ញាណប័ណ្ណ។'**
  String get identityNameMismatch;

  /// No description provided for @identityIdInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខអត្តសញ្ញាណយ៉ាងតិច ៦ ខ្ទង់។'**
  String get identityIdInvalid;

  /// No description provided for @identityPhotoInvalid.
  ///
  /// In km, this message translates to:
  /// **'ប្រើរូបពិត — JPEG, PNG ឬ WebP។'**
  String get identityPhotoInvalid;

  /// No description provided for @identityPhotoSame.
  ///
  /// In km, this message translates to:
  /// **'រូបមុខ និងអត្តសញ្ញាណប័ណ្ណត្រូវខុសគ្នា។'**
  String get identityPhotoSame;

  /// No description provided for @identityPhotoMissing.
  ///
  /// In km, this message translates to:
  /// **'បន្ថែមរូបទាំងពីរ។'**
  String get identityPhotoMissing;

  /// No description provided for @chat.
  ///
  /// In km, this message translates to:
  /// **'ជជែក'**
  String get chat;

  /// No description provided for @chatHint.
  ///
  /// In km, this message translates to:
  /// **'សារ'**
  String get chatHint;

  /// No description provided for @sendMessage.
  ///
  /// In km, this message translates to:
  /// **'ផ្ញើ'**
  String get sendMessage;

  /// No description provided for @replyAsBusiness.
  ///
  /// In km, this message translates to:
  /// **'ឆ្លើយជាអាជីវកម្ម'**
  String get replyAsBusiness;

  /// No description provided for @emptyChat.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានសារ។ អាចសរសេរបានតាំងពីថ្ងៃដំបូង។'**
  String get emptyChat;

  /// No description provided for @replyFast.
  ///
  /// In km, this message translates to:
  /// **'ឆ្លើយរហ័ស'**
  String get replyFast;

  /// No description provided for @replySlow.
  ///
  /// In km, this message translates to:
  /// **'ឆ្លើយយឺត'**
  String get replySlow;

  /// No description provided for @replyNew.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានពេលឆ្លើយ'**
  String get replyNew;

  /// No description provided for @workingHours.
  ///
  /// In km, this message translates to:
  /// **'ម៉ោងធ្វើការ {open}–{close}'**
  String workingHours(String open, String close);

  /// No description provided for @addItem.
  ///
  /// In km, this message translates to:
  /// **'បន្ថែមទំនិញ'**
  String get addItem;

  /// No description provided for @itemDescription.
  ///
  /// In km, this message translates to:
  /// **'ការពិពណ៌នាខ្លី'**
  String get itemDescription;

  /// No description provided for @itemPrice.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃ (USD)'**
  String get itemPrice;

  /// No description provided for @saveItem.
  ///
  /// In km, this message translates to:
  /// **'រក្សាទុកទំនិញ'**
  String get saveItem;

  /// No description provided for @itemInvalid.
  ///
  /// In km, this message translates to:
  /// **'បន្ថែមរូប ការពិពណ៌នាខ្លី និងតម្លៃ។'**
  String get itemInvalid;

  /// No description provided for @emptyItems.
  ///
  /// In km, this message translates to:
  /// **'មិនទាន់មានទំនិញ។'**
  String get emptyItems;

  /// No description provided for @forSale.
  ///
  /// In km, this message translates to:
  /// **'លក់'**
  String get forSale;

  /// No description provided for @forRent.
  ///
  /// In km, this message translates to:
  /// **'ជួល'**
  String get forRent;

  /// No description provided for @appPrice.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃកម្មវិធី'**
  String get appPrice;

  /// No description provided for @driverPrice.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃអ្នកបើក'**
  String get driverPrice;

  /// No description provided for @proposeFare.
  ///
  /// In km, this message translates to:
  /// **'ស្នើ'**
  String get proposeFare;

  /// No description provided for @allowFare.
  ///
  /// In km, this message translates to:
  /// **'យល់ព្រមតម្លៃនេះ'**
  String get allowFare;

  /// No description provided for @fareWaiting.
  ///
  /// In km, this message translates to:
  /// **'អ្នកជិះមិនទាន់យល់ព្រមតម្លៃនេះ។ តម្លៃកម្មវិធីនៅតែប្រើ។'**
  String get fareWaiting;

  /// No description provided for @saleHint.
  ///
  /// In km, this message translates to:
  /// **'ឡាន ម៉ូតូ កង់ ទូកទូក — ជួល ឬទិញ មានអ្នកបើក ឬអត់។'**
  String get saleHint;

  /// No description provided for @shopTitle.
  ///
  /// In km, this message translates to:
  /// **'ហាង'**
  String get shopTitle;

  /// No description provided for @ridesPartnerBody.
  ///
  /// In km, this message translates to:
  /// **'ការជិះផ្គូផ្គងជាមួយអ្នកបើកកម្ពុជាឯករាជ្យ។ Leca មិនកាន់កាប់យានទេ។ តម្លៃបង្ហាញមុន ហើយមិនបញ្ចុះក្រោយពេលអ្នកជិះយល់ព្រម។'**
  String get ridesPartnerBody;

  /// No description provided for @rentPartnerBody.
  ///
  /// In km, this message translates to:
  /// **'ជួល ឬទិញយានដែលម្ចាស់ដាក់ឯង។ Leca មិនដំណើរការកងយានទេ។'**
  String get rentPartnerBody;

  /// No description provided for @rentExamplesKh.
  ///
  /// In km, this message translates to:
  /// **'ឧទាហរណ៍យានរបស់ដៃគូ។ Leca មិនកាន់កាប់ និងមិនដំណើរការយានទេ។'**
  String get rentExamplesKh;

  /// No description provided for @platformFleetBlocked.
  ///
  /// In km, this message translates to:
  /// **'Leca មិនដំណើរការយានស្វយ័ត ឬកងយានផ្ទាល់ខ្លួននៅកម្ពុជាទេ។'**
  String get platformFleetBlocked;

  /// No description provided for @ownerConfirm.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំជាម្ចាស់យាននេះ។ Leca មិនមែនម្ចាស់។'**
  String get ownerConfirm;

  /// No description provided for @ownerRequired.
  ///
  /// In km, this message translates to:
  /// **'បញ្ជាក់ថាអ្នកជាម្ចាស់យាន។'**
  String get ownerRequired;

  /// No description provided for @licenceNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខប័ណ្ណបើកបរកម្ពុជា'**
  String get licenceNumber;

  /// No description provided for @plateNumber.
  ///
  /// In km, this message translates to:
  /// **'ផ្លាកលេខ'**
  String get plateNumber;

  /// No description provided for @plateLabel.
  ///
  /// In km, this message translates to:
  /// **'ផ្លាក'**
  String get plateLabel;

  /// No description provided for @registrationNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខបណ្ណសម្គាល់យានយន្ត'**
  String get registrationNumber;

  /// No description provided for @inspectionNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខលិខិតត្រួតពិនិត្យបច្ចេកទេស'**
  String get inspectionNumber;

  /// No description provided for @domesticCertNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខវិញ្ញាបនបត្រដឹកជញ្ជូនក្នុងស្រុក'**
  String get domesticCertNumber;

  /// No description provided for @insuranceNumber.
  ///
  /// In km, this message translates to:
  /// **'លេខធានារ៉ាប់រងពាណិជ្ជកម្ម'**
  String get insuranceNumber;

  /// No description provided for @logoConfirm.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំនឹងដាក់ស្លាកសញ្ញា Leca លើយាន'**
  String get logoConfirm;

  /// No description provided for @partnerConfirm.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំជាដៃគូឯករាជ្យ មិនមែននិយោជិត។ ចំណូលនៅជាមួយខ្ញុំ។'**
  String get partnerConfirm;

  /// No description provided for @trainTraffic.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានរៀនច្បាប់ចរាចរណ៍ផ្លូវគោក'**
  String get trainTraffic;

  /// No description provided for @trainDriving.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានរៀនការបើកបរ'**
  String get trainDriving;

  /// No description provided for @trainService.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានរៀនសេវាអតិថិជន'**
  String get trainService;

  /// No description provided for @trainConduct.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានរៀនក្រមសីលធម៌'**
  String get trainConduct;

  /// No description provided for @onlineBlocked.
  ///
  /// In km, this message translates to:
  /// **'បំពេញឯកសារដៃគូ និងការបណ្ដុះបណ្ដាលសិន ទើបចូលបណ្ដាញបាន។'**
  String get onlineBlocked;

  /// No description provided for @licenceInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខប័ណ្ណបើកបរកម្ពុជា។'**
  String get licenceInvalid;

  /// No description provided for @plateInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលផ្លាកលេខ។'**
  String get plateInvalid;

  /// No description provided for @registrationInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខបណ្ណសម្គាល់យានយន្ត។'**
  String get registrationInvalid;

  /// No description provided for @inspectionInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខលិខិតត្រួតពិនិត្យបច្ចេកទេស។'**
  String get inspectionInvalid;

  /// No description provided for @transportCertInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខវិញ្ញាបនបត្រដឹកជញ្ជូនក្នុងស្រុក។'**
  String get transportCertInvalid;

  /// No description provided for @insuranceInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលលេខធានារ៉ាប់រងពាណិជ្ជកម្ម។'**
  String get insuranceInvalid;

  /// No description provided for @logoRequired.
  ///
  /// In km, this message translates to:
  /// **'យានត្រូវមានស្លាកសញ្ញា Leca។'**
  String get logoRequired;

  /// No description provided for @partnerRequired.
  ///
  /// In km, this message translates to:
  /// **'បញ្ជាក់ថាអ្នកជាដៃគូឯករាជ្យ។'**
  String get partnerRequired;

  /// No description provided for @trainingRequired.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចប់ការបណ្ដុះបណ្ដាលទាំងបួនសិន។'**
  String get trainingRequired;

  /// No description provided for @partnerNotice.
  ///
  /// In km, this message translates to:
  /// **'អ្នកបើកជាដៃគូកម្ពុជាឯករាជ្យ។ Leca មិនកាន់កាប់តាក់ស៊ី រ៉ឺម៉ក ឬយានសាធារណៈផ្សេងទេ។'**
  String get partnerNotice;

  /// No description provided for @sellerName.
  ///
  /// In km, this message translates to:
  /// **'ឈ្មោះអ្នកលក់'**
  String get sellerName;

  /// No description provided for @sellerPhone.
  ///
  /// In km, this message translates to:
  /// **'ទូរស័ព្ទអ្នកលក់'**
  String get sellerPhone;

  /// No description provided for @sellerId.
  ///
  /// In km, this message translates to:
  /// **'លេខអត្តសញ្ញាណអ្នកលក់'**
  String get sellerId;

  /// No description provided for @sellerKycInvalid.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចូលឈ្មោះ ទូរស័ព្ទ និងលេខអត្តសញ្ញាណអ្នកលក់។'**
  String get sellerKycInvalid;

  /// No description provided for @sellerLine.
  ///
  /// In km, this message translates to:
  /// **'{name} · {phone}'**
  String sellerLine(String name, String phone);

  /// No description provided for @itemDescriptionKm.
  ///
  /// In km, this message translates to:
  /// **'ការពិពណ៌នាជាភាសាខ្មែរ'**
  String get itemDescriptionKm;

  /// No description provided for @itemKhmer.
  ///
  /// In km, this message translates to:
  /// **'ព័ត៌មានទំនិញត្រូវមានអក្សរខ្មែរ។'**
  String get itemKhmer;

  /// No description provided for @payMethods.
  ///
  /// In km, this message translates to:
  /// **'បង់តាម ABA Pay, Bakong, ACLEDA, Wing Bank, សាច់ប្រាក់ ឬ Visa, Mastercard, Discover, UnionPay និង Alipay តាម Stripe។ Leca មិនកាន់សមតុល្យ។'**
  String get payMethods;

  /// No description provided for @consumerReport.
  ///
  /// In km, this message translates to:
  /// **'តវ៉ា'**
  String get consumerReport;

  /// No description provided for @consumerReportDone.
  ///
  /// In km, this message translates to:
  /// **'ការតវ៉ាត្រូវបានកត់ត្រា។ Leca នឹងពិនិត្យ។'**
  String get consumerReportDone;

  /// No description provided for @takedown.
  ///
  /// In km, this message translates to:
  /// **'ដកទំនិញ'**
  String get takedown;

  /// No description provided for @takedownDone.
  ///
  /// In km, this message translates to:
  /// **'ទំនិញត្រូវបានដក។'**
  String get takedownDone;

  /// No description provided for @driverPhoto.
  ///
  /// In km, this message translates to:
  /// **'រូបអ្នកបើក'**
  String get driverPhoto;

  /// No description provided for @staffIdLabel.
  ///
  /// In km, this message translates to:
  /// **'បណ្ណបុគ្គលិក'**
  String get staffIdLabel;

  /// No description provided for @shareFamily.
  ///
  /// In km, this message translates to:
  /// **'ចែកការជិះនេះទៅគ្រួសារ'**
  String get shareFamily;

  /// No description provided for @shareAuthorities.
  ///
  /// In km, this message translates to:
  /// **'ចែកការជិះនេះទៅអាជ្ញាធរ'**
  String get shareAuthorities;

  /// No description provided for @shareCopied.
  ///
  /// In km, this message translates to:
  /// **'បានចម្លង។ ផ្ញើទៅអ្នកទទួល។'**
  String get shareCopied;

  /// No description provided for @shareTripHint.
  ///
  /// In km, this message translates to:
  /// **'រួមមានអ្នកបើក ផ្លាក ក្រុង ម៉ោង និងទីតាំងបើឧបករណ៍ផ្ដល់។'**
  String get shareTripHint;

  /// No description provided for @reportSafety.
  ///
  /// In km, this message translates to:
  /// **'រាយការណ៍'**
  String get reportSafety;

  /// No description provided for @reportIntoxication.
  ///
  /// In km, this message translates to:
  /// **'បើកបរក្រោមឥទ្ធិពល'**
  String get reportIntoxication;

  /// No description provided for @reportViolence.
  ///
  /// In km, this message translates to:
  /// **'អំពើហិង្សា'**
  String get reportViolence;

  /// No description provided for @reportHarassment.
  ///
  /// In km, this message translates to:
  /// **'ការបៀតបៀនផ្លូវភេទ'**
  String get reportHarassment;

  /// No description provided for @reportActed.
  ///
  /// In km, this message translates to:
  /// **'Leca បានកត់ត្រា ហើយផ្អាកដៃគូនេះពីការជិះថ្មី។ ពួកគេអាចប្តឹងបាន។'**
  String get reportActed;

  /// No description provided for @licencePhoto.
  ///
  /// In km, this message translates to:
  /// **'រូបប័ណ្ណបើកបរ'**
  String get licencePhoto;

  /// No description provided for @registrationPhoto.
  ///
  /// In km, this message translates to:
  /// **'រូបប័ណ្ណចុះឈ្មោះ'**
  String get registrationPhoto;

  /// No description provided for @insurancePhoto.
  ///
  /// In km, this message translates to:
  /// **'រូបធានារ៉ាប់រង'**
  String get insurancePhoto;

  /// No description provided for @reviewPending.
  ///
  /// In km, this message translates to:
  /// **'មនុស្សកំពុងមើលឯកសារនេះ។ ការចូលបណ្តាញរង់ចាំការនោះ។'**
  String get reviewPending;

  /// No description provided for @reviewApproved.
  ///
  /// In km, this message translates to:
  /// **'មនុស្សបានយល់ព្រមឯកសារនេះ។'**
  String get reviewApproved;

  /// No description provided for @reviewRejected.
  ///
  /// In km, this message translates to:
  /// **'ឯកសារនេះមិនត្រូវបានយល់ព្រម។'**
  String get reviewRejected;

  /// No description provided for @appealHint.
  ///
  /// In km, this message translates to:
  /// **'របាយការណ៍បានផ្អាកអ្នក។ សរសេរមូលហេតុដែលគួរលុបចោល។'**
  String get appealHint;

  /// No description provided for @appealSend.
  ///
  /// In km, this message translates to:
  /// **'ប្តឹង'**
  String get appealSend;

  /// No description provided for @appealEmpty.
  ///
  /// In km, this message translates to:
  /// **'សរសេរការប្តឹង។'**
  String get appealEmpty;

  /// No description provided for @upfrontFare.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃបង្ហាញមុន'**
  String get upfrontFare;

  /// No description provided for @noWallet.
  ///
  /// In km, this message translates to:
  /// **'ប្រាក់ចូលធនាគារ តាម Stripe សម្រាប់ Visa, Mastercard, Discover, UnionPay និង Alipay ឬជាសាច់ប្រាក់។ Leca មិនមានកាបូបប្រាក់ ឬ Bitcoin។'**
  String get noWallet;

  /// No description provided for @cashHint.
  ///
  /// In km, this message translates to:
  /// **'បង់ជារៀល ឬដុល្លារទៅដៃគូ ឬអ្នកលក់។ Leca មិនទទួលសាច់ប្រាក់នេះទេ។'**
  String get cashHint;

  /// No description provided for @dropoff.
  ///
  /// In km, this message translates to:
  /// **'ទម្លាក់'**
  String get dropoff;

  /// No description provided for @autoFare.
  ///
  /// In km, this message translates to:
  /// **'{km} គ.ម · {minutes} នាទី'**
  String autoFare(String km, int minutes);

  /// No description provided for @fareProof.
  ///
  /// In km, this message translates to:
  /// **'ភស្តុតាង {proof}'**
  String fareProof(String proof);

  /// No description provided for @talkVoice.
  ///
  /// In km, this message translates to:
  /// **'សំឡេង'**
  String get talkVoice;

  /// No description provided for @talkVideo.
  ///
  /// In km, this message translates to:
  /// **'វីដេអូ'**
  String get talkVideo;

  /// No description provided for @talkProof.
  ///
  /// In km, this message translates to:
  /// **'ការជជែកនេះផ្ទៀងផ្ទាត់បាន'**
  String get talkProof;

  /// No description provided for @talkIroh.
  ///
  /// In km, this message translates to:
  /// **'អក្សរ សំឡេង និងវីដេអូទៅផ្ទាល់តាម iroh។ សោឧបករណ៍នេះជាអាសយដ្ឋានដែលអ្នកដទៃប្រើ។ ឈ្មោះមិនបាច់មានទេ។'**
  String get talkIroh;

  /// No description provided for @talkWith.
  ///
  /// In km, this message translates to:
  /// **'ជជែក'**
  String get talkWith;

  /// No description provided for @whoDriver.
  ///
  /// In km, this message translates to:
  /// **'អ្នកបើក'**
  String get whoDriver;

  /// No description provided for @whoCustomer.
  ///
  /// In km, this message translates to:
  /// **'អតិថិជន'**
  String get whoCustomer;

  /// No description provided for @yourPrice.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃ{who}'**
  String yourPrice(String who);

  /// No description provided for @proposedBy.
  ///
  /// In km, this message translates to:
  /// **'{who} ស្នើ {price}។ តម្លៃកម្មវិធីនៅអនុវត្តរហូតដល់ម្ខាងទៀតយល់ព្រម។'**
  String proposedBy(String who, String price);

  /// No description provided for @agreedPrice.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃព្រមព្រៀង'**
  String get agreedPrice;

  /// No description provided for @priceAllowed.
  ///
  /// In km, this message translates to:
  /// **'យល់ព្រម {price}'**
  String priceAllowed(String price);

  /// No description provided for @priceInChat.
  ///
  /// In km, this message translates to:
  /// **'តម្លៃចរចានៅទីនេះ។ ម្ខាងស្នើ ម្ខាងទៀតយល់ព្រម។'**
  String get priceInChat;

  /// No description provided for @roadRouted.
  ///
  /// In km, this message translates to:
  /// **'ចម្ងាយតាមផ្លូវ និងចរាចរណ៍ថ្ងៃនេះ។'**
  String get roadRouted;

  /// No description provided for @rentLength.
  ///
  /// In km, this message translates to:
  /// **'រយៈពេល'**
  String get rentLength;

  /// No description provided for @rentHours.
  ///
  /// In km, this message translates to:
  /// **'{n} ម៉ោង'**
  String rentHours(int n);

  /// No description provided for @rentDays.
  ///
  /// In km, this message translates to:
  /// **'{n} ថ្ងៃ'**
  String rentDays(int n);

  /// No description provided for @rentWeeks.
  ///
  /// In km, this message translates to:
  /// **'{n} សប្តាហ៍'**
  String rentWeeks(int n);

  /// No description provided for @authMoreWays.
  ///
  /// In km, this message translates to:
  /// **'វិធីផ្សេងទៀត'**
  String get authMoreWays;

  /// No description provided for @authFewerWays.
  ///
  /// In km, this message translates to:
  /// **'បង្រួម'**
  String get authFewerWays;

  /// No description provided for @counterFare.
  ///
  /// In km, this message translates to:
  /// **'តថ្លៃវិញ'**
  String get counterFare;

  /// No description provided for @endFare.
  ///
  /// In km, this message translates to:
  /// **'បញ្ចប់ការតថ្លៃ'**
  String get endFare;

  /// No description provided for @fareEnded.
  ///
  /// In km, this message translates to:
  /// **'ការតថ្លៃបានបញ្ចប់។ អនុវត្ត {price}។'**
  String fareEnded(String price);

  /// No description provided for @fareYourTurn.
  ///
  /// In km, this message translates to:
  /// **'ការស្នើរបស់ម្ខាងទៀត។ យល់ព្រម តថ្លៃវិញ ឬបញ្ចប់។'**
  String get fareYourTurn;

  /// No description provided for @trainAll.
  ///
  /// In km, this message translates to:
  /// **'ខ្ញុំបានបញ្ចប់ការបណ្តុះបណ្តាលទាំងបួន'**
  String get trainAll;

  /// No description provided for @signupReady.
  ///
  /// In km, this message translates to:
  /// **'គ្រប់គ្រាន់ហើយ។ រក្សាទុកដើម្បីទទួលលេខបុគ្គលិក។'**
  String get signupReady;

  /// No description provided for @signupNext.
  ///
  /// In km, this message translates to:
  /// **'បន្ទាប់៖ {step}'**
  String signupNext(String step);

  /// No description provided for @talkInCall.
  ///
  /// In km, this message translates to:
  /// **'{name} បានចាប់ផ្ដើម {kind}'**
  String talkInCall(String name, String kind);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'km'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'km':
      return AppLocalizationsKm();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
