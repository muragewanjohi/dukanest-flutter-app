# DukaNest Scan

Phone app that hears a store beacon and shows the offer set on that shelf.

Android listens with a Bluetooth scan. iOS uses Core Location ranging for the same beacon, because Apple does not give iBeacon advertisements to a Bluetooth scan. The app only hears the beacon while it is open.

Bundle ID: `com.dukanest.proximityScanTester`

## iOS release

`codemagic.yaml` at the repository root builds this app and sends it to TestFlight.

1. Create the app in App Store Connect with bundle ID `com.dukanest.proximityScanTester`.
2. The Codemagic App Store Connect API key is `STOREFLOW MICROSYSTEMS LIMITED`.
3. Add a Codemagic variable group named `app_store` with `APP_STORE_APPLE_ID` set to the numeric Apple ID from App Store Connect → App Information.
