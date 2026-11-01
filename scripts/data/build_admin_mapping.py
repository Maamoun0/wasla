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
        item['name_official'] = r['adm2_name1']  # kept for search; display name drops قسم/مركز
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
        if city_hit:
            links.append((e, '، '.join(city_hit[0]['pcodes']), 'نفس اسم المنطقة'))
        elif parent_hit:
            links.append((e, None, 'مدينة أم لأقسام: ' + '، '.join(r['pcode'] for r in parent_hit)))
        elif other_gov:
            links.append((e, None, f"⚠️ الاسم موجود في محافظة تانية: {other_gov[0]['gov_ar']} ({other_gov[0]['pcode']})"))
        else:
            links.append((e, None, '⚠️ مالقيتش مطابقة: محتاج تحديد يدوي'))

    json.dump({'adm2': rows, 'existing_links': [
        {'city_id': e['id'], 'name': e['name'], 'pcode': pc, 'note': note} for e, pc, note in links
    ]}, open(out_json, 'w', encoding='utf-8'), ensure_ascii=False, indent=1, default=str)

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
    out.append('\n## محتاج قرارك\n')
    out.append('1. **المدن الحالية اللي مالقتلهاش مطابقة** (علامة ⚠️ في الجدول اللي فوق). أغلبها أحياء أصغر من القسم (العباسية، المهندسين، سموحة، ميامي…)، '
               'أو مدن جديدة (التجمع الخامس، مدينتي، الرحاب). مش هخمّن هي تبع أنهي قسم. محتاج تحدد لكل واحدة: تفضل مدينة، ولا تبقى حي تحت مدينة معينة.\n')
    out.append('2. **غلطات في البيانات الحالية:** "شبرا الخيمة" متسجلة في القاهرة، وهي في القليوبية (EG1406). و"حدائق الأهرام" متسجلة في القاهرة، وهي في الجيزة. '
               'و"فيصل" في الجيزة ليها نفس اسم قسم في السويس (EG0404)، يعني الاسم مش كفاية للربط.\n')
    out.append('3. **أسماء في المصدر ممكن تكون لازقة من غير مسافات** (الفحص آلي: "ال" في نص الكلمة، أو "ة" مش في آخرها). فيها أسماء سليمة كمان، زي الجمالية وسمالوط. التصحيح الآلي اتعمل بس لما الجزئين كانوا موجودين ككلمات في أسماء المستوى 3، والباقي محتاج نظرتك:\n')
    for r in glued_left:
        out.append(f"   - {r['pcode']}: {r['name_ar_source']}\n")
    out.append('4. **الاستبعادات المقترحة** (خارج الزمام، الصحراء، إدارات شرطة الموانئ): موافق؟\n')
    out.append('5. **المحافظات الحضرية** (القاهرة، والإسكندرية، وبورسعيد، والسويس…) مافيهاش مراكز، فكل اسم قسم بقى مدينة أم. '
               'ده بيطلّع "مدن" كتير في القاهرة (التبين، طره، عابدين…). البديل إن المحافظة كلها تبقى مدينة واحدة (مثلاً القاهرة)، والأقسام أحياء تحتها. أنهي الاتنين؟\n')

    # ── Post-2017 cities: listed for verification, never added ────────
    cands = ['العاصمة الإدارية الجديدة', 'العلمين الجديدة', 'المنصورة الجديدة', 'الجلالة', 'شرق بورسعيد', 'ناصر',
             'ملوي الجديدة', 'رشيد الجديدة', 'العبور الجديدة', 'أكتوبر الجديدة', 'حدائق أكتوبر', 'الإسماعيلية الجديدة',
             'بئر العبد الجديدة', 'رفح الجديدة', 'الفشن الجديدة', 'سفنكس الجديدة', 'النوبارية الجديدة']
    all_names = [norm(r['adm2_name1'] or '') for r in adm2] + [norm(r.get('adm3_name1') or '') for r in adm3]
    out.append('\n## مدن جديدة بعد 2017 (مش هتتضاف)\n')
    out.append('بيانات المصدر من 2017. الأسماء دي اتكتبت هنا عشان تتراجع بس، ومش هتتضاف لحد ما تيجي من مصدر رسمي. '
               'عمود "في المصدر" معناه إن الاسم ظهر كجزء من اسم في المستوى 2 أو 3، وده مش بيأكد إنه نفس المكان.\n\n')
    out.append('| المدينة | في المصدر؟ |\n|---|---|\n')
    for cname in cands:
        hit = any(norm(cname) in n for n in all_names)
        note = 'ظهر جزء من الاسم (غالباً مكان تاني، زي "منشأة ناصر")' if hit else 'لأ'
        out.append(f'| {cname} | {note} |\n')

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
