When developing iOS apps with Sign In with Apple, testing can be tricky since you're dealing with Apple's authentication system. Here are the main approaches:

**Sandbox / Simulator Testing**

- Sign In with Apple works on the iOS Simulator, but you must be signed into a real Apple ID in the simulator's Settings. Apple IDs used in the simulator go through the real Sign In with Apple flow, so you need a valid account.
- You can use your personal Apple ID, but many devs create a **dedicated test Apple ID** at appleid.apple.com to avoid mixing personal data.

**Hide My Email Handling**

- Apple lets users hide their real email, giving your app a relay address. Make sure your backend handles both real and relay emails gracefully.
- During testing, choosing "Share My Email" simplifies things so you can verify the correct email is stored.

**Revoking & Re-testing the Flow**

- Once a user has signed in, Apple won't show the full consent screen again for the same app. To re-test the full first-time flow, go to **Settings → Apple ID → Password & Security → Apps Using Apple ID** and revoke your app's access. The next sign-in will show the full sheet again.

**Token & Backend Testing**

- Apple issues a short-lived `identityToken` (JWT) and an `authorizationCode`. Your backend should verify the JWT using Apple's public keys from `https://appleid.apple.com/auth/keys`.
- For automated/unit testing of your backend auth logic, you can mock the token validation step rather than hitting Apple's real servers every time.

**Automated UI Testing (XCTest)**

- Sign In with Apple involves a system sheet, which XCTest **cannot interact with directly**. Common workarounds:
  - **Abstract the auth layer** behind a protocol/interface, then inject a mock auth provider during UI tests.
  - Use a **feature flag** to bypass Sign In with Apple entirely in test builds, swapping it for a simple email/password flow or a pre-authenticated test user.

**TestFlight**

- Works with real Apple IDs normally. Good for end-to-end testing before production, especially for testing the full user flow including the consent screen on real devices.

**The most common pattern** in practice is: use a dedicated test Apple ID for manual testing, mock the auth layer for automated tests, and revoke app access whenever you need to test the initial sign-in flow again.
