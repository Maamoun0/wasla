"""Builds docs/data/ADMIN_MAPPING.md (and a JSON copy for the migration) from
the COD-AB administrative boundaries of Egypt (CAPMAS, via HDX, CC BY-IGO).

Usage:
  python -I scripts/data/build_admin_mapping.py data/sources/egy_admin_boundaries.xlsx \
      <cities.psv> <out.md> <out.json>

<cities.psv> is the current cities table (id|governorate_id|governorate|name),
exported with psql, so existing cities can be linked to their P-code.

The classification is a proposal for human review; nothing is written to the
database by this script.
"""
import json
import re
import sys
import unicodedata

import openpyxl

ORDINALS = {
    'اول', 'أول', 'ثان', 'ثانى', 'ثاني', 'ثالث', 'رابع', 'خامس', 'سادس', 'سابع', 'ثامن', 'تاسع', 'عاشر',
    'حادى', 'حادي', 'عشر', 'شرق', 'غرب', 'بندر',
}
EXCLUDE_PREFIXES = ('خارج الزمام', 'صحراء', 'إدارة شرطة', 'إداره شرطه', 'اداره شرطه')

# Spacing fixes decided by hand (2026-11-01), on top of the automatic ones.
MANUAL_SPACING = {'EG0128': 'قسم مصر الجديدة'}

# Draft from the owner (2026-11-01, pending "مؤكد"): existing city -> area
# ('area', P-code) or district under an area ('district', parent P-code).
# None = the named qism is not in the 2017 source, so nothing is guessed.
NEIGHBORHOOD_DRAFT = {
    'وسط القاهرة': ('district', 'EG0111', 'قصر النيل'),
    'مصر الجديدة': ('area', 'EG0128', 'قسم مصر الجديدة بعد تصليح المسافة'),
    'العباسية': ('district', 'EG0122', 'الوايلي'),
    'المهندسين': ('district', 'EG2102', 'العجوزة'),
    'الهرم': ('area', 'EG2106', 'قسم الأهرام، والاسم المعروض «الهرم» (قرار 2026-11-01)'),
    'فيصل': ('district', 'EG2118', 'العمرانية مؤقتاً، ويتنقل للطالبية لما تظهر في مصدر رسمي أحدث'),
    'سموحة': ('district', 'EG0203', 'سيدى جابر'),
    'العجمي': ('district', 'EG0212', 'الدخيلة (مفيش «قسم العجمي» في المصدر)'),
    'مصطفى كامل': ('district', 'EG0203', 'سيدى جابر'),
    'ميامي': ('district', 'EG0201', 'المنتزة'),
    'التجمع الخامس': ('area', None, 'منطقة مستقلة في القاهرة (مش في مصدر 2017)'),
    'مدينتي': ('area', None, 'منطقة مستقلة في القاهرة (مش في مصدر 2017)'),
    'الرحاب': ('area', None, 'منطقة مستقلة في القاهرة (مش في مصدر 2017)'),
    'شبرا الخيمة': ('area', None, 'تتنقل للقليوبية، وأقسامها EG1406 وEG1407 أحياء تحتها'),
    'حدائق الأهرام': ('area', None, 'تتنقل للجيزة (مش في مصدر 2017)'),
}

