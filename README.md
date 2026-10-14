# Leca

Leca is a super-app for **Cambodia**.

One app for customers and operators (not a separate driver app):

- Food
- Rides
- Vehicle rental (any legal vehicle a partner owns, with or without a driver)
- Open delivery (send anything legal)
- Open a business (restaurant, pharmacy, or any lawful kind)
- Drive, accept jobs, and list a vehicle
- Pay: **Stripe** plus Cambodian KHQR rails (**ABA Pay**, Bakong, ACLEDA, Wing Bank, other QR)

Native on **Android, iOS, macOS, Windows, Linux, and web** (Flutter). A phone is for delivery: search is a kilometre radius from the phone's GPS, and the same phone can go out on a job. A Mac or Windows computer manages products and prices. It can receive a delivery, and it does not go out and make one. The top of the radius control is the whole country, which is not a circle.

## Sign in

Google, Facebook, WeChat, email and password, or a phone number. Without the auth server the app still signs you in locally (Google → `sokha@chow.app`, Facebook → `sokha.fb@chow.app`, WeChat → `sokha.wx@chow.app`, phone → 8+ digits then a 4+ digit code). Email accounts stay on this device until you point the app at the auth server.

The server in `server/` checks the real accounts:

- Phone: a 4-digit code. Twilio sends it when `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, and `TWILIO_FROM` are set. `CHOW_DEV_OTP=1` returns the code in the response instead.
- Google, Facebook, and WeChat: the server opens the provider, takes the callback, and keeps the session. WeChat uses the website QR login.

The live server is `root@65.21.232.29`. The main address is [https://leca.world](https://leca.world). These names serve the same site once each A record is `65.21.232.29`: `leca.my`, `leca.homes`, `leca.quest`, `leca.autos`, `leca.boats`, `leca.beer`, `leca.beauty`, and `leca.baby`. Email and password are real accounts. Test sign-in is off. Google, Facebook, WeChat, and phone SMS start only after their secrets are in `/etc/chow-auth.env`. Google’s redirect is `https://leca.world/v1/auth/google/callback`.

```bash
flutter run --dart-define=AUTH_API=https://leca.world
```

iPhone goes through the App Store later. Real Google, Facebook, and WeChat logins use `https://leca.world/v1/auth/google/callback`, `.../facebook/callback`, and `.../wechat/callback`.

`AuthConfig` in `lib/auth.dart` is the seam. A missing server cannot block the app.

## Payments

Checkout is **ABA Pay**, **Bakong KHQR**, **ACLEDA**, **Wing Bank**, cash in riel or dollars, or a card. **Visa**, **Mastercard**, **Discover**, **UnionPay**, and **Alipay** go through Stripe Checkout. Every sale adds a **5%** service fee on top of the listed price. Leca does not keep a wallet, escrow, or balance, and it does not take Bitcoin.

A driver's arrival time comes from Google Routes with live traffic (`GOOGLE_MAPS_API_KEY` on the server, Routes API enabled). The listed fare still goes to the partner.

```bash
flutter run --dart-define=STRIPE_PK=pk_test_...
```

Without a key, Stripe still shows a Checkout-style QR (`cs_test_chow_…`). ABA / Bakong / ACLEDA / Wing Bank QRs are **on-device EMVCo KHQR**. No live merchant accounts are bundled. Bank apps may reject scans until real Bakong IDs are attached. The payer’s bank holds the money.

## Requirements

- Flutter 3.47 stable (Dart 3.13)
- Bundled Kantumruy Pro (SIL OFL) for Khmer + Latin
- Android SDK 36 to produce a release APK
- Linux desktop: `ninja-build`, `libgtk-3-dev` (GTK 3)

Compatibility floors: Flutter defaults (**Android 24+**, **iOS 15+**), plus macOS, Windows, Linux, and web.

## Run

```bash
flutter pub get
```

### Web

```bash
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 45217
```

Open `http://127.0.0.1:45217`.

### Android / iOS / macOS / Windows / Linux

```bash
flutter run -d android
flutter run -d ios
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

iOS and macOS release builds are made on a Mac with Xcode.

## Android APK

```bash
flutter build apk
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

## Builds

`./build.sh` sends each target to the machine that can compile it.

