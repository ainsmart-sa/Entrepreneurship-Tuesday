# Tuesday Entrepreneurship — تيوزدية

المشروع موجود داخل مجلد `tuesday-netlify-production`.

## ربط الموقع القائم بـ GitHub على Netlify
- المستودع: `ainsmart-sa/Entrepreneurship-Tuesday`
- **Base directory**: `tuesday-netlify-production`
- **Build command**: `npm run build`
- **Publish directory**: `dist`
- **Functions directory**: `netlify/functions`
- المشروع الحالي على Netlify: `neon-griffin-df3de1`؛ اربط المستودع بنفس الموقع، لا تنشئ موقعًا جديدًا إذا أردت الاحتفاظ بالعنوان.

## متغيرات الإنتاج المطلوبة في Netlify (الإصدار 1.0.4)
هذه **ثلاثة متغيرات إلزامية**. أدخل القيم في Netlify لا في GitHub، مع النطاقين **Builds وFunctions**:

| Name | Value |
|---|---|
| `VITE_SUPABASE_URL` | رابط مشروع Supabase `https://<project-ref>.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | المفتاح العام الذي يبدأ بـ `sb_publishable_` |
| `TICKET_SIGNING_SECRET` | سر خاص عشوائي من `openssl rand -hex 32`؛ فعّل **Contains secret values** |

وظائف Netlify تستخدم القيم العامة من `VITE_` إذا لم توجد أسماء `SUPABASE_URL` و`SUPABASE_ANON_KEY` المكررة. إذا كانت هذه الأسماء المكررة موجودة، فيجب أن تطابق قيم `VITE_` تمامًا. لا تضع مفاتيح `sb_secret_` أو `service_role` في `VITE_` أو GitHub.

أضف السر داخل إعدادات الموقع ثم **أعد بناء المصدر**؛ رفع `dist` قديم لا يطبق التغييرات.

## بيانات قاعدة البيانات
ملف `supabase/migrations/001_initial.sql` مخصص للتنفيذ الأول فقط، ولا تعِد تشغيله على قاعدة بيانات قائمة. تأكد من الجداول وصلاحيات RLS وحساب المالك وصحة البريد OTP قبل استقبال أي حجز حقيقي.

## جاهزية الإنتاج
اختبار CI يفحص قابلية البناء فقط؛ لا يثبت الاتصال الحي بقاعدة Supabase أو سلامة الدفع أو ماسح QR. اختبر دورة الحجز والمراجعة وإصدار التذكرة ومسحها ثم رفض تكرار المسح على موقع التجربة قبل نشر الرابط للعملاء.

رابط لوحة الإدارة بعد الإعداد: https://neon-griffin-df3de1.netlify.app/admin