# Cities after the 2017 source, from the New Urban Communities Authority
# (checked 2026-11-01): (name from the page title, page slug, governorate,
# whether the page itself names the governorate).
NUCA_INDEX = 'http://www.newcities.gov.eg/know_cities/default.aspx'
NUCA_PAGE = 'http://www.newcities.gov.eg/know_cities/{}/default.aspx'
NUCA_CITIES = [
    ('العاصمة الإدارية الجديدة', 'NewCapital', 'القاهرة', False),
    ('العلمين الجديدة', 'alameen_new', 'مطروح', False),
    ('المنصورة الجديدة', 'NewMansoura', 'الدقهلية', True),
    ('شرق بور سعيد', 'CityMillions', 'بورسعيد', False),
    ('غرب أسيوط', 'West_Assiut_City', 'أسيوط', False),
    ('غرب قنا', 'West_Qena_City', 'قنا', False),
    ('الأقصر الجديدة', 'newLuxor', 'الأقصر', False),
    ('الإسكندرية الجديدة', 'NewAlex', 'الإسكندرية', False),
    ('رشيد الجديدة', 'NewRashid', 'البحيرة', False),
    ('الفشن الجديدة', 'NewFashn', 'بني سويف', False),
    ('ملوي الجديدة', 'NewMallawi', 'المنيا', False),
    ('6 أكتوبر الجديدة', 'NewOctober', 'الجيزة', False),
    ('العبور الجديدة', 'NewObour', 'القليوبية', False),
    ('امتداد الشيخ زايد', 'Ext_Zayed', 'الجيزة', False),
    ('حدائق أكتوبر', 'October_Gardens', 'الجيزة', False),
    ('سفنكس الجديدة', 'New_Sphinx', 'الجيزة', False),
    ('حدائق العاصمة', 'Capital_Gardens', 'القاهرة', False),
    ('توشكى الجديدة', 'Toshka', 'أسوان', False),
    ('شرق العوينات', 'EastOwaynat', 'الوادي الجديد', False),
]
# Mentioned before but not on the NUCA site: listed, never added.
UNVERIFIED_CITIES = ['الجلالة', 'ناصر', 'الإسماعيلية الجديدة', 'بئر العبد الجديدة', 'رفح الجديدة',
                     'النوبارية الجديدة']

# Display names decided by hand; the official name stays in name_official.
DISPLAY_NAMES = {'EG2106': 'الهرم'}

# Search aliases: a neighborhood name finds every area it spans.
SEARCH_ALIASES = {
    'فيصل': ['EG2118', 'EG2105'],  # العمرانية، بولاق الدكرور (+ الطالبية لما تتضاف)
    'الأهرام': ['EG2106'],  # الاسم الرسمي للهرم
    'وسط البلد': ['EG0111', 'EG0109', 'EG0113'],  # قصر النيل، عابدين، الأزبكية
}


def norm(text):
    """Same idea as public.normalize_arabic + place_name_key in the database."""
    t = unicodedata.normalize('NFKC', text or '').strip()
    t = re.sub(r'[ً-ْـ]', '', t)          # diacritics, tatweel
    t = t.translate(str.maketrans('أإآٱةى', 'ااااهي'))
    t = re.sub(r'\s+', ' ', t)
    return t


def strip_prefix(ar, prefix):
    return ar[len(prefix):].strip() if ar.startswith(prefix) else ar


def qism_bases(ar):
    """Candidate parent names for a qism: with and without 'مدينة'."""
    words = [w for w in strip_prefix(ar, 'قسم').split() if w]
    words = [w for w in words if norm(w) not in {norm(o) for o in ORDINALS}]
    with_city = ' '.join(words)
    without_city = ' '.join(w for w in words if norm(w) not in {'مدينه'})
    return [b for b in dict.fromkeys([with_city, without_city]) if b]


def split_glued(name, vocab):
    """The source sometimes drops spaces ("ثانمدينةنصر"). A word that is not
    itself in the vocabulary is split where both halves are known words; the
    vocabulary is every standalone word of the same dataset."""
    out = []
    for w in name.split():
        if norm(w) in vocab or len(w) < 6:
            out.append(w)
            continue
        parts = [w]
        for i in range(2, len(w) - 1):
            a, b = w[:i], w[i:]
            if norm(a) in vocab and (norm(b) in vocab or split_glued(b, vocab) != b):
                parts = [a, split_glued(b, vocab)]
                break
        out.append(' '.join(parts))
    return ' '.join(out)


def load_sheet(wb, name):
    rows = wb[name].iter_rows(values_only=True)
    header = next(rows)
    return [dict(zip(header, r)) for r in rows]