| Target | Where |
| --- | --- |
| macos, ios, android | this Mac |
| linux-arm64, windows-arm64 | Ubuntu and Windows 11 ARM VMs on this Mac |
| linux-x64 | the Omarchy PC in `scripts/x86.host` (`omarchy pkg add`, Flutter from mise) |
| windows-x64 | a KVM Windows guest on that PC (`scripts/win-x64.sh`, `CHOW_WIN_MEM` default `32G`) |

```bash
./build.sh
./build.sh linux-x64
./build.sh linux-arm64 windows-arm64
```

The ARM VMs are `./qemu/build.sh linux` and `./qemu/build.sh windows`. Disks stay in `qemu/.cache`. `CHOW_QEMU_MEM` (default `8G`) and `CHOW_QEMU_CPUS` (default `4`) size them. Delete `qemu/.cache/linux` or `qemu/.cache/windows` to recreate that VM.

## Driver, shops, rides

Cambodia rides match independent partners. Leca does not own or operate the vehicles. Driver signup asks for a selfie and an ID-card photo. The check is on-device: both files must be real images, they must not be the same file, and the name you type must match the name on the card. A Cambodian partner also files a driving licence, plate, registration, and commercial insurance, confirms the Leca logo, and completes training on the road-traffic law, driving, customer service, and conduct. Motorcycles skip the technical inspection and the domestic transport certificate. Tuk-tuks and remorques skip the transport certificate. The app then issues a staff ID. Going online stays closed until that file is complete.

A passenger sees the driver photo, plate, staff ID, and upfront fare, can share the trip with family or authorities, and can report intoxication, violence, or sexual harassment. A report suspends that partner from new trips. The fare is not discounted after the rider accepts it.

### Automatic fares and bargaining

Every ride, rental, food delivery, and parcel is priced the same way from rate card `leca-kh-1`: road distance (straight line × 1.3), trip minutes from live traffic when it is known, and a base, per-km, and per-minute charge per kind and vehicle. A rental with a driver bills their minutes; a self-drive rental does not. The app and the server (`POST /v1/quote`) share the math, and each quote carries a SHA-256 proof over the published inputs that either side can recompute.

The app price is what gets charged until both sides agree on something else. A driver can ask for more and a customer can offer less, on the booking card or in the chat beside the price. Either side can counter as many times as they like; a bid only takes effect when the other side allows it, and either side can end the bargain, which leaves the last agreed price (or the app price) standing. Every bargain in the app lives in one table keyed by fare, so the kitchen chat, the booking card, and checkout always show the same number. A changed route is a new key and a fresh bargain.

### Chat

Everyone on a trip shares one room: text, voice, video, and price lines. Each line hashes the previous one (`leca-talk/2`), so the whole conversation, including every price ask, allow, and end, is one proof. A line is bound to its author by `who`, a 16-hex hash of the account id that the server derives from the session token on join; names are shown, ids never leave the server, and two people with the same name cannot act for each other. Only signed-in accounts can place price lines. The relay is `/v1/room` on the Leca server; devices also open a direct iroh link with each other.

### Nothing is lost on restart

The app saves its state (session, cart, booking, chat chains, bargains, driver file, listed vehicles, reports) to local storage a moment after every change and restores it on launch. The server appends every room line to `$CHOW_TALK_DIR/<room>.jsonl` (default `/var/lib/chow-auth/rooms`) as it happens and re-reads the chain, verifying each proof, the first time a room is opened after a restart.

### Signing up

Customers sign in with a phone number, email, Google, Facebook, or WeChat. Drivers add the Cambodian partner file on one screen: the legal name and phone come from the account, the name on the ID follows the legal name until it is edited, every vehicle kind is a tap, training is one tap or four, and the screen names the next missing item until the file is complete.

A shop needs the seller’s name, phone, and ID. In Cambodia the item description must include Khmer. The shop states the payment method, records a consumer complaint, and can remove a listing. Chat is open the day the business is created. A green dot means replies during working hours (08:00–21:00) average 5 minutes or less. Red means slower.

Rentals and sales are vehicles the owner listed. Any vehicle kind can be rented or bought, with a driver or without. A rental is priced place to place like a ride; a sale keeps the listed price.

## Tests

```bash
flutter test
```

## Origin

Origin is the source of truth. This tree also lives as a local git repo at `~/ciao`.
