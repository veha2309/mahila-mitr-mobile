# Mahila Mitr (Flutter)

An early Android/iOS app for period tracking and creative notes from a chosen partner. The account owner logs period starts and sees a clearly labeled estimate. A partner joins through a short-lived, single-use pairing code, can view period start logs, and can send a styled note. Both people can record a shared date rating and reflection. The account owner alone can edit period logs. Disconnecting removes the shared link and its notes and ratings.

## Run

1. Create a Supabase project. Email authentication is normally enabled by default. To send an eight-digit code, the **Authentication → Email Templates → Magic Link** message must include `{{ .Token }}`. New free-tier projects using Supabase's default mail service cannot customize Auth templates; configure custom SMTP first to enable this OTP template.
2. Run `supabase/schema.sql` in the SQL editor.
3. Run `flutter pub get`.
4. Start with `flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key`. Never place a service-role key in the app.

The Flutter app checks for new notes when it resumes online and displays a generic local notification after the user grants permission. A production background push sender and delivery retries still need to be added before launch.

The default mail service sends only to email addresses belonging to the Supabase project team and has a very low sending limit. It can help test a template already configured for OTP, but it is not suitable for partner accounts or public users. For this app's code-entry flow, set up an SMTP service, then include `{{ .Token }}` in the Magic Link template. Without that token, Supabase sends a clickable link rather than a code. If email does not arrive, check spam, the project's Auth logs and email settings, and the `SUPABASE_URL` passed to `flutter run`.

If sign-in fails, run the app with `flutter run` and read the `Mahila Mitr action failed` line in the Flutter console. The debug app also shows the Supabase error message. Check **Authentication → Logs** in Supabase for a matching failure. The generic message alone cannot identify whether the cause is SMTP, recipient authorization, or connectivity.

An emulator test on 15 September 2026 returned HTTP 500 `unexpected_failure: Error sending confirmation email` from Supabase Auth. This means the request reached Supabase and the failure is in email delivery. In **Authentication → SMTP Settings**, verify the host, port, sender address, username, and password. For Gmail, use `smtp.gmail.com`, port `587`, your Gmail address as both username and sender, and a Google App Password (not your account password). Inspect Supabase Auth logs for the SMTP-specific reason, then send a test email after saving. [Supabase's Google SMTP troubleshooting](https://supabase.com/docs/guides/troubleshooting/using-google-smtp-with-supabase-custom-smtp-ZZzU4Y) covers common sender and password mismatches.

Nearby pairing is implemented on Android with a native BLE channel. It advertises only the short-lived six-byte invite value and stops after ten minutes; it does not broadcast a persistent device identifier. Android 12+ requests the Nearby Devices permissions, while older Android versions request location as required by the BLE APIs. Manual invite codes work on every supported platform. iOS Core Bluetooth support is still a launch follow-up, and background proximity alerts are intentionally not promised.

The current UI implements the complete Figma flow: role selection, OTP, owner home, pairing, moments, reflections, monthly/weekly/yearly calendars, and cycle statistics. Calendar and insight views are computed locally from the cycle rows already protected by Supabase RLS.

If the Supabase project was created with an older version of `schema.sql`, run `supabase/20260916_profiles_cycle_logging.sql` once. It adds private profile names, configurable period details (start/end dates, flow, symptoms and notes), and makes invite generation invalidate any older unused invite for the same owner. Without this migration, the app shows a setup screen instead of silently failing to load.

For existing databases, also run `supabase/20260922_partner_names_and_nicknames.sql` once. It adds shared partner nicknames and the protected function used to change them.

Run `supabase/20260922_ephemeral_chat.sql` to enable the private status/chat room. Messages are AES-256 encrypted on the server before storage and expire after the sender-selected TTL (10 minutes to 24 hours). This is server-side encryption, not end-to-end encryption; Supabase executes the authorized decryption function.

The room listens to Supabase Realtime and shows discreet local notifications containing no message preview while the app process is available. Delivery after the app has been fully terminated requires Firebase Cloud Messaging/APNs credentials plus a trusted server or Edge Function; do not describe local Realtime alerts as terminated-app push notifications.

Run `supabase/20260923_conversation_rooms.sql` after the chat migration to enable subject-based conversations. A conversation owns one adjustable expiry shared by all its messages; expiry deletes the conversation and cascades to its messages. The migration schedules minute-level cleanup with `pg_cron` when the project exposes it and otherwise cleans expired conversations on every room API call.

Run `supabase/20260924_message_ttl_and_status_effects.sql` to move expiry from the conversation to individual messages. Empty conversations persist, the default message TTL lives in conversation settings, long-pressing a message can extend it, and a conversation is removed after its final previously-created message expires. This migration also fixes the ambiguous `reply_to` SQL error from the earlier RPC.

Run `supabase/20260925_realtime_hardening.sql` to enforce publication membership, linked-user read policies, grants, and full replica identity for chat Realtime. The UI shows a green connection icon only after Supabase confirms the channel subscription and retries after app resume or channel failure.

For Android background and terminated-app push, place the matching `google-services.json` in `android/app`, run `supabase/20260926_push_tokens.sql`, deploy the `push-chat-notification` Edge Function, and set its `FIREBASE_SERVICE_ACCOUNT` secret to a Firebase Admin service-account JSON value. Never commit that service-account credential. The app registers and refreshes FCM tokens automatically; notification content is always the generic “You have a notification”.

Cycle estimates are approximate and should not be used as contraception or medical advice. Pairing gives the partner access to period start history; the pairing screen discloses this before a code is shared. Before a public launch, add account deletion, abuse prevention and rate limits for pairing codes, privacy policy, and a full security review of note access and notifications.
