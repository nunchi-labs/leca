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
- Data-only phone: the number is an iroh address, and the voice rides that link

Native on **Android, iOS, macOS, Windows, Linux, and web** (Flutter). A phone is for delivery: search is a kilometre radius from the phone's GPS, and the same phone can go out on a job. A Mac or Windows computer manages products and prices. It can receive a delivery, and it does not go out and make one. The top of the radius control is the whole country, which is not a circle.

## Sign in

Telegram, WeChat, Facebook, X, Google, email and password, or a WhatsApp code. Without the auth server the app still signs you in locally. Email accounts stay on this device until you point the app at the auth server.

The server in `server/` checks the real accounts:

- WhatsApp: a 4-digit code. Meta sends it when `WHATSAPP_TOKEN` and `WHATSAPP_PHONE_ID` are set, using the authentication template in `WHATSAPP_TEMPLATE`. Twilio sends it when `TWILIO_WHATSAPP_FROM` is set instead. `LECA_DEV_OTP=1` returns the code in the response instead.
- Telegram, WeChat, Facebook, X, and Google: the server opens the provider, takes the callback, and keeps the session. Telegram uses the bot token. X uses OAuth 2.0 with PKCE. WeChat uses the website QR login.

The live server is `root@65.21.232.29`. The main address is [https://leca.world](https://leca.world). These names redirect there once each A record is `65.21.232.29`: `leca.my`, `leca.homes`, `leca.quest`, `leca.autos`, `leca.boats`, `leca.beer`, `leca.beauty`, and `leca.baby`. Email and password are real accounts. Test sign-in is off. Google, Facebook, WeChat, and phone SMS start only after their secrets are in `/etc/leca-auth.env`. Google’s redirect is `https://leca.world/v1/auth/google/callback`.

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

Without a key, Stripe still shows a Checkout-style QR (`cs_test_leca_…`). ABA / Bakong / ACLEDA / Wing Bank QRs are **on-device EMVCo KHQR**. No live merchant accounts are bundled. Bank apps may reject scans until real Bakong IDs are attached. The payer’s bank holds the money.

## Requirements

- Flutter 3.47 stable (Dart 3.13)
- Bundled Kantumruy Pro (SIL OFL) for Khmer + Latin
- Android SDK 36 to produce a release APK
- Linux desktop: `ninja-build`, `libgtk-3-dev` (GTK 3)

Compatibility floors: Flutter defaults (**Android 24+**, **iOS 15+**), plus **macOS 13.5+** (passkeys), Windows, Linux, and web.

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
| macos, ios | the Mac in `scripts/mac.host` |
| android, linux-x64 | the Hetzner machine in `scripts/hetzner.host` |
| windows-x64 | a KVM Windows guest on that Hetzner machine (`scripts/win-x64.sh`, `LECA_WIN_MEM` default `32G`) |
| linux-arm64 | Depot CI (`depot-ubuntu-24.04-arm-8`) |
| windows-arm64 | a Windows ARM machine. Depot CI has no Windows sandbox |

```bash
./build.sh
./build.sh macos ios
./build.sh android linux-x64 windows-x64
```

`linux-arm64` is built by Depot CI. `windows-arm64` needs a Windows ARM machine. `./qemu/build.sh` can still boot those ARM VMs on the Apple Silicon Mac, outside `./build.sh`.

## Driver, shops, rides

Cambodia rides match independent partners. Leca does not own or operate the vehicles. Driver signup asks for a selfie and an ID-card photo, plus photos of the driving licence, registration, and insurance for motor vehicles. The check is on-device: the files must be real images, they must not be copies of each other, and the name you type must match the name on the card. A Cambodian partner also files the licence number, plate, registration, and commercial insurance, confirms the Leca logo, and completes training on the road-traffic law, driving, customer service, and conduct. Motorcycles skip the technical inspection and the domestic transport certificate. Tuk-tuks and remorques skip the transport certificate. The app then issues a staff ID and sends the file to `/v1/driver/file`. A person reviews it (`/v1/admin/driver/review`). Going online stays closed until that person approves.

A passenger sees the driver photo, plate, staff ID, and upfront fare, can share the trip with family or authorities, and can report intoxication, violence, or sexual harassment. A report is a server event: the partner is suspended from new trips at once, they see it and can appeal, and a reviewer upholds or clears it. The fare is not discounted after the rider accepts it.

### Automatic fares and bargaining

Every ride, rental, food delivery, and parcel is priced from the card the server publishes (`GET /v1/card` or `GET /v1/quote`, and the `rates` object on `POST /v1/quote`). Distance follows the road when `/v1/route` returns metres; otherwise the card's straight-line × 1.3 estimate. The proof names the card id and the metres that were used, so a Kampot → Kep quote stays checkable after the card changes. A rental also bills hours (eight per day), and that time charge is a floor under the route, so a day around Siem Reap that ends where it began still prices.

The app price is what gets charged until both sides agree on something else. A driver can ask for more and a customer can offer less, on the booking card or in the chat beside the price. Either side can counter as many times as they like; a bid only takes effect when the other side allows it, and either side can end the bargain, which leaves the last agreed price (or the app price) standing. Every bargain in the app lives in one table keyed by fare, so the kitchen chat, the booking card, and checkout always show the same number. A changed route is a new key and a fresh bargain.

### Chat

Everyone on a trip shares one room: text, voice, video, and price lines. Each line hashes the previous one (`leca-talk/2`), so the whole conversation, including every price ask, allow, and end, is one proof. A line is bound to its author by `who`, a 16-hex hash of the account id that the server derives from the session token on join; names are shown, ids never leave the server, and two people with the same name cannot act for each other. Only signed-in accounts can place price lines. The relay is `/v1/room` on the Leca server; devices also open a direct iroh link with each other.

### Phone

A call is data. The number is this device's iroh endpoint (`leca1`, the endpoint id, and the current address). Paste that card, call a saved contact, or call the other person in a trip room. Signaling is an iroh stream (`leca-phone/1`). Voice is 20 ms G.711 μ-law datagrams on the same connection. The microphone and speaker are the handset: echo cancel is on, and Android uses voice-communication mode. A carrier voice circuit is not in the call.

While the auth server is up, a signed-in device publishes its address at `POST /v1/phone/here` and can be found by name at `GET /v1/phone/find`. A listing expires after 90 seconds. The call still goes device to device over iroh. In a browser the number is shown; the call itself runs in the installed app.

### Nothing is lost on restart

The app saves its state (session, cart, booking, chat chains, bargains, driver file, listed vehicles, reports) to local storage a moment after every change and restores it on launch. The server appends every room line to `$LECA_TALK_DIR/<room>.jsonl` (default `/var/lib/leca-auth/rooms`) as it happens and re-reads the chain, verifying each proof, the first time a room is opened after a restart.

### Signing up

Customers sign in with a Cambodian phone number first (+855). Email, Google, Facebook, and WeChat sit under "more ways". Drivers add the Cambodian partner file on one screen: the legal name and phone come from the account, the name on the ID follows the legal name until it is edited, every vehicle kind is a tap, training is one tap or four, and the screen names the next missing item until the file is complete.

A shop needs the seller’s name, phone, and ID. In Cambodia the item description must include Khmer. The shop states the payment method, records a consumer complaint, and can remove a listing. Chat is open the day the business is created. A green dot means replies during working hours (08:00–21:00) average 5 minutes or less. Red means slower.

Rentals and sales are vehicles the owner listed. Any vehicle kind can be rented or bought, with a driver or without. A rental is priced place to place like a ride, plus the length of the hire; a sale keeps the listed price.

## Tests

```bash
flutter test
```

## Origin

Origin is the source of truth. The git remote named `origin` is the Cursor repository, and CI is `.depot/workflows/`. Depot runs those workflows when the Depot app is connected on the repository's Apps tab. A GitHub mirror does not start them.

Pull requests run the server tests, the Flutter tests, and `scripts/lint.sh`. A push to main also packages Android, Linux (x64 and arm64), and web. macOS, iOS, and Windows stay on `./build.sh`, because Depot CI sandboxes are Linux only. SwiftLint stays on a Mac (`swiftlint lint --strict`).

The GitHub remotes are still `github` (faddat/leca) and `nunchi` (nunchi-labs/leca). This tree also lives as a local git repo at `~/ciao`.
