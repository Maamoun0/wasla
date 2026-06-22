-- ========================================================================================
-- WASLA CLASSIFIEDS PLATFORM - SPRINT 2 DISTRICTS SEED DATA
-- ========================================================================================

-- Clear existing districts to allow safe clean runs
DELETE FROM public.districts;

-- Insert districts for Cairo, Giza, and Alexandria cities
INSERT INTO public.districts (city_id, name_ar, name_en) VALUES
  (2, 'المنطقة الأولى', 'First Zone'),
  (2, 'المنطقة السادسة', 'Sixth Zone'),
  (2, 'المنطقة الثامنة', 'Eighth Zone'),
  (2, 'زهراء مدينة نصر', 'Zahraa Nasr City'),
  (2, 'الحي السابع', '7th District'),
  (2, 'الحي العاشر', '10th District'),

  (3, 'المعادي القديمة', 'Old Maadi'),
  (3, 'ثكنات المعادي', 'Thakanat Maadi'),
  (3, 'زهراء المعادي', 'Zahraa Maadi'),
  (3, 'حدائق المعادي', 'Hadayek Maadi'),
  (3, 'دجلة المعادي', 'Degla Maadi'),

  (4, 'الكوربة', 'Korba'),
  (4, 'ميدان تريومف', 'Triumph Square'),
  (4, 'روكسي', 'Roxy'),
  (4, 'شيراتون', 'Sheraton'),
  (4, 'جسر السويس', 'Gesr El Suez'),

  (9, 'النرجس', 'Al Narges'),
  (9, 'الياسمين', 'Al Yasmeen'),
  (9, 'البنفسج', 'Al Bafanseg'),
  (9, 'اللؤلؤة', 'Al Loloa'),
  (9, 'المستثمرين', 'Investors'),
  (9, 'بيت الوطن', 'Beit El Watan'),

  (16, 'البحوث', 'El Bohooth'),
  (16, 'ميدان المساحة', 'Mesaha Square'),
  (16, 'بين السرايات', 'Been El Sarayat'),
  (16, 'ميدان الدقي', 'Dokki Square'),

  (17, 'ميدان لبنان', 'Lebanon Square'),
  (17, 'جامعة الدول العربية', 'Jamiat Al Dowal'),
  (17, 'ميت عقبة', 'Mit Okba'),
  (17, 'جزيرة العرب', 'Geziret Al Arab'),

  (18, 'سهل حمزة', 'Sahl Hamza'),
  (18, 'العريش', 'El Arish'),
  (18, 'المريوطية', 'Maryoutia'),
  (18, 'اللبيني', 'El Labini'),

  (19, 'الحي المتميز', 'Motamayez District'),
  (19, 'الحي الأول', 'First District'),
  (19, 'الحي الثاني', 'Second District'),
  (19, 'حدائق أكتوبر', 'Hadayek October'),
  (19, 'جنوب الأحياء', 'South Districts'),

  (20, 'الحي الأول', 'First District'),
  (20, 'الحي الثاني', 'Second District'),
  (20, 'الحي الحادي عشر', 'Eleventh District'),
  (20, 'الثورة الخضراء', 'Green Revolution'),

  (23, 'المندرة', 'Mandara'),
  (23, 'العصافرة', 'Asafra'),
  (23, 'أبو قير', 'Abu Qir'),
  (23, 'المعمورة', 'Maamoura'),

  (24, 'كليوباترا', 'Cleopatra'),
  (24, 'مصطفى كامل', 'Mustafa Kamel'),
  (24, 'رياضة سبورتنج', 'Sporting'),

  (25, 'فيكتور عمانويل', 'Victor Emmanuel'),
  (25, 'عزبة سعد', 'Ezbet Saad'),
  (25, 'ميدان ألبرت الأول', 'Albert Square');

-- Verify insertions
SELECT COUNT(*) FROM public.districts;
