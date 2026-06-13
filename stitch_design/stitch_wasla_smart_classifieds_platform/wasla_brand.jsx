import { useState } from "react";

// ═══════════════════════════════════════════════════════════
//  DESIGN TOKENS — وصلة Brand System v1.0
// ═══════════════════════════════════════════════════════════
const C = {
  // Primary: الفيروز المصري — not used by ANY Egyptian classifieds competitor
  p50:    "#E4F4F6",
  p100:   "#B8E2E6",
  p200:   "#74C4CC",
  p500:   "#0E9AA6",
  p600:   "#0D7A84",   // ← Primary
  p700:   "#0A606A",
  p800:   "#074650",
  p900:   "#032B30",

  // Accent: الذهب المصري — warm, trust, local value
  a50:    "#FEF5E4",
  a100:   "#FDE5B0",
  a300:   "#F7C04A",
  a500:   "#E89510",   // ← Accent
  a600:   "#C97C0C",
  a800:   "#7A4B07",

  // Neutrals: رمال دافئة
  n0:     "#FFFFFF",
  n50:    "#F9F7F3",   // ← Page background
  n100:   "#F0EDE7",
  n200:   "#EAE4DA",
  n300:   "#D5CEC3",
  n400:   "#B0A89C",
  n500:   "#8A8278",
  n600:   "#6E6459",
  n700:   "#4E473E",
  n800:   "#302B24",
  n900:   "#161210",

  // Semantic
  green:  "#16A34A",
  red:    "#DC2626",
  purple: "#7C3AED",
  orange: "#C2410C",
  blue:   "#0369A1",
  yellow: "#854D0E",
};

// ═══════════════════════════════════════════════════════════
//  LOGO COMPONENTS
// ═══════════════════════════════════════════════════════════
function LogoMark({ size = 48, variant = "color" }) {
  const teal  = variant === "white" ? "#FFFFFF" : C.p600;
  const gold  = variant === "white" ? "rgba(255,255,255,0.85)" : C.a500;
  const ghost = variant === "white" ? "rgba(255,255,255,0.25)" : C.p200 + "99";
  return (
    <svg width={size} height={size * 0.6} viewBox="0 0 80 48" fill="none">
      {/* Left node */}
      <circle cx="12" cy="36" r="12" fill={teal} />
      {/* Right node */}
      <circle cx="68" cy="36" r="12" fill={teal} />
      {/* Primary golden arc — the wasla itself */}
      <path d="M 23 33 C 30 12 50 12 57 33" stroke={gold} strokeWidth="4.5" fill="none" strokeLinecap="round"/>
      {/* Secondary ghost arc — depth */}
      <path d="M 23 39 C 30 52 50 52 57 39" stroke={ghost} strokeWidth="2.5" fill="none" strokeLinecap="round"/>
      {/* Apex dot — the meeting point */}
      <circle cx="40" cy="13" r="5.5" fill={gold} />
    </svg>
  );
}

