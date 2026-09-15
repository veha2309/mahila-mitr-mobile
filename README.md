# Mahila Mitr (Flutter)

An early Android/iOS app for period tracking and creative notes from a chosen partner. The account owner logs period starts and sees a clearly labeled estimate. A partner joins through a short-lived, single-use pairing code, can view period start logs, and can send a styled note. Both people can record a shared date rating and reflection. The account owner alone can edit period logs. Disconnecting removes the shared link and its notes and ratings.

## Run

1. Create a Supabase project. Email authentication is normally enabled by default. To send a six-digit code, the **Authentication → Email Templates → Magic Link** message must include `{{ .Token }}`. New free-tier projects using Supabase's default mail service cannot customize Auth templates; configure custom SMTP first to enable this OTP template.
2. Run `supabase/schema.sql` in the SQL editor.
3. Run `flutter pub get`.
4. Start with `flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key`. Never place a service-role key in the app.

The Flutter app checks for new notes when it resumes online and displays a generic local notification after the user grants permission. A production background push sender and delivery retries still need to be added before launch.

The default mail service sends only to email addresses belonging to the Supabase project team and has a very low sending limit. It can help test a template already configured for OTP, but it is not suitable for partner accounts or public users. For this app's code-entry flow, set up an SMTP service, then include `{{ .Token }}` in the Magic Link template. Without that token, Supabase sends a clickable link rather than a code. If email does not arrive, check spam, the project's Auth logs and email settings, and the `SUPABASE_URL` passed to `flutter run`.

If sign-in fails, run the app with `flutter run` and read the `Mahila Mitr action failed` line in the Flutter console. The debug app also shows the Supabase error message. Check **Authentication → Logs** in Supabase for a matching failure. The generic message alone cannot identify whether the cause is SMTP, recipient authorization, or connectivity.

An emulator test on 15 September 2026 returned HTTP 500 `unexpected_failure: Error sending confirmation email` from Supabase Auth. This means the request reached Supabase and the failure is in email delivery. In **Authentication → SMTP Settings**, verify the host, port, sender address, username, and password. For Gmail, use `smtp.gmail.com`, port `587`, your Gmail address as both username and sender, and a Google App Password (not your account password). Inspect Supabase Auth logs for the SMTP-specific reason, then send a test email after saving. [Supabase's Google SMTP troubleshooting](https://supabase.com/docs/guides/troubleshooting/using-google-smtp-with-supabase-custom-smtp-ZZzU4Y) covers common sender and password mismatches.

Bluetooth pairing and proximity alerts are not implemented yet. Advertising a persistent device ID would expose a trackable identifier. A safer later version can exchange a short-lived invitation over Bluetooth Low Energy, show the same confirmation phrase on both phones, require the account owner to approve, and finish linking through the server. After pairing, both users can separately opt in to a proximity alert. The phones should detect each other's rotating Bluetooth identifiers for several seconds, suppress repeated alerts, and show a generic local notification such as “You and your partner are nearby.” This needs a native BLE module, Android Bluetooth permissions, an iOS Core Bluetooth implementation, a development build, and testing on both platforms. iOS background advertising and scanning are restricted, so an “whenever close” promise cannot be made without device testing. Pairing by code works across distance today.

Cycle estimates are approximate and should not be used as contraception or medical advice. Pairing gives the partner access to period start history; the pairing screen discloses this before a code is shared. Before a public launch, add account deletion, abuse prevention and rate limits for pairing codes, privacy policy, and a full security review of note access and notifications.
