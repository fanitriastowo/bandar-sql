Swing Criteria 
MarketCap < 5_000_000_000_000
AND FreeFloat < 40
AND Close > MA50
AND MA50 > MA100
AND MA100 > MA200
AND AvgVolume(20) > AvgVolume(60)
AND Volume > AvgVolume(20)
AND Value > 5000000000
AND Highest(60)/Lowest(60) < 1.8
AND Close >= Highest(20)
AND RSI(14) > 55 AND RSI(14) < 70
AND Close / MA200 < 2
AND (High - Low) / Close < 0.12

1️⃣ MarketCap < 5.000.000.000.000
🔍 Tujuan
Menyaring saham yang MASIH PUNYA RUANG BESAR untuk naik.
🧠 Kenapa dipakai
	Saham ribuan persen hampir tidak pernah datang dari big cap
	Market cap kecil = uang masuk sedikit → efek ke harga besar
❌ Kalau dihilangkan
	Screener diisi saham besar
	Kenaikan mentok 10–30%
	Tidak cocok target besar

2️⃣ FreeFloat < 40
🔍 Tujuan
Mencari saham yang mudah digerakkan oleh bandar / institusi.
🧠 Kenapa dipakai
	Free float kecil = suplai terbatas
	Permintaan sedikit saja → harga naik cepat
❌ Kalau dihilangkan
	Saham naik lambat
	Perlu dana besar buat gerakin harga

3️⃣ Close > MA50
🔍 Tujuan
Pastikan saham sudah keluar dari fase turun.
🧠 Kenapa dipakai
	Kita tidak mau bottom fishing
	Ini filter awal supaya tidak nyangkut lama
❌ Kalau dihilangkan
	Banyak saham downtrend masuk
	Psikologis & waktu terkuras

4️⃣ MA50 > MA100
🔍 Tujuan
Menandakan trend mulai terbentuk.
🧠 Kenapa dipakai
	MA50 = uang cepat
	MA100 = uang menengah
	MA50 di atas MA100 = uang baru masuk

5️⃣ MA100 > MA200
🔍 Tujuan
Memastikan trend jangka panjang sudah searah.
🧠 Kenapa dipakai
	Saham besar tidak lahir di trend turun
	Ini memastikan fondasi naik sudah ada
❌ Kalau dihilangkan
	Banyak false rally
	Naik sebentar lalu jatuh

6️⃣ AvgVolume(20) > AvgVolume(60)
🔍 Tujuan
Deteksi akumulasi bertahap.
🧠 Kenapa dipakai
	Volume 1 bulan lebih besar dari 3 bulan
	Artinya ada minat yang meningkat, bukan kebetulan
❌ Kalau dihilangkan
	Saham sepi ikut masuk
	Sulit lanjut naik

7️⃣ Volume > AvgVolume(20)
🔍 Tujuan
Pastikan hari ini ada aksi nyata, bukan saham mati.
🧠 Kenapa dipakai
	Sinyal hanya muncul kalau ada partisipasi pasar
	Menghindari saham “lolos di data lama”

8️⃣ Value > 5.000.000.000
🔍 Tujuan
Filter likuiditas uang, bukan hanya lot.
🧠 Kenapa dipakai
	Volume bisa besar tapi nilai kecil
	Value memastikan uang serius yang masuk
❌ Kalau dihilangkan
	Saham gorengan tipis masuk
	Susah keluar kalau salah

9️⃣ Highest(60) / Lowest(60) < 1.8
🔍 Tujuan
Pastikan saham belum naik terlalu jauh.
🧠 Kenapa dipakai
	Kita mau awal trend, bukan akhir
	Saham ribuan persen naik bertahap, bukan loncat
❌ Kalau dihilangkan
	Saham yang sudah naik 200% ikut masuk
	Risiko koreksi besar

🔟 Close >= Highest(20)
🔍 Tujuan
Mencari breakout sehat dari konsolidasi.
🧠 Kenapa dipakai
	Harga menembus base → fase baru dimulai
	Titik psikologis paling kuat

1️⃣1️⃣ RSI(14) > 55 AND RSI(14) < 70
🔍 Tujuan
Masuk di awal momentum, bukan euforia.
🧠 Kenapa dipakai
	RSI < 55 → belum valid
	RSI > 70 → rawan distribusi

1️⃣2️⃣ Close / MA200 < 2
🔍 Tujuan
Anti masuk di pucuk.
🧠 Kenapa dipakai
	Saham ekstrem naik bertahap dari MA200
	Kalau terlalu jauh → risiko koreksi

1️⃣3️⃣ (High - Low) / Close < 0.12
🔍 Tujuan
Filter fake breakout & distribusi.
🧠 Kenapa dipakai
	Candle terlalu besar = tarik-ulur
	Breakout sehat range rapi
❌ Kalau dihilangkan
	Banyak saham “naik hari ini, turun besok”


