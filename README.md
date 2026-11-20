# AI Mobile Game Studio

استوديو تطوير ألعاب موبايل يعمل عبر GitHub Actions. يخطط، يصمم، يولد ملفات المشروع، ويراجع الجودة بمساعدة وكلاء AI.

## التشغيل
1. أضف Secret باسم `ANTHROPIC_API_KEY` في Settings → Secrets and variables → Actions.
2. من Actions شغّل workflow باسم **AI Game Studio Sprint**.
3. راجع ملفات `docs/` و`meetings/` و`game/` الناتجة عن التشغيل.

التشغيل المجدول يوميًا الساعة 06:00 UTC، ويمكن إيقافه من `.github/workflows/studio.yml`.

## حدود النسخة
الـQA يراجع الملفات ولا يدّعي تشغيل اللعبة على هاتف. بناء APK يحتاج إعداد Godot/Android إضافيًا. استدعاءات API قد تستهلك رصيدًا.
