// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Leca';

  @override
  String get tagline => 'Cheaper · better · without the silly limits';

  @override
  String get languageToggle => 'ខ្មែរ';

  @override
  String get cityPhnomPenh => 'Phnom Penh';

  @override
  String get citySiemReap => 'Siem Reap';

  @override
  String get serviceFood => 'Food';

  @override
  String get serviceSend => 'Send anything';

  @override
  String get serviceRides => 'Rides';

  @override
  String get serviceMoto => 'Motorcycle';

  @override
  String get serviceRent => 'Rent';

  @override
  String get bornInCambodia => 'Every city and village in Cambodia.';

  @override
  String get searchHint => 'Search dishes or kitchens';

  @override
  String popularTitle(int km) {
    return 'Most popular within $km km';
  }

  @override
  String get radiusCountry => 'All of Cambodia';

  @override
  String get popularCountry => 'Most popular in Cambodia';

  @override
  String radiusLabel(int km) {
    return '$km km';
  }

  @override
  String get windowHour => 'This hour';

  @override
  String get windowDay => 'Today';

  @override
  String get windowWeek => 'This week';

  @override
  String get windowMonth => 'This month';

  @override
  String popularOrders(int count) {
    return '$count orders';
  }

  @override
  String get popularEmpty => 'No popularity data for this window yet.';

  @override
  String feePromise(String price) {
    return '5% service fee · delivery from $price';
  }

  @override
  String etaMins(int mins) {
    return '$mins min';
  }

  @override
  String deliveryFrom(String price) {
    return 'Delivery $price';
  }

  @override
  String get loadingPlaces => 'Loading kitchens…';

  @override
  String get emptySearchTitle => 'Nothing matches';

  @override
  String get emptySearchBody =>
      'Nothing in this radius. Increase the kilometres.';

  @override
  String get catalogError => 'Could not load kitchens.';

  @override
  String get retry => 'Try again';

  @override
  String get add => 'Add';

  @override
  String get cart => 'Cart';

  @override
  String cartItems(int count) {
    return '$count items';
  }

  @override
  String get checkout => 'Order';

  @override
  String get emptyCartTitle => 'Cart is empty';

  @override
  String get emptyCartBody => 'Add a dish first, then come back to pay.';

  @override
  String get backToFood => 'Back to food';

  @override
  String get noteLabel => 'Order note';

  @override
  String get noteHint => 'e.g. no soy sauce, extra chilli';

  @override
  String get amountLabel => 'Amount';

  @override
  String get subtotal => 'Food';

  @override
  String get deliveryFee => 'Delivery';

  @override
  String get serviceFee => 'Service fee';

  @override
  String get serviceFeeNone => '5% of this sale.';

  @override
  String driverFastBonus(String amount) {
    return 'Leca pays the driver an extra $amount for getting there faster than the card\'s average time, inside the posted speed limit. Leca pays this, and the fare you pay does not change.';
  }

  @override
  String driverMinutes(String name, int minutes) {
    return '$name is $minutes minutes away';
  }

  @override
  String deliveryMinutes(int minutes) {
    return 'Delivery is $minutes minutes away';
  }

  @override
  String get total => 'Total';

  @override
  String get payTitle => 'Pay';

  @override
  String get scanToPay => 'Scan the QR code to pay';

  @override
  String get payWith => 'Pay with';

  @override
  String get stripePay => 'Pay with Stripe';

  @override
  String get stripeHint =>
      'Stripe Checkout for Visa, Mastercard, Discover, UnionPay, and Alipay. Pass STRIPE_PK when you have a live publishable key.';

  @override
  String get stripeHintLive =>
      'Stripe is ready for Visa, Mastercard, Discover, UnionPay, and Alipay — scan or tap to pay.';

  @override
  String get stripeBrands => 'Visa · Mastercard · Discover · UnionPay · Alipay';

  @override
  String khqrHint(String bank) {
    return 'Scan with $bank or Bakong. KHQR is generated on-device — no live merchant account is connected.';
  }

  @override
  String get otherHint => 'Generic fallback payload for other scanner apps.';

  @override
  String get loadingQr => 'Creating QR code…';

  @override
  String get errorQr => 'Could not create the QR code.';

  @override
  String get invalidAmount => 'Enter a valid amount.';

  @override
  String get tipTitle => 'Tip the driver';

  @override
  String get tipNone => 'No tip';

  @override
  String get tipCustom => 'Other amount';

  @override
  String get tipHint =>
      'The tip is added to this payment and goes to the driver. The fare does not change.';

  @override
  String get tipAsk => 'Add a tip for the driver before you pay?';

  @override
  String get tipSkip => 'Continue without a tip';

  @override
  String get tipAdd => 'Add this tip to the payment';

  @override
  String get iPaid => 'I have paid';

  @override
  String get paidTitle => 'Order received';

  @override
  String get paidBody =>
      'Keep the receipt in your bank app. Leca does not hold this payment.';

  @override
  String get close => 'Close';

  @override
  String get sendTitle => 'Send anything';

  @override
  String get sendBody =>
      'Send a parcel, documents, food, or anything legal. Anyone can deliver.';

  @override
  String get sendAnythingTitle => 'Send now';

  @override
  String get sendAnythingDetail => 'No category bans except the law.';

  @override
  String get ridesTitle => 'Rides';

  @override
  String get ridesBody =>
      'Book a ride. Any legal vehicle, with a driver or without.';

  @override
  String get rentBody =>
      'Rent a regular or autonomous vehicle. The list below is examples, not a closed set.';

  @override
  String get regularVehicles => 'Regular vehicles';

  @override
  String get autonomousVehicles => 'Autonomous vehicles';

  @override
  String get autonomousHint => 'No driver — the vehicle drives itself.';

  @override
  String get withOrWithoutDriver => 'With a driver or self-drive';

  @override
  String get vehicleExamplesNote =>
      'Examples only — any legal vehicle can be rented, with or without a driver.';

  @override
  String get ok => 'OK';

  @override
  String get authMockBanner =>
      'Face or a passkey is the fastest way in. Without the auth server this device uses a local mock.';

  @override
  String get authLiveBanner => 'Face or a passkey is the fastest way in.';

  @override
  String get authOtherWays => 'Other ways';

  @override
  String get authTelegram => 'Continue with Telegram (mock)';

  @override
  String get authTelegramLive => 'Continue with Telegram';

  @override
  String get authX => 'Continue with X (mock)';

  @override
  String get authXLive => 'Continue with X';

  @override
  String get authWhatsappLabel => 'WhatsApp';

  @override
  String get authWhatsappSend => 'Send WhatsApp code';

  @override
  String get authWhatsappUnconfigured =>
      'WhatsApp sign-in is not configured on the server.';

  @override
  String get authWechat => 'Continue with WeChat (mock)';

  @override
  String get authWechatLive => 'Continue with WeChat';

  @override
  String get authDevCode => 'Development code';

  @override
  String get authProviderUnconfigured =>
      'That sign-in provider is not configured on the server.';

  @override
  String get authSmsUnconfigured =>
      'Phone sign-in is not configured on the server.';

  @override
  String get authPhoneInvalid => 'Enter a phone number with at least 8 digits.';

  @override
  String get authCodeInvalid => 'That code is not valid.';

  @override
  String get authHandleEmpty => 'Enter an account.';

  @override
  String get authFailed => 'Could not sign in.';

  @override
  String get authGoogle => 'Continue with Google (mock)';

  @override
  String get authGoogleLive => 'Continue with Google';

  @override
  String get authFacebook => 'Continue with Facebook (mock)';

  @override
  String get authFacebookLive => 'Continue with Facebook';

  @override
  String get authPhoneLabel => 'Phone number';

  @override
  String get authPhoneHint => '012 345 678';

  @override
  String get authCodeHint => '4-digit code';

  @override
  String get authVerify => 'Verify';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authPasswordHint => 'Password, at least 8 characters';

  @override
  String get authNameHint => 'Your name';

  @override
  String get authKeyLabel => 'This device';

  @override
  String get authKeyExplain =>
      'This device holds the key other people use to reach you directly. A name is optional.';

  @override
  String get authKeyNameHint => 'Name, if you want one';

  @override
  String get authKeySignIn => 'Continue with this device';

  @override
  String get authFace => 'Continue with face';

  @override
  String get authFaceUnavailable => 'This device has no face recognition.';

  @override
  String get authFaceDenied => 'Face recognition was declined.';

  @override
  String get authPasskey => 'Continue with a passkey';

  @override
  String get authPasskeyUnavailable =>
      'Passkeys are not available on this device.';

  @override
  String get authPasskeyCancelled => 'Passkey sign-in was cancelled.';

  @override
  String get authEmailSignIn => 'Sign in with email';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authNeedAccount => 'Need an account?';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authPasswordShort => 'Use a password of at least 8 characters.';

  @override
  String get authEmailTaken => 'That email already has an account.';

  @override
  String get authCredentialsInvalid => 'That email or password is not right.';

  @override
  String get deskLead =>
      'Manage products, prices, and shops. This computer can receive a delivery. It does not go out and make one.';

  @override
  String get deskOrder => 'Get a delivery';

  @override
  String get deliverTo => 'Deliver to';

  @override
  String get accountTitle => 'Account';

  @override
  String get earnTitle => 'Earn with Leca';

  @override
  String get earnBody =>
      'Open any lawful business, drive, or list a vehicle. One app — not a separate driver app.';

  @override
  String get openBusiness => 'Open a business';

  @override
  String get driveCta => 'Drive';

  @override
  String get listVehicle => 'List a vehicle';

  @override
  String get myBusinesses => 'My businesses';

  @override
  String get emptyBusinesses => 'No businesses yet.';

  @override
  String get myVehicles => 'My vehicles';

  @override
  String get emptyVehicles => 'No vehicles listed yet.';

  @override
  String get withDriver => 'With a driver';

  @override
  String get selfDrive => 'Self-drive';

  @override
  String get drivingOn => 'You are online — you can take rides';

  @override
  String get drivingOff => 'You are offline';

  @override
  String get signOut => 'Sign out';

  @override
  String get businessKindHint =>
      'Restaurant, computers, baby items, pharmacy, or any lawful kind. Not a closed list.';

  @override
  String get businessKind => 'Business kind';

  @override
  String get businessName => 'Business name';

  @override
  String get businessInvalid => 'Enter a kind and a name.';

  @override
  String get saveBusiness => 'Save business';

  @override
  String get driveBody =>
      'Go online after the partner file and training are complete. You are an independent partner, not an employee.';

  @override
  String get driveVehicleNote => 'Vehicle you drive (e.g. motorcycle)';

  @override
  String get goOnline => 'Go online';

  @override
  String get listVehicleBody =>
      'List a vehicle you own. Any lawful kind, with a driver or self-drive.';

  @override
  String get vehicleKind => 'Vehicle kind';

  @override
  String get autonomousToggle => 'Autonomous';

  @override
  String get vehicleInvalid => 'Enter a vehicle kind.';

  @override
  String get saveVehicle => 'Save vehicle';

  @override
  String get jobsCta => 'Accept jobs';

  @override
  String get jobsTitle => 'Jobs';

  @override
  String get jobsBody =>
      'Take rides, food, parcels — any lawful job. Not a closed list.';

  @override
  String get jobsOffline => 'Go online first, then accept jobs.';

  @override
  String get emptyJobs => 'No open jobs right now.';

  @override
  String get emptyAcceptedJobs => 'No accepted jobs yet.';

  @override
  String get loadingJobs => 'Loading jobs…';

  @override
  String get jobsError => 'Could not load jobs.';

  @override
  String get acceptJob => 'Accept';

  @override
  String get declineJob => 'Decline';

  @override
  String get jobAccepted => 'Accepted';

  @override
  String get jobDeclined => 'Declined';

  @override
  String get acceptedJobs => 'Accepted jobs';

  @override
  String get openJobs => 'Open jobs';

  @override
  String get driverSignup => 'Driver signup';

  @override
  String get driverSignupBody =>
      'Your photo and ID card must match. In Cambodia, file a Cambodian driving licence, plate, registration, commercial insurance, the Leca logo, and training. Motorcycles do not need a technical inspection or a domestic transport certificate. Tuk-tuks and remorques do not need the transport certificate.';

  @override
  String get legalName => 'Your legal name';

  @override
  String get nameOnId => 'Name printed on the ID';

  @override
  String get idNumber => 'ID number';

  @override
  String get selfiePhoto => 'Your photo';

  @override
  String get idCardPhoto => 'ID card';

  @override
  String get pickPhoto => 'Add photo';

  @override
  String get saveDriver => 'Submit';

  @override
  String get driverVerified => 'Identity verified';

  @override
  String get driverUnverified => 'Identity not verified yet';

  @override
  String get identityNameMismatch => 'That name does not match the ID.';

  @override
  String get identityIdInvalid =>
      'Enter the ID number from the card (at least 6 digits).';

  @override
  String get identityPhotoInvalid => 'Use a real photo — JPEG, PNG, or WebP.';

  @override
  String get identityPhotoSame =>
      'The selfie and the ID card must be different photos.';

  @override
  String get identityPhotoMissing => 'Add both photos.';

  @override
  String get chat => 'Chat';

  @override
  String get chatHint => 'Message';

  @override
  String get sendMessage => 'Send';

  @override
  String get replyAsBusiness => 'Reply as the business';

  @override
  String get emptyChat => 'No messages yet. You can write from day one.';

  @override
  String get replyFast => 'Fast reply';

  @override
  String get replySlow => 'Slow reply';

  @override
  String get replyNew => 'No reply time yet';

  @override
  String workingHours(String open, String close) {
    return 'Working hours $open–$close';
  }

  @override
  String get addItem => 'Add item';

  @override
  String get itemDescription => 'Short description';

  @override
  String get itemPrice => 'Price (USD)';

  @override
  String get saveItem => 'Save item';

  @override
  String get itemInvalid => 'Add a photo, a short description, and a price.';

  @override
  String get emptyItems => 'No items yet.';

  @override
  String get forSale => 'For sale';

  @override
  String get forRent => 'For rent';

  @override
  String get appPrice => 'App price';

  @override
  String get driverPrice => 'Driver price';

  @override
  String get proposeFare => 'Propose';

  @override
  String get allowFare => 'Allow this price';

  @override
  String get fareWaiting =>
      'The rider has not allowed this price yet. The app price still applies.';

  @override
  String get saleHint =>
      'Car, motorcycle, bicycle, or tuktuk — rent or buy, with a driver or without.';

  @override
  String get shopTitle => 'Shop';

  @override
  String get ridesPartnerBody =>
      'Rides match independent Cambodian partners. Leca does not own the vehicles. The fare is shown up front and is not discounted after you accept it.';

  @override
  String get motoRideBody =>
      'A passenger sits behind the driver on a motorcycle with no trailer. This is not a tuk-tuk or a remorque. Two adults and a child can ride, and the driver, the passenger, and a child of three or older wear helmets. The ride is available in Phnom Penh and across Cambodia. Leca is based in Siem Reap, where Grab does not offer a motorcycle.';

  @override
  String get motoRideDetail =>
      'No trailer. The passenger sits behind the driver.';

  @override
  String get otherRides => 'Tuk-tuk, car, and the other rides';

  @override
  String get rentPartnerBody =>
      'Rent or buy a vehicle the owner listed. Leca does not operate a fleet.';

  @override
  String get rentExamplesKh =>
      'Examples of partner-owned vehicles. Leca does not own or operate them.';

  @override
  String get platformFleetBlocked =>
      'Leca does not operate autonomous or company-owned vehicles in Cambodia.';

  @override
  String get ownerConfirm => 'I own this vehicle. Leca does not.';

  @override
  String get ownerRequired => 'Confirm that you own the vehicle.';

  @override
  String get licenceNumber => 'Cambodian driving licence number';

  @override
  String get plateNumber => 'Plate';

  @override
  String get plateLabel => 'Plate';

  @override
  String get registrationNumber => 'Vehicle registration number';

  @override
  String get inspectionNumber => 'Technical inspection number';

  @override
  String get domesticCertNumber => 'Domestic transport certificate number';

  @override
  String get insuranceNumber => 'Commercial insurance number';

  @override
  String get logoConfirm => 'The Leca logo will be on this vehicle';

  @override
  String get partnerConfirm =>
      'I am an independent partner, not an employee. The fare stays with me.';

  @override
  String get trainTraffic => 'I have studied the road traffic law';

  @override
  String get trainDriving => 'I have studied driving';

  @override
  String get trainService => 'I have studied customer service';

  @override
  String get trainConduct => 'I have studied the code of conduct';

  @override
  String get onlineBlocked =>
      'Finish the partner file and training before going online.';

  @override
  String get licenceInvalid => 'Enter the Cambodian driving licence number.';

  @override
  String get plateInvalid => 'Enter the plate.';

  @override
  String get registrationInvalid => 'Enter the vehicle registration number.';

  @override
  String get inspectionInvalid => 'Enter the technical inspection number.';

  @override
  String get transportCertInvalid =>
      'Enter the domestic transport certificate number.';

  @override
  String get insuranceInvalid => 'Enter the commercial insurance number.';

  @override
  String get logoRequired => 'The vehicle needs the Leca logo.';

  @override
  String get partnerRequired => 'Confirm that you are an independent partner.';

  @override
  String get trainingRequired => 'Finish all four training topics first.';

  @override
  String get partnerNotice =>
      'Drivers are independent Cambodian partners. Leca does not own taxis, tuk-tuks, or other public-transport vehicles.';

  @override
  String get sellerName => 'Seller name';

  @override
  String get sellerPhone => 'Seller phone';

  @override
  String get sellerId => 'Seller ID number';

  @override
  String get sellerKycInvalid => 'Enter the seller name, phone, and ID number.';

  @override
  String sellerLine(String name, String phone) {
    return '$name · $phone';
  }

  @override
  String get itemDescriptionKm => 'Description in Khmer';

  @override
  String get itemKhmer => 'Product information must include Khmer.';

  @override
  String get payMethods =>
      'Pay with ABA Pay, Bakong, ACLEDA, Wing Bank, cash, or Visa, Mastercard, Discover, UnionPay, and Alipay through Stripe. Leca does not hold a balance.';

  @override
  String get consumerReport => 'Complaint';

  @override
  String get consumerReportDone =>
      'The complaint is recorded. Leca will review it.';

  @override
  String get takedown => 'Remove item';

  @override
  String get takedownDone => 'The item was removed.';

  @override
  String get driverPhoto => 'Driver photo';

  @override
  String get staffIdLabel => 'Staff ID';

  @override
  String get shareFamily => 'Share this trip with family';

  @override
  String get shareAuthorities => 'Share this trip with authorities';

  @override
  String get shareCopied => 'Copied. Send it to the recipient.';

  @override
  String get shareTripHint =>
      'Includes the driver, plate, city, time, and location when the device provides it.';

  @override
  String get reportSafety => 'Report';

  @override
  String get reportIntoxication => 'Driving under the influence';

  @override
  String get reportViolence => 'Violence';

  @override
  String get reportHarassment => 'Sexual harassment';

  @override
  String get reportActed =>
      'Leca recorded this and suspended this partner from new trips. They can appeal.';

  @override
  String get licencePhoto => 'Driving licence photo';

  @override
  String get registrationPhoto => 'Registration photo';

  @override
  String get insurancePhoto => 'Insurance photo';

  @override
  String get reviewPending =>
      'A person is looking at this file. Going online waits for that.';

  @override
  String get reviewApproved => 'A person approved this file.';

  @override
  String get reviewRejected => 'This file was not approved.';

  @override
  String get appealHint =>
      'A report suspended you. Write why it should be cleared.';

  @override
  String get appealSend => 'Appeal';

  @override
  String get appealEmpty => 'Write the appeal.';

  @override
  String get upfrontFare => 'Upfront fare';

  @override
  String get noWallet =>
      'Money settles in the bank app, with Stripe for Visa, Mastercard, Discover, UnionPay, and Alipay, or in cash. Leca has no wallet and does not take Bitcoin.';

  @override
  String get cashHint =>
      'Pay the partner or seller in riel or US dollars. Leca does not take the cash.';

  @override
  String get dropoff => 'Drop off';

  @override
  String autoFare(String km, int minutes) {
    return '$km km · $minutes min';
  }

  @override
  String fareProof(String proof) {
    return 'Proof $proof';
  }

  @override
  String get talkVoice => 'Voice';

  @override
  String get talkVideo => 'Video';

  @override
  String get talkProof => 'This chat checks out';

  @override
  String get talkIroh =>
      'Chat and prices ride an iroh swarm. Web, iPhone, Mac, and Windows are on it together. This device\'s key is how the others reach you.';

  @override
  String get talkWith => 'Talk';

  @override
  String get whoDriver => 'Driver';

  @override
  String get whoCustomer => 'Customer';

  @override
  String yourPrice(String who) {
    return '$who price';
  }

  @override
  String proposedBy(String who, String price) {
    return '$who proposes $price. The app price applies until the other side allows it.';
  }

  @override
  String get agreedPrice => 'Agreed price';

  @override
  String priceAllowed(String price) {
    return '$price allowed';
  }

  @override
  String get priceInChat =>
      'Price is negotiated here. Either side can propose; the other allows.';

  @override
  String get roadRouted => 'Distance follows the road in today\'s traffic.';

  @override
  String get rentLength => 'How long';

  @override
  String rentHours(int n) {
    return '$n h';
  }

  @override
  String rentDays(int n) {
    return '$n day';
  }

  @override
  String rentWeeks(int n) {
    return '$n week';
  }

  @override
  String get authMoreWays => 'More ways to sign in';

  @override
  String get authFewerWays => 'Fewer ways';

  @override
  String get counterFare => 'Counter';

  @override
  String get endFare => 'End bargaining';

  @override
  String fareEnded(String price) {
    return 'Bargaining ended. $price applies.';
  }

  @override
  String get fareYourTurn =>
      'Their offer. Allow it, counter, or end the bargain.';

  @override
  String get trainAll => 'I completed all four training topics';

  @override
  String get signupReady => 'Everything is here. Save to get your staff ID.';

  @override
  String signupNext(String step) {
    return 'Next: $step';
  }

  @override
  String talkInCall(String name, String kind) {
    return '$name started $kind';
  }

  @override
  String get servicePhone => 'Phone';

  @override
  String get phoneTitle => 'Phone';

  @override
  String get phoneData =>
      'Calls are data. iroh carries the voice between the two devices.';

  @override
  String get phoneYourNumber => 'Your number';

  @override
  String get phoneCopy => 'Copy';

  @override
  String get phoneCopied => 'Number copied';

  @override
  String get phoneHint => 'Paste a Leca number, or a name';

  @override
  String get phoneCall => 'Call';

  @override
  String get phoneAccept => 'Accept';

  @override
  String get phoneDecline => 'Decline';

  @override
  String get phoneHangup => 'Hang up';

  @override
  String get phoneMute => 'Mute';

  @override
  String get phoneMuted => 'Muted';

  @override
  String phoneDialing(String name) {
    return 'Calling $name';
  }

  @override
  String phoneRinging(String name) {
    return '$name is calling';
  }

  @override
  String get phoneLive => 'In call';

  @override
  String get phoneBusy => 'Busy';

  @override
  String get phoneUnreachable => 'No route. Paste the full number.';

  @override
  String get phoneDeclined => 'Declined';

  @override
  String get phoneSelf => 'That number is this device';

  @override
  String get phoneOffline => 'The data line is not up';

  @override
  String get phoneGear => 'The microphone is off. The call stays up.';

  @override
  String get phoneTimeout => 'No answer';

  @override
  String get phoneContacts => 'Contacts';

  @override
  String get phoneEmpty => 'No contacts yet. A number is an iroh address.';

  @override
  String get phoneRecent => 'Recent';

  @override
  String get phoneWeb =>
      'This browser shows the number. The call runs in the installed app.';

  @override
  String get phoneHeadset => 'A headset keeps the two voices apart.';

  @override
  String get phoneWayIn => 'In';

  @override
  String get phoneWayOut => 'Out';

  @override
  String get phoneWayMissed => 'Missed';

  @override
  String get talkCall => 'Call';

  @override
  String get chatFaceAnon => 'Distance only';

  @override
  String get chatFaceName => 'Show my name';

  @override
  String get chatFaceHide => 'Don\'t appear';

  @override
  String chatAway(int km) {
    return '$km km away';
  }

  @override
  String get chatAwayNear => 'Under 1 km';

  @override
  String get chatRadius => 'Chat radius';

  @override
  String get chatHiddenBody => 'You are not in this chat.';
}
