# AI Mobile Game Studio

استوديو تطوير ألعاب موبايل يعمل عبر GitHub Actions، ويستخدم Gemini API لتخطيط وتصميم وتوليد ملفات المشروع ومراجعة الجودة.

## الإعداد
1. من Settings → Secrets and variables → Actions أضف Secret باسم `GEMINI_API_KEY`.
2. من Actions شغّل **AI Game Studio Sprint** باستخدام Run workflow.
3. راجع ملفات `docs/` و`meetings/` و`game/` الناتجة عن التشغيل.

التشغيل المجدول يوميًا الساعة 06:00 UTC. يمكن إيقافه من `.github/workflows/studio.yml`.

## الموديل
الافتراضي `gemini-3.8-flash`. يمكن تغيير الموديل بإضافة متغير Repository باسم `GEMINI_MODEL`.

## حدود النسخة
الـQA يراجع ملفات المصدر ولا يدّعي تشغيل اللعبة على هاتف. بناء APK يحتاج إعداد Godot/Android إضافيًا. استدعاءات Gemini API تخضع لحدود الخدمة.
