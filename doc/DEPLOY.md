# Snapzle Deployment & Operations Guide

## ১. Render.com-এ Spring Boot ব্যাকএন্ড ডিপ্লয় করা

1. [dashboard.render.com](https://dashboard.render.com)-এ লগইন করুন।
2. **New +** -> **Web Service** সিলেক্ট করুন।
3. আপনার **Snapzle** গিটহাব রিপোজিটরি কানেক্ট করুন।
4. কনফিগারেশন সেটিংস:
   * **Name**: `snapzle-backend`
   * **Root Directory**: `server`
   * **Runtime / Environment**: `Docker`
   * **Region**: `Singapore` (or Frankfurt)
   * **Instance Type**: `Free` ($0/mo)
5. **Environment Variables** সেকশনে নিচের ৪টি ভেরিয়েবল যোগ করুন:

| Key | Value |
| :--- | :--- |
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `SPRING_DATASOURCE_URL` | `jdbc:postgresql://db.YOUR_PROJECT_REF.supabase.co:5432/postgres` |
| `SPRING_DATASOURCE_USERNAME` | `postgres` |
| `SPRING_DATASOURCE_PASSWORD` | `Snapzle@2026` |
| `SUPABASE_JWT_SECRET` | আপনার Supabase Project Settings -> API -> JWT Secret |

6. **Create Web Service** বাটনে ক্লিক করুন। ২–৩ মিনিটে বিল্ড হয়ে ইউআরএল রেডি হবে:
   `https://snapzle-backend-xxxx.onrender.com`

---

## ২. Render স্লিপ ঠেকানোর অটো-পিং সেটআপ (Spindown Prevention)

Render ফ্রি টায়ারে ১৫ মিনিট পর স্লিপ মোডে চলে যায়। এটি সারা দিন-রাত জাগিয়ে রাখতে:

1. [cron-job.org](https://cron-job.org) অথবা [uptimerobot.com](https://uptimerobot.com)-এ ফ্রি একাউন্ট খুলুন।
2. **Create Cronjob / Monitor**-এ ক্লিক করুন।
3. **URL**: `https://snapzle-backend-xxxx.onrender.com/health` দিন।
4. **Schedule / Interval**: প্রতি **14 minutes (১৪ মিনিট)** সেট করুন।
5. সেভ করে দিন। এখন সার্ভার কখনো স্লিপে যাবে না এবং ০ সেকেন্ডে ইনস্ট্যান্ট রেসপন্স করবে!

---

## ৩. Flutter মোবাইল অ্যাপ কনফিগারেশন ও রান করা

1. [ui/lib/main.dart](file:///d:/LiMoN/Programming/Git-Online/GitHub/Snapzle/ui/lib/main.dart)-এ আপনার Supabase ক্রেডেনশিয়াল বসান:
   ```dart
   await Supabase.initialize(
     url: 'https://YOUR_PROJECT.supabase.co',
     anonKey: 'YOUR_ANON_KEY',
   );
   ```

2. [ui/lib/services/api_service.dart](file:///d:/LiMoN/Programming/Git-Online/GitHub/Snapzle/ui/lib/services/api_service.dart)-এ ব্যাকএন্ড ইউআরএল বসান:
   ```dart
   // লোকাল এমুলেটরে টেস্ট করতে:
   static const String baseUrl = 'http://10.0.2.2:8080/api';

   // অথবা Render-এ ডিপ্লয় করার পর:
   static const String baseUrl = 'https://snapzle-backend-xxxx.onrender.com/api';
   ```

3. অ্যাপ রান করা:
   ```bash
   cd ui
   flutter run
   ```

4. প্রোডাকশন APK তৈরি করা:
   ```bash
   cd ui
   flutter build apk --release
   ```
