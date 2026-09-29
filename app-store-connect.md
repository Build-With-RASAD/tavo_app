# App Store Connect — Tavo

> Source of truth for the App Store listing. Values marked ✅ are verified
> from the project. Values marked TODO still need input or assets.

## 1. App Information

| Field                    | Value                                                                                                                       |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| App name                 | Tavo ✅                                                                                                                     |
| Bundle ID                | `com.rasad.tavo` ✅                                                                                                         |
| SKU                      | `tavo-ios` (suggested, must be unique in your account)                                                                      |
| Apple ID                 | Assigned by Apple after first upload (TODO)                                                                                 |
| Primary language         | English (decision: if launch is Saudi-first, create the app record with **Arabic** as primary — it cannot be changed later) |
| Additional localizations | Arabic ✅ — verified 304/304 keys, zero missing or empty (`assets/translations/ar.json`)                                    |
| Category (primary)       | Food & Drink ✅                                                                                                             |
| Category (secondary)     | — (optional, leave empty)                                                                                                   |
| Content rights           | Contains no third-party content requiring documented rights ✅                                                              |

## 2. Pricing and Availability

| Field        | Value                                                               |
| ------------ | ------------------------------------------------------------------- |
| Price        | Free ✅                                                             |
| Availability | All territories (adjust if launch is region-limited — TODO confirm) |
| Pre-order    | Off                                                                 |

## 3. Version Information — 1.1.0 (build 2)

| Field          | Value                                                            |
| -------------- | ---------------------------------------------------------------- |
| Version number | 1.1.0 ✅ (`pubspec.yaml`)                                        |
| Build number   | 2 ✅ (`pubspec.yaml`, `version: 1.1.0+2`)                        |
| Minimum iOS    | 15.0 ✅ (`IPHONEOS_DEPLOYMENT_TARGET`)                           |
| Release type   | Manual release (recommended for first submission — TODO confirm) |

### What's New in This Version (English)

```text
Welcome to Tavo!

Discover great restaurants and book your table in seconds. Browse menus,
pick your spot, choose your guests, and manage all your reservations in
one place. Available in English and Arabic.
```

### What's New in This Version (Arabic)

```text
مرحباً بك في تافو!

اكتشف أفضل المطاعم واحجز طاولتك في ثوانٍ. تصفح القوائم، واختر مكانك،
وحدد عدد ضيوفك، وأدر جميع حجوزاتك في مكان واحد. متوفر باللغتين
العربية والإنجليزية.
```

## 4. App Store Listing (English)

- **Subtitle** (max 30 chars):

```text
Book tables at top restaurants
```

- **Description** (max 4000 chars):

```text
Tavo makes dining out effortless. Discover restaurants near you, explore
their menus, and reserve your table in just a few taps.

• Discover restaurants and browse their menus
• Book tables with your preferred date, time, and guest count
• Manage all your reservations in one place
• Get updates about your bookings
• Full experience in English and Arabic

Create your account with your phone number in seconds and start your
journey with Tavo.
```

- **Keywords** (max 100 chars, comma-separated):

```text
restaurant,booking,tables,reservation,food,menu,dining,مطاعم,حجز,طاولات
```

- **Support URL**: TODO (required — must be live before submission)
- **Privacy Policy URL**: TODO (required — app collects phone number, email, and photos)
- **Marketing URL**: optional, leave empty

## 5. App Store Listing (Arabic)

> Add Arabic as a localization on the version page in Connect, then paste
> each field below. App UI Arabic coverage is verified 100% (304/304 keys).

- **Subtitle**:

```text
احجز طاولات في أفضل المطاعم
```

- **Promotional text** (max 170 chars, editable without new review):

```text
احجز طاولتك في أفضل المطاعم خلال ثوانٍ — تصفح القوائم وأدر حجوزاتك بالعربية أو الإنجليزية.
```

- **Keywords** (max 100 chars, comma-separated, 48 used):

```text
مطاعم,حجز,طاولات,حجوزات,مطعم,أكل,قائمة,عشاء,غداء,تافو
```

- **Subtitle**:

```text
احجز طاولات في أفضل المطاعم
```

- **Description**:

```text
تافو يجعل الخروج لتناول الطعام سهلاً. اكتشف المطاعم القريبة منك، وتصفح
قوائمها، واحجز طاولتك ببضع نقرات فقط.

• اكتشف المطاعم وتصفح قوائمها
• احجز الطاولات بالتاريخ والوقت وعدد الضيوف المفضل لديك
• أدر جميع حجوزاتك في مكان واحد
• تابع تحديثات حجوزاتك
• تجربة كاملة باللغتين العربية والإنجليزية

أنشئ حسابك برقم هاتفك في ثوانٍ وابدأ رحلتك مع تافو.
```

## 6. Screenshots and Previews (TODO — assets not yet created)

| Slot                | Spec                                   | Status      |
| ------------------- | -------------------------------------- | ----------- |
| iPhone 6.9" display | 1290 × 2796 px, min 3, max 10          | TODO        |
| iPhone 6.5" display | 1242 × 2688 px (or 1284 × 2778), min 3 | TODO        |
| iPad 13" (optional) | 2064 × 2752 px                         | TODO        |
| App preview video   | optional                               | skip for v1 |

Suggested screenshot flow: Home/discover → restaurant page → menu → booking sheet → reservations → profile.

## 7. Age Rating — 4+ (expected)

Basis (verified from code): no user-posted content (ratings are
display-only), no gambling, no mature/provocative content, no weapons,
no medical advice. Complete the App Store questionnaire in Connect; it
should resolve to 4+.

## 8. App Privacy (nutrition labels)

Declare the following data collection (verified from code):

| Data             | Linked to user | Used for                              | Tracking |
| ---------------- | -------------- | ------------------------------------- | -------- |
| Phone number     | Yes            | App functionality, account management | No       |
| Email address    | Yes            | App functionality, account management | No       |
| Name             | Yes            | App functionality                     | No       |
| Photos (profile) | Yes            | App functionality                     | No       |

Not collected: precise/coarse location, contacts, browsing history,
health/fitness data. No third-party advertising or analytics SDKs are
bundled. Backend API receives the above account data (first-party).

## 9. App Review Notes (paste into Connect)

```text
Test account: sign up with any phone number and enter OTP code 1111
when prompted. The code 1111 is accepted for review builds.

Notes:
- Login is phone + OTP only. The Google and Apple buttons on the login
  screen are placeholders in this build and perform no action.
- The app is localized in English and Arabic; use the in-app language
  setting to switch.
```

> ⚠️ Known risk: the visible-but-inactive Google/Apple buttons may draw
> a Guideline 2.1/4.0 completeness objection. Decision recorded: keep
> for v1. If rejected, remove the buttons and resubmit.

## 10. Build Upload Checklist

- [ ] Version `1.1.0`, build `2` set in `pubspec.yaml` ✅
- [ ] Bundle ID `com.rasad.tavo` on the App ID + provisioning profile
- [ ] Development Team selected in Xcode signing
- [ ] Archive with **Any iOS Device (arm64)** destination
- [ ] Upload via Xcode Organizer → App Store Connect
- [ ] Wait for processing, select build in version 1.1.0 record
- [ ] Fill all sections above, submit for review (manual release)

## 11. Open TODOs (blocking submission)

1. Support URL — must be live.
2. Privacy Policy URL — must be live (required: account data collected).
3. Screenshots (6.9" + 6.5" sets).
4. Confirm launch territories (default: all).
5. Confirm release type (recommended: manual).
6. Decide primary language at app creation (English vs Arabic — permanent).
7. Add Arabic localization on the version page and paste section 5 fields.