function LogoFull({ size = 48, variant = "color" }) {
  const textColor = variant === "white" ? "#FFFFFF" : C.p900;
  return (
    <div style={{ display: "inline-flex", alignItems: "center", gap: size * 0.22, direction: "rtl" }}>
      <LogoMark size={size} variant={variant} />
      <span style={{
        fontFamily: "'Cairo', sans-serif",
        fontWeight: 900,
        fontSize: size * 0.75,
        color: textColor,
        letterSpacing: "0.01em",
        lineHeight: 1,
        marginTop: size * 0.04,
      }}>وصلة</span>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
//  UI BUILDING BLOCKS
// ═══════════════════════════════════════════════════════════
function Tag({ label, bg, color }) {
  return (
    <span style={{
      background: bg, color,
      padding: "5px 14px", borderRadius: "20px",
      fontSize: "12px", fontWeight: 700,
      whiteSpace: "nowrap",
    }}>{label}</span>
  );
}

function SectionLabel({ id, title, subtitle }) {
  return (
    <div style={{ marginBottom: "32px" }}>
      <span style={{
        display: "inline-block",
        background: C.p50, color: C.p600,
        padding: "2px 12px", borderRadius: "20px",
        fontSize: "11px", fontWeight: 800,
        letterSpacing: "0.08em", marginBottom: "8px",
        fontFamily: "'IBM Plex Mono', monospace",
      }}>{id.toUpperCase()}</span>
      <h2 style={{ fontSize: "26px", fontWeight: 900, color: C.n900, margin: 0, lineHeight: 1.2 }}>{title}</h2>
      {subtitle && <p style={{ fontSize: "14px", color: C.n600, marginTop: "6px", margin: 0, marginTop: 6 }}>{subtitle}</p>}
    </div>
  );
}

function Card({ children, style = {} }) {
  return (
    <div style={{
      background: C.n0,
      border: `1px solid ${C.n200}`,
      borderRadius: "16px",
      padding: "24px",
      ...style,
    }}>{children}</div>
  );
}

function ColorSwatch({ name, hex, desc, tall = false }) {
  const [cp, setCp] = useState(false);
  const copy = () => { navigator.clipboard?.writeText(hex).catch(() => {}); setCp(true); setTimeout(() => setCp(false), 1500); };
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  const light = (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.55;
  const fg = light ? C.n800 : "#FFFFFF";
  return (
    <div onClick={copy} style={{
      background: hex,
      borderRadius: "12px",
      padding: "14px 12px",
      cursor: "pointer",
      height: tall ? "120px" : "88px",
      display: "flex", flexDirection: "column",
      justifyContent: "space-between",
      border: hex === "#FFFFFF" || hex === C.n0 ? `1px solid ${C.n200}` : "none",
      transition: "transform 0.15s, box-shadow 0.15s",
    }}
      onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-3px)"; e.currentTarget.style.boxShadow = "0 8px 20px rgba(0,0,0,0.13)"; }}
      onMouseLeave={e => { e.currentTarget.style.transform = ""; e.currentTarget.style.boxShadow = ""; }}
    >
      <span style={{ color: fg, fontSize: "11px", fontWeight: 600, opacity: 0.8 }}>{name}</span>
      <div>
        <div style={{ color: fg, fontSize: "12px", fontWeight: 700, fontFamily: "'IBM Plex Mono', monospace" }}>
          {cp ? "✓ copied" : hex.toUpperCase()}
        </div>
        {desc && <div style={{ color: fg, fontSize: "11px", opacity: 0.65, marginTop: "2px" }}>{desc}</div>}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════
//  MAIN BRAND PAGE
// ═══════════════════════════════════════════════════════════
export default function WaslaBrand() {
  const [nav, setNav] = useState("logo");
  const navItems = [
    { id: "logo",   ar: "اللوجو" },
    { id: "colors", ar: "الألوان" },
    { id: "type",   ar: "الخطوط" },
    { id: "comps",  ar: "المكونات" },
    { id: "voice",  ar: "الشخصية" },
  ];
  const go = (id) => { setNav(id); document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" }); };

  return (
    <div style={{ fontFamily: "'Cairo', sans-serif", direction: "rtl", background: C.n50, minHeight: "100vh", color: C.n900 }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cairo:wght@300;400;500;600;700;800;900&family=IBM+Plex+Mono:wght@400;600&display=swap');
        *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: ${C.n50}; }
        ::-webkit-scrollbar { width: 6px; }
        ::-webkit-scrollbar-track { background: ${C.n100}; }
        ::-webkit-scrollbar-thumb { background: ${C.p200}; border-radius: 4px; }
      `}</style>

      {/* ── STICKY NAV ── */}
      <nav style={{
        position: "sticky", top: 0, zIndex: 200,
        background: "rgba(249,247,243,0.92)",
        backdropFilter: "blur(16px)",
        borderBottom: `1px solid ${C.n200}`,
        padding: "0 28px",
        display: "flex", alignItems: "center", justifyContent: "space-between",
        height: "56px",
      }}>
        <LogoFull size={26} />
        <div style={{ display: "flex", gap: "2px" }}>
          {navItems.map(n => (
            <button key={n.id} onClick={() => go(n.id)} style={{
              background: nav === n.id ? C.p50 : "transparent",
              border: "none", padding: "6px 14px", borderRadius: "8px",
              cursor: "pointer", fontSize: "13px", fontFamily: "'Cairo', sans-serif",
              fontWeight: nav === n.id ? 700 : 500,
              color: nav === n.id ? C.p600 : C.n500,
              transition: "all 0.15s",
            }}>{n.ar}</button>
          ))}
        </div>
        <span style={{
          fontSize: "11px", fontFamily: "'IBM Plex Mono', monospace",
          color: C.n400, background: C.n100,
          border: `1px solid ${C.n200}`, padding: "4px 10px", borderRadius: "20px",
        }}>v1.0</span>
      </nav>

      {/* ── HERO ── */}
      <div style={{
        background: `linear-gradient(145deg, ${C.p900} 0%, ${C.p700} 45%, ${C.p500} 100%)`,
        padding: "72px 32px 84px",
        textAlign: "center",
        position: "relative",
        overflow: "hidden",
      }}>
        {/* Ambient glow */}
        <div style={{ position: "absolute", inset: 0, background: "radial-gradient(ellipse at 70% 40%, rgba(232,149,16,0.2) 0%, transparent 60%)", pointerEvents: "none" }}/>
        {/* Grid pattern */}
        <div style={{ position: "absolute", inset: 0, backgroundImage: "radial-gradient(circle, rgba(255,255,255,0.06) 1px, transparent 1px)", backgroundSize: "32px 32px", pointerEvents: "none" }}/>

        <div style={{ position: "relative", zIndex: 1 }}>
          <div style={{ display: "inline-flex", justifyContent: "center" }}>
            <LogoFull size={64} variant="white" />
          </div>
          <p style={{ color: "rgba(255,255,255,0.55)", fontSize: "14px", marginTop: "14px", letterSpacing: "0.04em", fontWeight: 400 }}>
            دليل الهوية البصرية الرسمي — Brand Identity v1.0
          </p>
          <div style={{ display: "flex", gap: "10px", justifyContent: "center", marginTop: "28px", flexWrap: "wrap" }}>
            {["ثقة", "قُرب", "سرعة", "أمان", "مصر"].map(w => (
              <span key={w} style={{
                background: "rgba(255,255,255,0.1)",
                border: "1px solid rgba(255,255,255,0.18)",
                color: "rgba(255,255,255,0.82)",
                padding: "6px 18px", borderRadius: "20px",
                fontSize: "13px", fontWeight: 600,
              }}>{w}</span>
            ))}
          </div>
        </div>
      </div>

      {/* ── CONTENT ── */}
      <div style={{ maxWidth: "980px", margin: "0 auto", padding: "64px 24px 80px" }}>

        {/* ▸▸ LOGO ◂◂ */}
        <section id="logo" style={{ marginBottom: "80px" }}>
          <SectionLabel id="logo" title="اللوجو" subtitle="الشعار هو الواجهة الأولى لعلامة وصلة — الرمز يمثّل وصلة حقيقية بين شخصين" />

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px", marginBottom: "16px" }}>
            <Card style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "16px", minHeight: "200px" }}>
              <LogoFull size={52} />
              <span style={{ fontSize: "12px", color: C.n400, fontWeight: 500 }}>النسخة الرئيسية — خلفية فاتحة</span>
            </Card>
            <Card style={{
              display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "16px",
              minHeight: "200px",
              background: `linear-gradient(135deg, ${C.p900}, ${C.p700})`,
              border: "none",
            }}>
              <LogoFull size={52} variant="white" />
              <span style={{ fontSize: "12px", color: "rgba(255,255,255,0.45)", fontWeight: 500 }}>النسخة البيضاء — خلفية داكنة</span>
            </Card>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px", marginBottom: "16px" }}>
            <Card style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "14px", minHeight: "150px" }}>
              <LogoMark size={56} />
              <span style={{ fontSize: "12px", color: C.n400, fontWeight: 500 }}>الرمز فقط — Icon</span>
            </Card>
            <Card style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "14px", minHeight: "150px" }}>
              <span style={{ fontSize: "44px", fontWeight: 900, color: C.p900, lineHeight: 1 }}>وصلة</span>
              <span style={{ fontSize: "12px", color: C.n400, fontWeight: 500 }}>الاسم فقط — Wordmark</span>
            </Card>
            <Card style={{
              display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: "14px",
              minHeight: "150px", background: C.n900, border: "none",
            }}>
              <LogoFull size={36} variant="white" />
              <span style={{ fontSize: "12px", color: "rgba(255,255,255,0.35)", fontWeight: 500 }}>أحادي اللون</span>
            </Card>
          </div>

          {/* Anatomy */}
          <Card style={{ marginBottom: "16px", background: C.p50, border: `1px solid ${C.p100}` }}>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.p700, marginBottom: "16px" }}>تشريح اللوجو — Logo Anatomy</div>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "40px", padding: "12px 0", flexWrap: "wrap" }}>
              <div style={{ textAlign: "center" }}>
                <svg width="80" height="48" viewBox="0 0 80 48" fill="none">
                  <circle cx="12" cy="36" r="12" fill={C.p200} />
                  <circle cx="12" cy="36" r="5" fill={C.p600} />
                  <text x="12" y="14" textAnchor="middle" fontSize="9" fill={C.p700} fontFamily="Cairo" fontWeight="700">نقطة</text>
                  <text x="12" y="23" textAnchor="middle" fontSize="9" fill={C.p700} fontFamily="Cairo">الطرف</text>
                </svg>
                <div style={{ fontSize: "11px", color: C.p700, fontWeight: 600 }}>نقطة الطرف</div>
              </div>
              <div style={{ textAlign: "center" }}>
                <svg width="80" height="48" viewBox="0 0 80 48" fill="none">
                  <path d="M 10 36 C 18 10 62 10 70 36" stroke={C.a100} strokeWidth="4.5" fill="none" strokeLinecap="round" strokeDasharray="6 4"/>
                  <path d="M 10 36 C 18 10 62 10 70 36" stroke={C.a500} strokeWidth="4.5" fill="none" strokeLinecap="round" strokeDasharray="0 10 100" />
                  <circle cx="40" cy="12" r="5.5" fill={C.a500} />
                  <text x="40" y="44" textAnchor="middle" fontSize="9" fill={C.a600} fontFamily="Cairo" fontWeight="700">القوس الذهبي</text>
                </svg>
                <div style={{ fontSize: "11px", color: C.a600, fontWeight: 600 }}>القوس — الوصلة</div>
              </div>
              <div style={{ textAlign: "center" }}>
                <svg width="80" height="48" viewBox="0 0 80 48" fill="none">
                  <circle cx="40" cy="20" r="12" fill={C.a100} />
                  <circle cx="40" cy="20" r="6" fill={C.a500} />
                  <text x="40" y="42" textAnchor="middle" fontSize="9" fill={C.a600} fontFamily="Cairo" fontWeight="700">نقطة اللقاء</text>
                </svg>
                <div style={{ fontSize: "11px", color: C.a600, fontWeight: 600 }}>نقطة اللقاء</div>
              </div>
            </div>
          </Card>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
            <Card style={{ borderRight: `4px solid ${C.green}` }}>
              <div style={{ color: C.green, fontWeight: 800, fontSize: "13px", marginBottom: "12px" }}>✓ مسموح</div>
              {["استخدم النسخة الكاملة (رمز + اسم) دائماً", "الحفاظ على نسب اللوجو بدون تمديد", "استخدم على خلفيات الـ Brand فقط"].map(t => (
                <div key={t} style={{ fontSize: "13px", color: C.n600, marginBottom: "6px" }}>• {t}</div>
              ))}
            </Card>
            <Card style={{ borderRight: `4px solid ${C.red}` }}>
              <div style={{ color: C.red, fontWeight: 800, fontSize: "13px", marginBottom: "12px" }}>✗ ممنوع</div>
              {["تغيير ألوان الرمز أو الاسم", "وضع اللوجو على خلفيات مزدحمة", "تدوير أو تشويه أي عنصر في الشعار"].map(t => (
                <div key={t} style={{ fontSize: "13px", color: C.n600, marginBottom: "6px" }}>• {t}</div>
              ))}
            </Card>
          </div>
        </section>

        {/* ▸▸ COLORS ◂◂ */}
        <section id="colors" style={{ marginBottom: "80px" }}>
          <SectionLabel id="colors" title="لوحة الألوان" subtitle="الفيروز المصري + الذهب المصري — هوية لا تشبه أي منافس في السوق" />

          {/* Primary */}
          <div style={{ marginBottom: "20px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "12px" }}>
              <div style={{ width: "10px", height: "10px", borderRadius: "50%", background: C.p600 }} />
              <span style={{ fontSize: "13px", fontWeight: 700, color: C.n600 }}>اللون الأساسي — الفيروز المصري</span>
              <span style={{ fontSize: "11px", color: C.n400, fontFamily: "'IBM Plex Mono',monospace" }}>Primary Teal</span>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: "10px" }}>
              <ColorSwatch name="P-50"  hex={C.p50}  desc="خلفيات" />
              <ColorSwatch name="P-100" hex={C.p100} desc="حدود" />
              <ColorSwatch name="P-200" hex={C.p200} desc="عناصر فاتحة" />
              <ColorSwatch name="P-600" hex={C.p600} desc="الأساسي" tall />
              <ColorSwatch name="P-700" hex={C.p700} desc="Hover" tall />
              <ColorSwatch name="P-900" hex={C.p900} desc="داكن جداً" />
            </div>
          </div>

          {/* Accent */}
          <div style={{ marginBottom: "20px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "12px" }}>
              <div style={{ width: "10px", height: "10px", borderRadius: "50%", background: C.a500 }} />
              <span style={{ fontSize: "13px", fontWeight: 700, color: C.n600 }}>اللون المميز — الذهب المصري</span>
              <span style={{ fontSize: "11px", color: C.n400, fontFamily: "'IBM Plex Mono',monospace" }}>Accent Gold</span>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(6, 1fr)", gap: "10px" }}>
              <ColorSwatch name="A-50"  hex={C.a50}  desc="خلفيات" />
              <ColorSwatch name="A-100" hex={C.a100} desc="حدود" />
              <ColorSwatch name="A-300" hex={C.a300} desc="فاتح" />
              <ColorSwatch name="A-500" hex={C.a500} desc="المميز" tall />
              <ColorSwatch name="A-600" hex={C.a600} desc="Hover" tall />
              <ColorSwatch name="A-800" hex={C.a800} desc="داكن" />
            </div>
          </div>

          {/* Neutrals */}
          <div style={{ marginBottom: "20px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "8px", marginBottom: "12px" }}>
              <div style={{ width: "10px", height: "10px", borderRadius: "50%", background: C.n500 }} />
              <span style={{ fontSize: "13px", fontWeight: 700, color: C.n600 }}>الألوان المحايدة — رمال دافئة</span>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: "10px" }}>
              <ColorSwatch name="White" hex={C.n0}   desc="سطوح" />
              <ColorSwatch name="N-50"  hex={C.n50}  desc="خلفية الصفحة" />
              <ColorSwatch name="N-100" hex={C.n100} desc="hover" />
              <ColorSwatch name="N-200" hex={C.n200} desc="حدود" />
              <ColorSwatch name="N-500" hex={C.n500} desc="نص ثانوي" />
              <ColorSwatch name="N-700" hex={C.n700} desc="نص رئيسي" />
              <ColorSwatch name="N-900" hex={C.n900} desc="الأداكن" />
            </div>
          </div>

          {/* Semantic */}
          <div>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "12px" }}>ألوان الحالات — Semantic</div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "10px" }}>
              <ColorSwatch name="Success" hex={C.green}  desc="نجاح / موثّق" />
              <ColorSwatch name="Error"   hex={C.red}    desc="خطأ / تحذير" />
              <ColorSwatch name="Info"    hex={C.blue}   desc="معلومات" />
              <ColorSwatch name="Warning" hex={C.a500}   desc="تنبيه" />
            </div>
          </div>
        </section>

        {/* ▸▸ TYPOGRAPHY ◂◂ */}
        <section id="type" style={{ marginBottom: "80px" }}>
          <SectionLabel id="type" title="منظومة الخطوط" subtitle="Cairo — مصمم خصيصاً للعربية، يحمل روح الحداثة والوضوح" />

          <Card style={{ marginBottom: "16px" }}>
            {[
              { role: "Display", weight: 900, size: "52px", lh: 1.1, sample: "وصّل. وثّق. ابنِ." },
              { role: "H1",      weight: 800, size: "34px", lh: 1.2, sample: "ابحث عن الخدمة التي تحتاجها الآن" },
              { role: "H2",      weight: 700, size: "26px", lh: 1.3, sample: "إعلانات موثّقة من جيرانك" },
              { role: "H3",      weight: 600, size: "20px", lh: 1.4, sample: "تواصل مباشر — بدون وسيط وبدون رسوم" },
              { role: "Body",    weight: 400, size: "16px", lh: 1.75, sample: "منصة وصلة تربطك بالحرفيين والخدمات المحلية في مدينتك بشكل مباشر وآمن. انشر إعلانك مجاناً وتواصل مع الآلاف." },
              { role: "Small",   weight: 500, size: "13px", lh: 1.5,  sample: "منذ ٣ ساعات · المعادي، القاهرة · قسم الخدمات" },
            ].map(({ role, weight, size, lh, sample }, i, arr) => (
              <div key={role} style={{
                paddingBottom: i < arr.length - 1 ? "22px" : 0,
                marginBottom: i < arr.length - 1 ? "22px" : 0,
                borderBottom: i < arr.length - 1 ? `1px solid ${C.n100}` : "none",
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: "10px", marginBottom: "8px" }}>
                  <span style={{ fontSize: "11px", color: C.n400, fontFamily: "'IBM Plex Mono',monospace", minWidth: "52px" }}>{role}</span>
                  <span style={{ fontSize: "11px", color: C.n300, fontFamily: "'IBM Plex Mono',monospace" }}>{weight} · {size}</span>
                </div>
                <div style={{ fontSize: size, fontWeight: weight, lineHeight: lh, color: C.n800 }}>{sample}</div>
              </div>
            ))}
          </Card>

          <Card style={{ background: C.p50, border: `1px solid ${C.p100}` }}>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.p700, marginBottom: "16px" }}>قواعد أساسية</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "16px" }}>
              {[
                { label: "العناوين", rule: "وزن 700-900 دائماً، لا تستخدم 400 في العناوين أبداً" },
                { label: "جسم النص", rule: "وزن 400-500 فقط، line-height لا تقل عن 1.65 للقراءة" },
                { label: "الأرقام", rule: "IBM Plex Mono للأرقام والأكواد، Cairo لباقي النصوص" },
              ].map(({ label, rule }) => (
                <div key={label}>
                  <div style={{ fontSize: "12px", fontWeight: 800, color: C.p600, marginBottom: "6px" }}>{label}</div>
                  <div style={{ fontSize: "13px", color: C.n600, lineHeight: 1.6 }}>{rule}</div>
                </div>
              ))}
            </div>
          </Card>
        </section>

        {/* ▸▸ COMPONENTS ◂◂ */}
        <section id="comps" style={{ marginBottom: "80px" }}>
          <SectionLabel id="comps" title="مكونات الواجهة" subtitle="عناصر UI الأساسية — مبنية على نظام الألوان والخطوط تماماً" />

          {/* Buttons */}
          <Card style={{ marginBottom: "16px" }}>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "16px" }}>الأزرار — Buttons</div>
            <div style={{ display: "flex", gap: "12px", flexWrap: "wrap", alignItems: "center" }}>
              {[
                { label: "انشر إعلانك", bg: C.p600, color: "#FFF", border: "none" },
                { label: "⭐ ترقية مميزة", bg: C.a500, color: "#FFF", border: "none" },
                { label: "تصفح الإعلانات", bg: "transparent", color: C.p600, border: `2px solid ${C.p600}` },
                { label: "المزيد", bg: C.p50, color: C.p600, border: "none" },
                { label: "حذف", bg: "#FEE2E2", color: C.red, border: "none" },
              ].map(({ label, bg, color, border }) => (
                <button key={label} style={{
                  background: bg, color, border: border || "none",
                  padding: "11px 22px", borderRadius: "10px",
                  fontSize: "14px", fontFamily: "'Cairo',sans-serif", fontWeight: 700,
                  cursor: "pointer", transition: "opacity 0.15s",
                }}
                  onMouseEnter={e => e.currentTarget.style.opacity = "0.85"}
                  onMouseLeave={e => e.currentTarget.style.opacity = "1"}
                >{label}</button>
              ))}
            </div>
          </Card>

          {/* Search bar */}
          <Card style={{ marginBottom: "16px" }}>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "16px" }}>شريط البحث</div>
            <div style={{ display: "flex", gap: "10px" }}>
              <div style={{
                flex: 1, display: "flex", alignItems: "center", gap: "10px",
                background: C.n50, border: `1.5px solid ${C.n200}`,
                borderRadius: "12px", padding: "12px 16px",
              }}>
                <span>🔍</span>
                <input placeholder="ابحث عن خدمة، حرفي، أو إعلان..." readOnly style={{
                  border: "none", background: "transparent", outline: "none",
                  fontSize: "14px", fontFamily: "'Cairo',sans-serif", color: C.n400,
                  flex: 1, direction: "rtl", cursor: "default",
                }} />
              </div>
              <div style={{
                display: "flex", alignItems: "center", gap: "8px",
                background: C.n50, border: `1.5px solid ${C.n200}`,
                borderRadius: "12px", padding: "12px 14px",
              }}>
                <span style={{ fontSize: "14px" }}>📍</span>
                <span style={{ fontSize: "13px", color: C.n600, fontWeight: 500 }}>القاهرة</span>
                <span style={{ color: C.n400, fontSize: "12px" }}>▾</span>
              </div>
              <button style={{
                background: C.p600, color: "#FFF", border: "none",
                padding: "12px 24px", borderRadius: "12px",
                fontSize: "14px", fontFamily: "'Cairo',sans-serif", fontWeight: 700, cursor: "pointer",
              }}>بحث</button>
            </div>
          </Card>

          {/* Ad Cards */}
          <Card style={{ marginBottom: "16px" }}>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "16px" }}>بطاقة الإعلان — Ad Card</div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>

              {/* Standard card */}
              <div style={{ border: `1px solid ${C.n200}`, borderRadius: "14px", overflow: "hidden", background: C.n0 }}>
                <div style={{
                  height: "150px", background: `linear-gradient(135deg, ${C.p50}, ${C.p100}55)`,
                  display: "flex", alignItems: "center", justifyContent: "center", fontSize: "44px",
                }}>🔧</div>
                <div style={{ padding: "14px 16px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "6px" }}>
                    <span style={{ fontSize: "15px", fontWeight: 700, color: C.n900 }}>سباك محترف</span>
                    <Tag label="خدمات" bg={C.p50} color={C.p600} />
                  </div>
                  <div style={{ fontSize: "21px", fontWeight: 900, color: C.p600, marginBottom: "6px" }}>١٥٠ ج.م / ساعة</div>
                  <div style={{ fontSize: "12px", color: C.n400, display: "flex", gap: "10px", marginBottom: "12px" }}>
                    <span>📍 المعادي</span><span>⏱ منذ ٢ ساعة</span>
                  </div>
                  <div style={{ display: "flex", gap: "8px" }}>
                    <button style={{ flex: 1, background: C.p600, color: "#FFF", border: "none", padding: "10px", borderRadius: "8px", fontSize: "13px", fontFamily: "'Cairo',sans-serif", fontWeight: 700, cursor: "pointer" }}>📞 تواصل</button>
                    <button style={{ background: C.p50, color: C.p500, border: "none", padding: "10px 14px", borderRadius: "8px", fontSize: "16px", cursor: "pointer" }}>♡</button>
                  </div>
                </div>
              </div>

              {/* Featured card */}
              <div style={{ border: `2px solid ${C.a500}`, borderRadius: "14px", overflow: "hidden", background: C.n0, position: "relative" }}>
                <div style={{ position: "absolute", top: "10px", right: "10px", background: C.a500, color: "#FFF", padding: "3px 10px", borderRadius: "20px", fontSize: "11px", fontWeight: 800, zIndex: 1 }}>⭐ مميز</div>
                <div style={{
                  height: "150px", background: `linear-gradient(135deg, ${C.a50}, ${C.a100}55)`,
                  display: "flex", alignItems: "center", justifyContent: "center", fontSize: "44px",
                }}>📚</div>
                <div style={{ padding: "14px 16px" }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "6px" }}>
                    <span style={{ fontSize: "15px", fontWeight: 700, color: C.n900 }}>مدرس رياضيات</span>
                    <Tag label="تعليم" bg="#FEF9C3" color={C.yellow} />
                  </div>
                  <div style={{ fontSize: "21px", fontWeight: 900, color: C.a500, marginBottom: "6px" }}>٢٠٠ ج.م / حصة</div>
                  <div style={{ fontSize: "12px", color: C.n400, display: "flex", gap: "10px", marginBottom: "12px" }}>
                    <span>📍 مصر الجديدة</span><span>⏱ منذ ٣٠ دقيقة</span>
                  </div>
                  <div style={{ display: "flex", gap: "8px" }}>
                    <button style={{ flex: 1, background: C.a500, color: "#FFF", border: "none", padding: "10px", borderRadius: "8px", fontSize: "13px", fontFamily: "'Cairo',sans-serif", fontWeight: 700, cursor: "pointer" }}>📞 تواصل</button>
                    <button style={{ background: C.a50, color: C.a500, border: "none", padding: "10px 14px", borderRadius: "8px", fontSize: "16px", cursor: "pointer" }}>♡</button>
                  </div>
                </div>
              </div>

            </div>
          </Card>

          {/* Tags & Badges */}
          <Card>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "16px" }}>الشارات والتصنيفات — Badges & Tags</div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "10px" }}>
              <Tag label="✓ موثّق" bg="#DCFCE7" color="#15803D" />
              <Tag label="⭐ مميز" bg={C.a50} color={C.a600} />
              <Tag label="جديد" bg={C.p50} color={C.p600} />
              <Tag label="خدمات" bg="#EDE9FE" color={C.purple} />
              <Tag label="تعليم" bg="#FEF9C3" color={C.yellow} />
              <Tag label="عقارات" bg="#FFEDD5" color={C.orange} />
              <Tag label="سيارات" bg="#F0F9FF" color={C.blue} />
              <Tag label="مطلوب" bg="#FEE2E2" color={C.red} />
              <Tag label="معروض" bg="#DCFCE7" color="#15803D" />
              <Tag label="قاهرة" bg={C.n100} color={C.n600} />
              <Tag label="إسكندرية" bg={C.n100} color={C.n600} />
            </div>
          </Card>
        </section>

        {/* ▸▸ VOICE ◂◂ */}
        <section id="voice" style={{ marginBottom: "80px" }}>
          <SectionLabel id="voice" title="شخصية العلامة" subtitle="وصلة ليست مجرد تطبيق — لها صوت وشخصية مميزة بين المصريين" />

          <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "16px", marginBottom: "16px" }}>
            {[
              { icon: "🤝", title: "موثوق",         desc: "نتحقق من كل إعلان. الثقة ليست ميزة — هي الأساس الذي بُنيت عليه وصلة." },
              { icon: "⚡", title: "مباشر وسريع",   desc: "بدون لف ودوران. البائع والمشتري يتواصلوا خلال دقائق من النشر." },
              { icon: "🏘️", title: "محلي وقريب",   desc: "نحن لسنا OLX الدولي. نحن منصتك في حيّك، مدينتك، بلدك." },
            ].map(({ icon, title, desc }) => (
              <Card key={title} style={{ textAlign: "center" }}>
                <div style={{ fontSize: "40px", marginBottom: "12px" }}>{icon}</div>
                <div style={{ fontSize: "17px", fontWeight: 800, color: C.n900, marginBottom: "8px" }}>{title}</div>
                <div style={{ fontSize: "13px", color: C.n600, lineHeight: 1.65 }}>{desc}</div>
              </Card>
            ))}
          </div>

          <Card>
            <div style={{ fontSize: "13px", fontWeight: 700, color: C.n600, marginBottom: "16px" }}>صوت وصلة في الكتابة — Brand Voice</div>
            <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
              {[
                { ctx: "ترحيب",       txt: "أهلاً في وصلة 👋 — ابدأ بنشر أول إعلان لك، أو ابحث عما تحتاجه الآن." },
                { ctx: "بعد النشر",   txt: "إعلانك منشور! سيصل لآلاف الباحثين في منطقتك. ✓" },
                { ctx: "توثيق ناجح", txt: "تم التحقق من حسابك — أصبحت معلناً موثوقاً في وصلة. 🔒" },
                { ctx: "صفحة فارغة", txt: "لا توجد إعلانات هنا بعد — كن أول من ينشر في هذه المنطقة!" },
                { ctx: "خطأ",         txt: "حدث خطأ في الاتصال. تحقق من الإنترنت وحاول مرة أخرى." },
              ].map(({ ctx, txt }) => (
                <div key={ctx} style={{
                  display: "flex", gap: "14px", alignItems: "flex-start",
                  background: C.n50, borderRadius: "10px", padding: "12px 14px",
                }}>
                  <Tag label={ctx} bg={C.p50} color={C.p600} />
                  <span style={{ fontSize: "14px", color: C.n700, lineHeight: 1.65 }}>{txt}</span>
                </div>
              ))}
            </div>
          </Card>
        </section>

        {/* Footer */}
        <div style={{
          textAlign: "center",
          paddingTop: "40px",
          borderTop: `1px solid ${C.n200}`,
        }}>
          <div style={{ display: "inline-flex", justifyContent: "center" }}>
            <LogoFull size={30} />
          </div>
          <p style={{ fontSize: "12px", color: C.n400, marginTop: "10px", fontFamily: "'IBM Plex Mono',monospace" }}>
            Brand Identity System v1.0 · وصلة — منصة الإعلانات المبوّبة في مصر
          </p>
        </div>

      </div>
    </div>
  );
}