def main(xlsx, cities_psv, out_md, out_json):
    wb = openpyxl.load_workbook(xlsx, read_only=True)
    adm1 = load_sheet(wb, 'egy_admin1')
    adm2 = load_sheet(wb, 'egy_admin2')
    adm3 = load_sheet(wb, 'egy_admin3')

    from collections import Counter as _C
    # Words of the level-3 names (villages, shiakhas): a glued level-2 name is
    # not in there, so it cannot vouch for itself.
    words = _C(norm(w) for r in adm3 for w in (r.get('adm3_name1') or '').split())
    vocab = set(words) | {norm(o) for o in ORDINALS} | {'مدينه', 'قسم', 'مركز'}
    fixes = {}
    for r in adm2:
        raw = (r['adm2_name1'] or '').strip()
        fixed = split_glued(raw, vocab)
        if fixed != raw:
            fixes[r['adm2_pcode']] = (raw, fixed)
            r['adm2_name1'] = fixed
        if r['adm2_pcode'] in MANUAL_SPACING:
            fixes[r['adm2_pcode']] = (raw, MANUAL_SPACING[r['adm2_pcode']])
            r['adm2_name1'] = MANUAL_SPACING[r['adm2_pcode']]

    existing = []
    for line in open(cities_psv, encoding='utf-8'):
        cid, gid, gname, cname = line.rstrip('\n').split('|')
        existing.append({'id': int(cid), 'gov': gname, 'name': cname})

    gov_alias = {norm('مدينة الأقصر'): norm('الأقصر')}
    gov_of = {r['adm1_pcode']: r['adm1_name1'].strip() for r in adm1}

    rows = []
    markaz = {}  # (gov pcode, norm name) -> pcode
    for r in adm2:
        ar = (r['adm2_name1'] or '').strip()
        if ar.startswith('مركز'):
            markaz[(r['adm1_pcode'], norm(strip_prefix(ar, 'مركز')))] = r['adm2_pcode']

    # Decision 2026-11-01: these governorates, and any made of qisms only.
    urban = {'EG01', 'EG02', 'EG03', 'EG04', 'EG21'} | (
        {r['adm1_pcode'] for r in adm1} - {g for g, _ in markaz})

    for r in sorted(adm2, key=lambda x: x['adm2_pcode']):
        ar = (r['adm2_name1'] or '').strip()
        gov = r['adm1_pcode']
        item = {
            'pcode': r['adm2_pcode'], 'gov_pcode': gov, 'gov_ar': gov_of[gov], 'name_ar_source': ar,
            'name_en_source': r['adm2_name'], 'lat': r['center_lat'], 'lng': r['center_lon'],
            'type': None, 'name_ar': None, 'parent': None, 'parent_pcode': None, 'rule': None, 'review': False,
        }
        if ar.startswith('مركز'):
            item.update(type='city', name_ar=strip_prefix(ar, 'مركز'), rule='مركز ← مدينة')
        elif ar.startswith(('مدينة', 'مدينه')):
            item.update(type='city', name_ar=re.sub(r'^مدين[ةه]\s+', '', ar), rule='مدينة جديدة ← مدينة')
        elif ar.startswith(EXCLUDE_PREFIXES):
            item.update(type='exclude', rule='منطقة غير سكنية/إدارية: استبعاد مقترح', review=True)
        elif gov in urban:
            # Decision 2026-11-01: in urban governorates each qism is an area at
            # the city level; numbered qisms (أول/ثان…) merge into one area below.
            bases = qism_bases(ar) if ar.startswith('قسم') else [ar]
            item.update(type='city', name_ar=bases[0], rule='قسم ← منطقة (محافظة حضرية)')
            if not ar.startswith('قسم'):
                item['review'] = True
        else:
            bases = qism_bases(ar) if ar.startswith('قسم') else [ar]
            parent = None
            for b in bases:
                if (gov, norm(b)) in markaz:
                    parent = (b, markaz[(gov, norm(b))], 'قسم ← حي داخل مدينة المركز')
                    break
            if parent is None:
                for b in bases:
                    hit = [e for e in existing if norm(e['name']) == norm(b) and norm(e['gov']) == norm(gov_of[gov])]
                    if hit:
                        parent = (hit[0]['name'], None, 'قسم ← حي داخل مدينة موجودة')
                        break
            if parent is None:
                name = bases[-1]
                parent = (name, None, 'قسم ← حي، والمدينة الأم جديدة (محافظة حضرية أو مدينة جديدة)')
                item['review'] = True
            if not ar.startswith('قسم'):
                item['review'] = True
            item.update(type='district', name_ar=ar if not ar.startswith('قسم') else strip_prefix(ar, 'قسم'),
                        parent=parent[0], parent_pcode=parent[1], rule=parent[2])
        if r['adm2_pcode'] in fixes:
            item['review'] = True
            item['rule'] += f" — تصحيح مسافات: «{fixes[r['adm2_pcode']][0]}» ← «{fixes[r['adm2_pcode']][1]}»"
        item['name_official'] = r['adm2_name1']
        if r['adm2_pcode'] in DISPLAY_NAMES:
            item['name_ar'] = DISPLAY_NAMES[r['adm2_pcode']]  # kept for search; display name drops قسم/مركز
        rows.append(item)

    # One area per (governorate, name): numbered qisms, and a qism and a markaz
    # with the same name in an urban governorate, share it with all P-codes.
    groups = {}
    for item in rows:
        if item['type'] == 'city':
            groups.setdefault((item['gov_pcode'], norm(item['name_ar'])), []).append(item)
    for members in groups.values():
        codes = [m['pcode'] for m in members]
        for m in members:
            m['pcodes'] = codes
            if len(members) > 1:
                m['rule'] += ' — مدموجة: ' + '، '.join(codes)

    # Existing cities: linked to a P-code (markaz) or to a proposed parent city.
    links = []
    for e in existing:
        gov_rows = [r for r in rows if norm(r['gov_ar']) in (norm(e['gov']), gov_alias.get(norm(e['gov']), ''))]
        city_hit = [r for r in gov_rows if r['type'] == 'city' and norm(r['name_ar']) == norm(e['name'])]
        parent_hit = [r for r in gov_rows if r['type'] == 'district' and norm(r['parent'] or '') == norm(e['name'])]
        other_gov = [r for r in rows if r['type'] in ('city', 'district')
                     and norm(r['name_ar'] if r['type'] == 'city' else (r['parent'] or '')) == norm(e['name'])
                     and r not in gov_rows]
        draft = NEIGHBORHOOD_DRAFT.get(e['name'])
        if draft:
            kind, pc, note = draft
            label = 'منطقة مستقلة' if kind == 'area' else 'حي تحت'
            links.append((e, pc, f"مسودة: {label} — {note}"))
        elif city_hit:
            links.append((e, '، '.join(city_hit[0]['pcodes']), 'نفس اسم المنطقة'))
        elif parent_hit:
            links.append((e, None, 'مدينة أم لأقسام: ' + '، '.join(r['pcode'] for r in parent_hit)))
        elif other_gov:
            links.append((e, None, f"⚠️ الاسم موجود في محافظة تانية: {other_gov[0]['gov_ar']} ({other_gov[0]['pcode']})"))
        else:
            links.append((e, None, '⚠️ مالقيتش مطابقة: محتاج تحديد يدوي'))

    json.dump({'adm2': rows, 'existing_links': [
        {'city_id': e['id'], 'name': e['name'], 'pcode': pc, 'note': note} for e, pc, note in links
    ], 'search_aliases': SEARCH_ALIASES},open(out_json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=str)

    # ── Markdown for review ──────────────────────────────────────────
    from collections import Counter
    c = Counter(r['type'] for r in rows)
    out = []
    out.append('# جدول تصنيف التقسيم الإداري (للمراجعة قبل الـ migration)\n')
    out.append('> المصدر: [Egypt - Subnational Administrative Boundaries (COD-AB)](https://data.humdata.org/dataset/cod-ab-egy)، '
               'من CAPMAS عن طريق HDX، رخصة **CC BY-IGO**، إصدار v01، صالح من 2017-04-21. الملف: '
               '`data/sources/egy_admin_boundaries.xlsx` (sha256 `9d8ed34df98f328048b0c2e8be28f2fcab27484f00b3f6fd55aa8851850a0250`). '
               'الجدول اتولّد بـ `scripts/data/build_admin_mapping.py`، ومفيش حاجة اتكتبت في قاعدة البيانات.\n')
    out.append('> **الأسماء العربية:** الملف مافيهوش أعمدة اسمها `_AR`، بس فيه `adm1_name1` و`adm2_name1` و`lang1 = ar`. ودي اللي اتاخدت.\n')
    out.append('## الملخص\n')
    out.append(f"- المستوى 1: **{len(adm1)} محافظة**، وكلها مطابقة للـ 27 الموجودين، بفروق إملائية بس (جدول تحت).\n"
               f"- المستوى 2: **{len(rows)} صف**: {c['city']} مدينة (مراكز ومدن جديدة)، و{c['district']} حي (أقسام)، و{c['exclude']} استبعاد مقترح.\n"
               f"- الصفوف اللي محتاجة نظرتك متعلّمة بـ 🔎 ({sum(r['review'] for r in rows)} صف).\n")
    out.append('\n## قواعد التصنيف (حسب قرارات 2026-11-01)\n')
    out.append('| القاعدة | النتيجة |\n|---|---|\n'
               '| `مركز X` | منطقة في مستوى المدن اسمها X (المركز كله، المدينة والقرى اللي حواليها) |\n'
               '| `مدينة X الجديدة` | منطقة في مستوى المدن |\n'
               '| المحافظات الحضرية (القاهرة، الجيزة، الإسكندرية، بورسعيد، السويس، وأي محافظة كلها أقسام): `قسم … X` | منطقة في مستوى المدن اسمها X. الأقسام المرقّمة (أول/ثان/ثالث) بتتدمج في منطقة واحدة، والـ P-codes كلها بتتخزن عليها |\n'
               '| باقي المحافظات: `قسم … X` | حي تحت منطقة المركز X (أو المنطقة اللي بنفس الاسم) |\n'
               '| `خارج الزمام`، `صحراء …`، `إدارة شرطة ميناء …` | استبعاد (اتوافق عليه) |\n'
               '| أسماء من غير بادئة (`منشأةناصر`، `مصرالقديمة`، `الساحل الشمالى`) | 🔎 اتعاملت معاملة القسم |\n')
    out.append('\n**الأسماء والتخزين:** الاسم المعروض من غير "قسم" و"مركز" (دسوق مش مركز دسوق). الاسم الرسمي بيتخزن في عمود منفصل، والبحث بيلاقي الاتنين. كل منطقة بتخزن كل الـ P-codes بتاعتها، وكل حي بيخزن الـ P-code بتاعه.\n')

    out.append('\n## المدن الـ 29 الحالية ← الـ P-code\n')
    out.append('| id | المدينة | P-code | الملاحظة |\n|---|---|---|---|\n')
    for e, pc, note in links:
        out.append(f"| {e['id']} | {e['name']} ({e['gov']}) | {pc or '—'} | {note} |\n")

    # ── Open issues ─────────────────────────────────────────────────
    # Signs of a dropped space: "ال" inside a word, or "ة" not at a word's end.
    glued_left = [r for r in rows if re.search(r'\S{2}ال\S{2}|ة\S', r['name_ar_source']) and r['type'] != 'exclude'
                  and 'تصحيح مسافات' not in (r['rule'] or '')]
    by_pc = {r['pcode']: r for r in rows}
    out.append('\n## أسماء البحث البديلة (مسودة)\n')
    out.append('اسم الحي بيلاقي المنطقة (أو المناطق) اللي هو فيها. الأحياء اللي في المسودة فوق بتلاقي منطقتها تلقائي، والجدول ده للأحياء الممتدة على أكتر من قسم.\n\n')
    out.append('| الاسم | بيلاقي |\n|---|---|\n')
    for alias, codes in SEARCH_ALIASES.items():
        out.append(f"| {alias} | {'، '.join(by_pc[c]['name_ar'] + ' (' + c + ')' for c in codes)} |\n")

    review = [r for r in rows if r['review'] and r['type'] != 'exclude']
    out.append(f'\n## الصفوف اللي محتاجة مراجعتك ({len(review)})\n')
    out.append('الـ 18 استبعاد اتوافق عليهم. دول الباقيين: الاسم من المصدر ← الاقتراح.\n\n')
    for r in review:
        sug = r['name_ar'] if r['type'] == 'city' else f"{r['name_ar']} (حي تحت «{r['parent']}»)"
        why = 'تصحيح مسافة' if 'تصحيح مسافات' in r['rule'] else (
            'من غير بادئة' if r['type'] == 'city' else 'مفيش مركز بالاسم ده، فالمنطقة الأم جديدة')
        out.append(f"- {r['pcode']} {r['gov_ar']}: {r['name_ar_source']} ← {sug} — {why}\n")
    out.append('\n**أسماء ممكن تكون لازقة ومااتصلحتش** (الفحص آلي، وفيها أسماء سليمة زي الجمالية):\n')
    for r in glued_left:
        out.append(f"- {r['pcode']}: {r['name_ar_source']}\n")

    # ── Post-2017 cities: listed for verification, never added ────────
    all_names = [norm(r['adm2_name1'] or '') for r in adm2] + [norm(r.get('adm3_name1') or '') for r in adm3]
    out.append('\n## مدن جديدة مش في مصدر 2017\n')
    out.append(f'**من موقع هيئة المجتمعات العمرانية الجديدة** ([قائمة المدن]({NUCA_INDEX})، اتراجعت 2026-11-01). '
               'الاسم من عنوان صفحة المدينة. أغلب الصفحات مش مكتوب فيها المحافظة، فعمود المحافظة اقتراح محتاج تأكيدك، '
               'إلا لو مكتوب «من الصفحة».\n\n')
    out.append('| المدينة | المصدر | المحافظة | في COD-AB؟ |\n|---|---|---|---|\n')
    for cname, slug, gov, from_page in NUCA_CITIES:
        hit = any(norm(cname) in n for n in all_names)
        gov_note = f'{gov} (من الصفحة)' if from_page else f'🔎 {gov} (اقتراح)'
        out.append(f"| {cname} | [NUCA]({NUCA_PAGE.format(slug)}) | {gov_note} | {'ظهر جزء من الاسم' if hit else 'لأ'} |\n")
    out.append('\n**تحت التحقق** (مش لاقيها في موقع الهيئة، ومش هتتضاف):\n')
    for cname in UNVERIFIED_CITIES:
        out.append(f'- {cname}\n')

    out.append('\n## المحافظات (المستوى 1)\n| P-code | الاسم في المصدر |\n|---|---|\n')
    for r in sorted(adm1, key=lambda x: x['adm1_pcode']):
        out.append(f"| {r['adm1_pcode']} | {r['adm1_name1']} |\n")

    out.append('\n## المستوى 2 بالتفصيل\n')
    for gov in sorted({r['gov_pcode'] for r in rows}):
        g_rows = [r for r in rows if r['gov_pcode'] == gov]
        out.append(f"\n### {gov_of[gov]} ({gov}) — {len(g_rows)} صف\n")
        out.append('| | P-code | الاسم في المصدر | النوع | الاسم المقترح | المدينة الأم | القاعدة |\n|---|---|---|---|---|---|---|\n')
        type_ar = {'city': 'مدينة', 'district': 'حي', 'exclude': 'استبعاد'}
        for r in g_rows:
            parent = r['parent'] or '—'
            if r['parent_pcode']:
                parent += ' (' + r['parent_pcode'] + ')'
            flag = '🔎' if r['review'] else ''
            name = r['name_ar'] or '—'
            out.append(f"| {flag} | {r['pcode']} | {r['name_ar_source']} | {type_ar[r['type']]} | {name} | {parent} | {r['rule']} |\n")
    open(out_md, 'w', encoding='utf-8', newline='\n').write(''.join(out))
    print(dict(c), 'review:', sum(r['review'] for r in rows), 'space fixes:', len(fixes))


if __name__ == '__main__':
    main(*sys.argv[1:5])
