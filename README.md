# Tuesday Entrepreneurship — تيوزدية

المشروع موجود داخل مجلد `tuesday-netlify-production`.

## ربط الموقع القائم بـ GitHub على Netlify
- المستودع: `ainsmart-sa/Entrepreneurship-Tuesday`
- **Base directory**: `tuesday-netlify-production`
- **Build command**: `npm run build`
- **Publish directory**: `dist`
- **Functions directory**: `netlify/functions`
- المشروع الحالي على Netlify: `neon-griffin-df3de1`؛ اربط المستودع بنفس الموقع، لا تنشئ موقعًا جديدًا إذا أردت الاحتفاظ بالعنوان.

## متغيرات الإنتاج المطلوبة في Netlify
اضبط المفاتيح داخل Netlify (لا ترفعها إلى GitHub):

| Name | Value |
|---|---|
| `VITE_SUPABASE_URL` | رابط مشروع Supabase |
| `VITE_SUPABASE_ANON_KEY` | المفتاح العام Publishable |
| `SUPABASE_URL` | نفس رابط المشروع |
| `SUPABASE_ANON_KEY` | نفس المفتاح العام |
| `TICKET_SIGNING_SECRET` | سر عشوائي مولّد حديثًا بطول 32 حرفًا على الأقل |

**لا تضف مفاتيح `sb_secret_` أو `service_role` داخل متغيرات `VITE_` ولا في المستودع.**

إذا أوقف `scripts/verify-env.mjs` البناء بسبب متغير ناقص، أكمل إعداده في Netlify ثم أعد البناء من المصدر. لا تستخدم نسخة `dist` قديمة.

## بيانات قاعدة البيانات
ملف `supabase/migrations/001_initial.sql` مخصص للتنفيذ الأول فقط، ولا تعِد تشغيله على قاعدة بيانات قائمة. تأكد من الجداول وصلاحيات RLS وحساب المالك وصحة البريد OTP قبل استقبال أي حجز حقيقي.

## جاهزية الإنتاج
اختبار CI يفحص قابلية البناء فقط؛ لا يثبت الاتصال الحي بقاعدة Supabase أو سلامة الدفع أو ماسح QR. اختبر دورة الحجز والمراجعة وإصدار التذكرة ومسحها ثم رفض تكرار المسح على موقع التجربة قبل نشر الرابط للعملاء.

رابط لوحة الإدارة بعد الإعداد: https://neon-griffin-df3de1.netlify.app/admin
