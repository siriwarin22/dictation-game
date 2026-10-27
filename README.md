# สมุดตามคำบอก

เกมเขียนตามคำบอกภาษาไทยและอังกฤษ 6 ด่าน คลังคำด่านละ 40 คำ พร้อม badge, ประวัติ, ตารางอันดับ และห้องเล่นสดแบบ Kahoot

- `index.html` — ตัวเกมทั้งหมด
- `supabase.js` — ไลบรารี Supabase (v2.117.2) ไว้ต่อฐานข้อมูลอันดับและห้องเล่นสด
- `badges/` — รูป badge
- `supabase.sql` — สคริปต์สร้างฐานข้อมูล (รันครั้งเดียวใน Supabase SQL Editor)

Deploy: Netlify ดึงจาก repo นี้ ไม่ต้องมี build command, publish directory คือโฟลเดอร์ราก
