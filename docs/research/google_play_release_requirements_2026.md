# Google Play release requirements research (2026)

Verified against official Google, Android, and Flutter documentation on **2026-09-12**. This note records external requirements and recommended release gates; it does not assert that the repository currently satisfies them. Google can change Play requirements, so re-check the linked pages at release-candidate time.

## Immediate conclusions for MCQ Quizzer

1. **A new phone/tablet app or app update submitted now must target Android 16 / API 36 or higher.** The API 36 deadline was August 31, 2026; an extension to November 1, 2026 may be available through Play Console. An existing published app needs at least API 35 to remain broadly discoverable to new users. [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
2. **Choose the permanent production application ID before the first Play upload.** Android identifies an app by `applicationId`; after publication, changing it makes Play treat the upload as a different app. Keep `namespace` aligned unless there is a deliberate reason not to. [Android app-module configuration](https://developer.android.com/build/configure-app-module)
3. **Publish an Android App Bundle and configure real release signing.** New Play apps publish with `.aab`, and new apps use Play App Signing. The uploaded bundle must be signed with a private upload key; a debug-signed or unsigned release is not a production artifact. [Android App Bundle requirement](https://support.google.com/googleplay/android-developer/answer/9844279?hl=en), [Android app signing](https://developer.android.com/studio/publish/app-signing)
4. **Verify 16 KB page-size compatibility, including every native `.so` bundled by Flutter or plugins.** Current Android guidance says apps targeting API 35+ must support 16 KB pages on 64-bit devices, with unsupported updates blocked from February 1, 2027. Use APK Analyzer or bundle explorer, `zipalign -c -P 16 -v 4`, and a 16 KB emulator/device. [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes)
5. **Treat AI content safety and in-app reporting as a launch dependency.** Apps that generate content using AI must prevent prohibited/restricted output and provide an in-app way to report or flag offensive generated content without leaving the app. A factual-accuracy disclaimer is valuable but does not replace these controls. [Google Play AI-generated content policy](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en)
6. **Complete Android developer verification/package registration.** Effective September 30, 2026, Play package names must be registered to a verified developer; Play may auto-register eligible apps, but the Owner must confirm status in Play Console. [Registering Play package names](https://support.google.com/googleplay/android-developer/answer/16984799?hl=en)

## Platform and build requirements

### SDK levels

- **Target SDK:** API 36 or newer is required for new phone/tablet submissions and updates as of August 31, 2026. If this is an existing listing targeting API 35, it remains available, but its next update still needs API 36. [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- **Compile SDK:** Play does not publish a separate `compileSdk` policy threshold, but the project must compile against an SDK that supports its chosen `targetSdk`; for an API 36 target, compile with API 36 or newer and test Android 16 behavior changes.
- **Minimum SDK:** Google Play does not impose one universal `minSdk` for ordinary phone apps. The team should select the oldest Android version it can securely support and actually test; raising it later removes eligibility for older devices.
- **Resolved artifact check:** Do not rely only on Gradle variables. Inspect the release AAB/APK manifest or Play bundle explorer to confirm the effective min/target SDK and merged permissions before upload.

### 16 KB memory pages

Flutter apps contain native engine libraries even when the app itself has no C/C++ source, and plugins can add more native libraries. Therefore, MCQ Quizzer should not assume compatibility from Dart-only application code.

Release gate:

- build the release AAB with a current compatible Flutter/AGP toolchain;
- inspect all 64-bit native libraries in APK Analyzer or Play bundle explorer;
- run the official alignment check on generated APKs;
- install and exercise the app on a 16 KB Android 15+ emulator or supported device, verifying `adb shell getconf PAGE_SIZE` returns `16384`.

The current official page states that API 35+ apps must support 16 KB pages and that unsupported updates will be blocked from February 1, 2027. Treat compatibility as required now rather than waiting for enforcement. [Android 16 KB guidance](https://developer.android.com/guide/practices/page-sizes)

### Versioning

- Every Play release needs a positive, **strictly increasing** `versionCode`; Play will not accept reuse of a previously uploaded code.
- `versionName` is user-facing and can follow semantic versioning, but it does not control upgrade order.
- Establish one owner-controlled release bump step and record the Play track/build associated with each code. Flutter's `version: name+code` can supply both, provided the release process prevents duplicate codes. [Android versioning](https://developer.android.com/studio/publish/versioning)

## Application identity and signing

### Permanent identity decision

Before any Play upload, the Owner should confirm:

- final unique reverse-domain `applicationId`;
- whether that package name already exists in any Play Console account or has been distributed off-Play;
- matching Android namespace and Kotlin package migration plan;
- public app name and developer identity (these are separate from the package ID).

After publication, updates must keep the same application ID and compatible signing lineage. [Android app-module configuration](https://developer.android.com/build/configure-app-module)

### Recommended signing architecture

- Enrol the app in **Play App Signing** and let Google hold the app-signing key unless cross-store signing requirements justify supplying an existing app-signing key.
- Generate a distinct **upload key** locally; use it only to sign AABs sent to Play.
- Keep the keystore and all passwords outside the repository. Keep `android/key.properties` or equivalent secret-bearing configuration ignored, and inject CI values only through a protected secret store without logging them.
- Back up the upload key and recovery information securely. Play App Signing allows an upload-key reset if it is lost or compromised.
- Ensure the signing key validity extends beyond October 22, 2033. [Android app signing](https://developer.android.com/studio/publish/app-signing)

Flutter explicitly says both the upload keystore and `key.properties` must remain private and must not be committed to public source control. [Flutter Android release guide](https://docs.flutter.dev/deployment/android)

## Manifest and security review gates

### Permissions

- The final merged release manifest should contain only permissions required for active, user-visible functionality; dependencies can add permissions during manifest merging.
- Prefer system pickers and scoped APIs over broad storage access. High-risk or sensitive permissions can trigger a Play Permissions Declaration and extended review. [Play permission declarations](https://support.google.com/googleplay/android-developer/answer/9214102?hl=en)
- Request runtime permissions in context and only when the relevant feature is used. Explain unexpected personal/sensitive-data access before the permission prompt. [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en)

### Exact alarms and reminders

Most apps should use inexact alarms. Exact alarms are appropriate only when a user-facing feature genuinely requires precise timing. `SCHEDULE_EXACT_ALARM` is special app access, is not pre-granted to most fresh installs targeting API 33+, can be revoked, and requires a grant check before scheduling. `USE_EXACT_ALARM` is automatically granted but Play-restricted to narrow core cases such as alarm/timer or calendar apps. [Android alarm guidance](https://developer.android.com/develop/background-work/services/alarms), [Play restricted exact-alarm policy](https://support.google.com/googleplay/android-developer/answer/9888170?hl=en-EG)

For ordinary study reminders, prefer inexact scheduling unless the Owner defines an exact-time guarantee as core functionality. If exact scheduling remains, the app must explain the special access, handle denial/revocation, and reschedule safely after permission or boot events.

### Exported Android components

Every activity, service, receiver, and provider should explicitly declare `android:exported`. Export only components that must receive external/system intents; internal components should be `false`. An exported component that performs sensitive work should also validate callers/input and require an appropriate permission where applicable. [Android exported-component guidance](https://developer.android.com/privacy-and-security/risks/android-exported), [Exported component access control](https://developer.android.com/privacy-and-security/risks/access-control-to-exported-components)

Audit both the source manifests and the **merged release manifest**, because notification and other plugins may contribute receivers, services, providers, permissions, or intent filters.

### Network security

- Apps targeting API 28+ deny cleartext traffic by default, but an explicit Network Security Configuration gives the release an auditable policy and protects against accidental broad opt-in.
- Provider API keys, prompts, quiz source text, and generated content should travel only over authenticated TLS. A custom-provider URL should not be allowed to weaken release traffic to plain HTTP.
- Do not implement a permissive trust manager or ignore certificate errors. If local development needs user-installed CAs, use debug-only network-security overrides.
- Broad certificate pinning is a poor fit for arbitrary user-configured providers and creates availability/rotation risk; use platform trust unless a specific first-party endpoint and rotation strategy justify pinning.

[Android Network Security Configuration](https://developer.android.com/privacy-and-security/security-config), [Android security best practices](https://developer.android.com/privacy-and-security/security-best-practices)

### Backup and device transfer

Auto Backup is enabled by default for applicable apps and can include most app data. Set `android:allowBackup` explicitly and define exclusions rather than accepting an accidental default. Apps targeting API 31+ use `android:dataExtractionRules` for Android 12+; older devices use `android:fullBackupContent`. Device-to-device behavior can differ from cloud backup, so configure and test both. [Android Auto Backup](https://developer.android.com/identity/data/autobackup), [Backup security recommendations](https://developer.android.com/privacy-and-security/risks/backup-best-practices)

For this app, exclude API keys, tokens, secure-storage material, signing-related data, and any provider authentication state from cloud backup and device transfer. Decide separately whether user-created quiz/library data should be portable; document that decision in the privacy policy.

## Play Console, privacy, and content obligations

### Data Safety and privacy policy

All apps on closed, open, or production tracks must complete the Data Safety form, including apps that claim to collect no user data. Even a no-collection declaration requires a privacy-policy URL. Declarations must include behavior of third-party SDKs and remain accurate as ads, analytics, crash reporting, billing, or other libraries are added. [Play Data Safety requirements](https://support.google.com/googleplay/android-developer/answer/10787469)

MCQ Quizzer's privacy review must map these flows rather than assuming `local-first` means `no data leaves the device`:

- user-provided API credentials stored on device;
- prompts, imported document text, quiz topics, and generated quiz data transmitted directly to the provider selected by the user;
- notification/reminder data;
- exported/shared files;
- any future ad, billing, analytics, diagnostics, or crash-reporting SDK data.

The Owner should obtain legal review where appropriate. The privacy policy must be hosted at an active public URL and also be accessible in the app when the app handles personal or sensitive data. Prominent in-app disclosure and consent are additionally required where collection would not be reasonably expected. [Google Play User Data policy](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en), [Prominent disclosure guidance](https://support.google.com/googleplay/android-developer/answer/11150561?hl=en)

### Generative-AI policy

Because the app accepts user instructions/source material and generates new quiz questions and answers, the conservative release position is that Play's AI-generated content policy applies.

Required product/release gates:

- prohibit and prevent generation of Play-restricted content;
- provide a clearly labelled in-app report/flag action on generated content without requiring the user to leave the app;
- establish a real destination and handling process for reports, then use reports to improve filtering/moderation;
- give reviewers working access to the generation and reporting flows;
- retain the explicit `AI content may be wrong; verify important answers` warning for safety and trust, while recognizing that it is not a substitute for moderation/reporting.

[Google Play AI-generated content policy](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en), [AI policy overview](https://support.google.com/googleplay/android-developer/answer/14094294?hl=en)

### Other App content declarations

Before review, Play Console requires accurate setup for privacy policy, ads presence, app access instructions, target audience/content, content rating, Data Safety, and any sensitive-permission declarations. Apps without a content rating can be removed. [Prepare an app for review](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en), [Content rating requirements](https://support.google.com/googleplay/android-developer/answer/9898843?hl=en)

The Owner must decide the intended age groups. If any selected group includes children, the app, its AI providers, ads, data handling, and SDKs must comply with the Families policy; choosing an adult/older audience must also match the actual product and child appeal of the listing. [Target audience and content](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)

If the developer account is a personal account created after November 13, 2023, production access requires a closed test with at least 12 testers continuously opted in for 14 days, followed by a production-access application. New personal accounts also require verification using a real Android device. [Personal-account testing requirement](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en), [Device verification](https://support.google.com/googleplay/android-developer/answer/14316361?hl=en)

## Monetization dependencies (when implemented)

These are not blockers while the app has no ads or paid digital entitlement, but they become release gates in the same version that introduces monetization.

### One-time Pro / remove ads

An ad-free entitlement or other paid in-app functionality is a digital product and ordinarily must use Google Play Billing for Play-distributed users, subject to any enrolled regional alternative-billing program. The listing and purchase UI must clearly state price and terms. [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en)

As of this research date, Billing Library 7 passed its normal submission deadline on August 31, 2026; new apps/updates should use a supported Billing Library version (8 or newer) rather than beginning on a deprecated integration. [Play Billing deprecation schedule](https://developer.android.com/google/play/billing/deprecation-faq)

A production design should restore purchases, acknowledge purchases, handle pending/cancelled/refunded states, and avoid treating an easily modified local flag as authoritative. Server-side verification is the stronger entitlement architecture, especially if the app later adds subscriptions or provider-funded usage.

### Ads

- Declare **Contains ads** in Play Console and update Data Safety/privacy disclosures for the chosen ads SDK.
- A planned embedded, non-full-screen card/banner is less policy-risky than a full-screen unit, but it must remain distinguishable from app content and avoid accidental taps.
- Do not show unexpected full-screen interstitials, before the loading screen, or between a user action and its expected result. Interruptive full-screen ads must be readily dismissible and generally closeable within 15 seconds. [Google Play Ads policy](https://support.google.com/googleplay/android-developer/answer/9857753?hl=en)
- If children are in the target audience, ads require Families self-certified SDK versions, child-appropriate content, non-personalized treatment, and possibly a neutral age screen for a mixed audience. [Google Play Families policy](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)

## Recommended release checklist

### Owner / Play Console decisions

- [ ] Confirm the final application ID before the first upload and verify package-name availability/ownership.
- [ ] Confirm whether this is a new listing or an existing Play app, and the account type/creation date.
- [ ] Complete developer identity verification and confirm package registration before September 30, 2026.
- [ ] Decide target countries, age groups, category, pricing, and whether the first release contains ads or purchases.
- [ ] Approve a public privacy-policy URL, support contact, and AI-report handling channel.
- [ ] Choose Play App Signing key strategy and create/secure the upload key outside source control.

### Repository and artifact gates

- [ ] Set permanent `applicationId`/namespace and update matching Kotlin paths only after Owner approval.
- [ ] Resolve target API 36+ and confirm min/target SDK in the built artifact.
- [ ] Configure release signing without secrets in Git; fail release builds clearly when signing inputs are absent.
- [ ] Build a signed release `.aab`; retain APKs only for direct/manual testing.
- [ ] Review the merged release manifest: permissions, features, exported components, and provider grants.
- [ ] Remove unneeded permissions; verify reminder scheduling works when exact-alarm access is denied.
- [ ] Enforce TLS and define an auditable release network-security policy.
- [ ] Add backup/data-transfer rules that exclude API credentials and secure state.
- [ ] Verify 16 KB alignment and run core flows on a 16 KB environment.
- [ ] Verify monotonically increasing `versionCode` and intended `versionName`.
- [ ] Run release-mode smoke tests on representative Android versions/ABIs and Play pre-launch report.

### Policy and listing gates

- [ ] Publish an accurate privacy policy and complete Data Safety, including all third-party SDK/provider flows.
- [ ] Add/verify in-app reporting for AI-generated content and an operational moderation path.
- [ ] Verify the AI fallibility warning is visible at generation/review/use points appropriate to the product.
- [ ] Complete ads, app access, target audience, content rating, and permission declarations.
- [ ] Prepare store listing text, app icon, feature graphic, screenshots, support email, and review instructions.
- [ ] If applicable, complete the 12-testers/14-days closed-test requirement and production-access application.
- [ ] If monetization is included, validate Play Billing entitlements and ads/privacy/Families compliance before rollout.

## Re-check at release-candidate time

The target API, Billing Library, 16 KB, Android developer verification, and SDK policy deadlines are date-sensitive. Re-open the official pages above immediately before the first closed-test and production submissions, and treat Play Console's current policy/status warnings as authoritative for the specific app record.
