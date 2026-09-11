import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/services/answer_key_service.dart';

void main() {
  test('parse provided answer key sample', () {
    final service = AnswerKeyService();
    final sample = r'''
Internal Medicine Best-of-Five MCQ Set — Answer Key and 	Explanations 1

1.	A. False — Troponin is important diagnostically, but immediate revascularization is lifesaving in STEMI.
B. True — Immediate dual antiplatelet therapy (aspirin) and transfer for primary PCI is standard of care for acute STEMI; fastest reperfusion saves myocardium.
C. False — Oral nitrates can be adjunct, but waiting delays reperfusion and is unsafe.
D. False — Discharging a STEMI case is contraindicated—risk of death/morbidity.
E. False — Statins are essential for secondary prevention but are not the urgent first measure.

2.	A. False — Mitral regurgitation would not cause a loud S1 or a diastolic rumble with opening snap.
B. False — Aortic stenosis typically involves a systolic murmur radiating to the neck.
C. True — Classic for mitral stenosis: mid-diastolic murmur with opening snap, loud S1, history of rheumatic fever, hemoptysis.
D. False — Tricuspid regurgitation causes right-sided signs; murmur best at left lower sternal border.
E. False — Hypertrophic cardiomyopathy murmur is systolic, no opening snap.


3.	A. False — Prosthetic, not native, valve is infected in this patient.
B. False — No evidence for rheumatic disease or sequelae.
C. True — S. epidermidis is a classic prosthetic valve organism (biofilm risk), two years after surgery.
D. False — Viral myocarditis causes arrhythmias, not murmur/bacterial infection.
E. False — Libman–Sacks is sterile/autoimmune (SLE), not septic endocarditis.
4.	A. False — ARVC may cause sudden death, but murmur/ECG findings and family history point otherwise.
B. False — Long QT causes arrhythmia/syncope, not murmur/T-wave changes.
C. True — HCM: young athlete, exertional syncope, murmur louder with Valsalva, deep T inversion, sudden death risk.
D. False — Mitral valve prolapse can cause murmur/syncope, but not as described.
E. False — No evidence of pulmonary embolism.

5.	A. False — Hepatomegaly is more right-sided heart failure.
B. True — Orthopnea is typical for left-sided HF due to pulmonary congestion.
C. False — Ascites is a right-sided or late biventricular HF finding.
D. False — Ankle edema is more typically right HF or hypoalbuminemia.
E. False — Raised JVP may be both-sided, but orthopnea is more specific for left-sided HF.


6.	A. False — MI does not present with pulsus paradoxus and muffled heart sounds.
B. True — Classic Beck’s triad: raised JVP, hypotension, and muffled heart sounds from cardiac tamponade; trauma and pulsus paradoxus point to this.
C. False — Aortic regurgitation causes wide pulse pressure, not tamponade findings.
D. False — Pulmonary embolism causes acute right heart strain and hypoxia, not this combination.
E. False — Tension pneumothorax presents with tracheal deviation, absent breath sounds, and hypotension, not heart sounds.

7.	A. False — Male sex is a minor risk factor per CHA₂DS₂-VASc.
B. True — Hypertension is a significant and common risk factor for stroke in AF patients and is highly weighted on risk calculators.
C. False — Diabetes is a risk but less weighted than hypertension.
D. False — Young age actually confers lower risk.
E. False — Beta-blockers are for rate control, not for embolic risk modification.

8.	A. False — Adenosine can block AV node, may exacerbate pre-excited AF.
B. False — Amiodarone is dangerous but digoxin is even more so in WPW+AF.
C. True — Digoxin increases conduction through the accessory pathway and can precipitate ventricular fibrillation in WPW+AF.
D. False — Propafenone is proarrhythmic but not most dangerous in this setting.
E. False — Ibutilide is used for chemical cardioversion in some atrial dysrhythmias.

9.	A. False — Oral penicillin is ineffective for enterococcal prosthetic valve endocarditis.
B. False — Ceftriaxone is inadequate coverage.
C. False — Vancomycin alone is not best initial; dual therapy preferred.
D. True — Ampicillin plus gentamicin is the gold standard for enterococcal prosthetic valve endocarditis.
E. False — Metronidazole does not cover enterococcus.

10.	A. False — Viral infection is a less likely cause in a dialysis patient with pericarditis.
B. True — Uremic pericarditis is classic in missed dialysis/advanced CKD.
C. False — MI presents with regional, not diffuse, ST elevations/ECG findings.
D. False — Alcoholic cardiomyopathy is less relevant here.
E. False — Rheumatic disease would affect a younger demographic and is less likely.

11.	A. False — Unstable angina does not present with transient ST elevations and normal cardiac arteries.
B. False — STEMI shows persistent, not transient, ST elevation.
C. True — Prinzmetal (variant) angina: episodic pain, transient ST elevation, normal coronaries.
D. False — Pericarditis: positional pain, widespread rather than episodic transient changes.
E. False — Takotsubo presents acutely after emotional/physical stress, not recurrent atypical pains.

12.	A. False — Murmur and pulse findings do not correlate with mitral valve pathology.
B. False — Tricuspid pathology does not cause wide pulse pressure or a diastolic murmur.
C. False — Pulmonary valve disease rarely gives these signs.
D. True — Aortic regurgitation is defined by water-hammer (collapsing) pulse, wide pulse pressure, and early diastolic murmur.
E. False — "None" is not correct.

13.	A. False — High-flow O2 in COPD can worsen hypercapnia and should be avoided if possible.
B. True — Controlled O2 with bronchodilators is first-line for COPD exacerbation; maintain saturations 88–92%.
C. False — Intubation/ventilation is only for failure to respond or very severe cases.
D. False — Oral corticosteroids are important but not solo first-line.
E. False — Dropping steroids would worsen exacerbation.

14.	A. False — Chest X-ray cannot confirm asthma diagnosis.
B. False — Sputum eosinophilia is supportive, not diagnostic.
C. True — Reversible airflow obstruction on spirometry is diagnostic for asthma.
D. False — Allergy testing is supportive but not confirmatory.
E. False — Methacholine challenge, though sensitive, is only used if the diagnosis is uncertain after spirometry.

15.	A. False — COPD exacerbation develops more gradually and shows obstructive airflow limitation.
B. False — Lung abscess is a subacute process, typically with fever and localized chest findings, not sudden dyspnea and pleuritic pain.
C. True — PE presents after immobilization, with acute pleuritic pain, breathlessness, hypoxia, and tachycardia.
D. False — Tension pneumothorax presents with hypotension, tracheal shift, absent breath sounds.
E. False — Pulmonary edema is more insidious and generally bilateral, with crackles/orthopnea.

16.	A. False — Tuberculosis has caseating, not non-caseating, granulomas, and does not typically cause hypercalcemia.
B. True — Sarcoidosis: young woman, bilateral hilar lymphadenopathy, non-caseating granulomas, hypercalcemia from increased vitamin D activation.
C. False — Lung carcinoma may cause lymphadenopathy but not the classical calcium/lab findings.
D. False — Bronchiectasis: chronic infection, not LDH/lymphadenopathy/fatigue.
E. False — Bacterial pneumonia is usually acute and does not present with hypercalcemia.

17.	A. False — Asthma exacerbation is episodic wheeze, not sudden silent hemithorax.
B. False — Pleural effusion causes dullness to percussion, not hyperresonance.
C. True — Tall thin man, sudden pleuritic chest pain, hyperresonance, absent breath sounds: classic for primary spontaneous pneumothorax.
D. False — Heart failure classically causes bilateral basal crackles, not sudden onset.
E. False — Bronchiectasis is productive, chronic, not sudden chest pain/dyspnea.

18.	A. False — No indication for hypoglycemia (glucose not low, confusion relates to CO₂).
B. True — Hypercapnic (type II) respiratory failure is common in advanced COPD—CO₂ narcosis, confusion, flapping tremor.
C. False — Hypoxemic (type I) may occur but CO₂ is key in this presentation.
D. False — No evidence for encephalitic or infectious etiology.
E. False — Metabolic alkalosis not typical of respiratory decompensation.

19.	A. False — Asthma does not persistently result in purulent sputum and clubbing.
B. False — Chronic bronchitis is chronic cough but not large purulent daily sputum in young non-smoker with clubbing.
C. True — Bronchiectasis: chronic large-volume sputum, recurrent infections, digital clubbing.
D. False — Empyema would be more acute, often post-pneumonia, frank pus in pleural space.
E. False — Pneumoconioses: restrictive pattern, not productive cough/purulent sputum.

20.	A. True — This is classic for prerenal AKI: old, dehydrated, oliguric, elevated BUN/Cr.
B. False — Obstructive (postrenal) is less likely than hypovolemia here.
C. False — No nephritic urine findings/proteinuria to suggest glomerulonephritis.
D. False — CKD is chronic, these findings are acute.
E. False — Renal artery stenosis may cause chronic, not acute, severe AKI.

21.	A. False — Acute nephritic syndrome usually causes hematuria, hypertension, and oliguria but is not primarily associated with proteinuria/edema/hyperlipidemia.
B. False — Diabetic nephropathy develops slowly and can cause proteinuria but not usually as sudden-onset and with such severe hypoalbuminemia.
C. True — Nephrotic syndrome is defined by heavy proteinuria (>3.5g/day), hypoalbuminemia, edema, hyperlipidemia; frothy urine and periorbital swelling are classic.
D. False — Renal amyloidosis is a rare cause of nephrotic syndrome; there is no signal for amyloid disease here.
E. False — Post-infectious GN is more hematuric/erythrocyturic rather than proteinuric.

22.	A. False — Beta-blockers do not specifically slow progression of diabetic nephropathy.
B. True — ACE inhibitors (or ARBs) are proven to slow progression of diabetic nephropathy by reducing intraglomerular pressure and proteinuria.
C. False — Calcium has no benefit in nephropathy progression.
D. False — Diuretics are symptomatic for edema, not renal protection.
E. False — Nitrates do not slow renal decline.

23.	A. False — Hyperthyroidism is characterized by weight loss, tachycardia, heat intolerance, not sleepiness, bradycardia, or puffiness.
B. True — Hypothyroidism causes fatigue, weight gain, bradycardia, periorbital swelling, high TSH.
C. False — Renal failure may cause fatigue and periorbital swelling but TSH is not high.
D. False — Addison’s has hyperpigmentation, hypotension, but not periorbital swelling or high TSH.
E. False — Depression can mimic hypothyroidism but does not cause the physical signs or TSH elevation.

24.	A. False — Iron deficiency is microcytic and has high reticulocyte count in response to anemia.
B. False — B12 deficiency results in macrocytic anemia, not normocytic.
C. True — Erythropoietin deficiency is responsible for anemia in CKD, with normocytic/normochromic anemia and low reticulocytes.
D. False — Folate deficiency causes macrocytic anemia.
E. False — CKD does not primarily cause hemolysis.

25.	A. True — Calcium gluconate IV stabilizes the myocardium rapidly in life-threatening hyperkalemia; it is the most urgent step.
B. False — Kayexalate acts very slowly and is not appropriate acutely.
C. False — Loop diuretic works only if urine output is intact; may not be effective or fast enough.
D. False — Insulin and glucose reduce serum potassium but are adjuncts after cardiac stabilization.
E. False — Dialysis is definitive treatment but requires stabilization while waiting.

26.	A. False — Renal cell carcinoma typically presents with hematuria, flank mass, and constitutional symptoms.
B. False — Medullary sponge kidney is associated with stones, not with hypertension or cerebral aneurysms.
C. True — Polycystic kidney disease: bilateral cysts, hypertension, hematuria, and family history of subarachnoid hemorrhage.
D. False — Alport’s syndrome features hematuria and hearing loss, not cysts/hypertension.
E. False — Interstitial nephritis presents as AKI, not cystic kidneys.

27.	A. False — Vitamin D deficiency is common in CKD but secondary hyperparathyroidism is the main driver of bone disease.
B. True — Secondary hyperparathyroidism caused by CKD leads to renal osteodystrophy (bone pain, fractures).
C. False — Bone metastases would present with other organ findings and labs.
D. False — Myeloma kidney is not the usual cause of bone pain/fracture in CKD.
E. False — Primary hyperparathyroidism causes stones/bones/groans but not as a CKD consequence.

28.	A. False — Diabetes insipidus causes polyuria and polydipsia but glucose is normal.
B. True — Diabetes mellitus presents with polyuria, polydipsia, weight loss, and hyperglycemia.
C. False — Cushing's syndrome includes weight gain, central obesity, and glucose intolerance—but rarely such dramatic polyuria/polydipsia.
D. False — Thyrotoxicosis causes weight loss but not polyuria/polydipsia.
E. False — Addison's presents with hypotension, hyperpigmentation.

29.	A. False — Hypopituitarism causes secondary adrenal insufficiency with low ACTH, less pigment change, less hyperkalemia.
B. True — Addison’s disease: muscle weakness, weight loss, hyperpigmentation, low sodium, high potassium.
C. False — Conn's syndrome is hyperaldosteronism; causes hypertension, hypokalemia.
D. False — SIADH causes hyponatremia but not hyperpigmentation or hyperkalemia.
E. False — Cushing's syndrome: hypertension, central obesity, no pigment change.

30.	A. False — Metastatic bone disease would cause bone pain but not hypercalcemia and elevated parathyroid hormone.
B. False — Multiple myeloma presents with bone pain but is not associated with primary hyperparathyroidism.
C. True — Primary hyperparathyroidism: high calcium, kidney stones, bone pain, abdominal symptoms, psychiatric findings (“bones, stones, groans, thrones, psychiatric overtones”).
D. False — Osteomalacia causes bone pain but low calcium and vitamin D.
E. False — Vitamin D intoxication elevates calcium but not PTH.

31.	A. True — Acute pancreatitis: epigastric pain radiates to back, often after alcohol binge or gallstones.
B. False — Cholecystitis would be RUQ pain with guarding, not radiating to back.
C. False — Peptic ulcer disease: burning, epigastric pain, meal-related.
D. False — Appendicitis: RLQ pain, fever.
E. False — GERD: burning chest pain, regurgitation.

32.	A. False — PSC often in males with IBD, not typically with antimitochondrial antibodies.
B. True — Primary biliary cholangitis: progressive jaundice, pruritus, pale stools, positive AMA.
C. False — Autoimmune hepatitis: anti-SMA, not AMA.
D. False — Alcoholic hepatitis: history of excessive alcohol, no AMA.
E. False — Wilson’s disease: copper abnormalities, Kayser-Fleischer rings.

33.	A. False — Crohn's disease has skip lesions and may affect any GI tract segment.
B. False — Infective colitis is usually transient, not chronic with weight loss.
C. True — Ulcerative colitis: continuous inflammation from rectum proximally, with bloody diarrhea and weight loss.
D. False — IBS has no inflammation or blood.
E. False — Colon cancer: older age, mass, not continuous inflammatory changes in young.

34.	A. False — Mallory-Weiss tear: vomiting then small-volume bleeding, rarely hypotension.
B. True — Peptic ulcer disease: NSAID history, melena, hypotension, big bleed risk.
C. False — Esophageal varices are seen in liver disease, alcoholics, portal hypertension, not NSAID use.
D. False — Colon polyps bleed rectally, not as upper GI hemorrhage.
E. False — Hemorrhoidal bleeding is lower GI, painless.

35.	A. False — Peptic ulcer: epigastric pain, not RUQ/postprandial.
B. False — Hepatitis B: systemic symptoms, jaundice.
C. True — Cholecystitis: RUQ pain after fatty meals, Murphy's sign, mild jaundice.
D. False — Pancreatitis: severe epigastric pain radiating to back.
E. False — Gastric cancer: would cause weight loss, gastric outlet obstruction.

________________________________________
36.	A. True — Hepatic encephalopathy: confusion, drowsiness, elevated ammonia, and asterixis; commonly occurs in cirrhosis.
B. False — Metabolic acidosis would cause tachypnea, not confusion and asterixis.
C. False — Alcohol withdrawal is associated with agitation, tremor, hallucinations.
D. False — Hypoglycemia: confusion, sweating, tachycardia.
E. False — Meningitis would cause fever, neck stiffness, photophobia, not high ammonia.

37.	A. False — Lactose intolerance causes bloating and diarrhea without anemia or steatorrhea.
B. False — Crohn’s disease is patchy, not anti-tTG positive, often affects the terminal ileum.
C. True — Celiac disease: diarrhea, steatorrhea, iron deficiency, anti-tTG positivity.
D. False — Whipple’s disease is very rare; presents with multi-system findings.

38.	A. False — Cirrhosis can cause weight loss, but a palpable hard liver mass is more suggestive of cancer.
B. True — Hepatocellular carcinoma: chronic hepatitis, weight loss, hard irregular mass, elevated tumor markers (CA 19-9).
C. False — Fatty liver is usually asymptomatic and presents as hepatomegaly, not mass.
D. False — Pancreatic carcinoma causes jaundice, weight loss, but not hard irregular liver mass.
E. False — Gallbladder carcinoma would be right upper quadrant, not palpable liver mass.

39.	A. False — Crohn’s disease is associated with PSC less than ulcerative colitis.
B. True — Ulcerative colitis is strongly associated with primary sclerosing cholangitis, jaundice, pruritus.
C. False — Celiac disease primarily affects the small intestine; association with liver disease is rare.
D. False — NASH is related to metabolic syndrome, not PSC.
E. False — Colon cancer is a late risk in UC, not directly linked to PSC.

40.	A. False — Acute pancreatitis is more likely with rapid-onset pain and elevated amylase, not cachexia or palpable gallbladder.
B. False — Chronic cholecystitis does not present with a palpable gallbladder.
C. True — Pancreatic cancer causes persistent pain, jaundice, palpable gallbladder (Courvoisier’s sign), and cachexia.
D. False — HCC would cause liver mass, not palpable gallbladder.
E. False — Choledocholithiasis causes jaundice, pain, but not cachexia or mass.

41.	A. False — Diabetes insipidus causes polyuria/polydipsia but normal glucose and no acidosis.
B. False — HHS presents with very high glucose, dehydration, but not ketones or acidosis.
C. True — Diabetic ketoacidosis: high glucose, acidosis (low pH), and ketones.
D. False — SIADH presents with euvolemic hyponatremia, not hyperglycemia/acidosis.
E. False — Insulinoma: hypoglycemia rather than hyperglycemia.

42.	A. False — Hypothyroidism is characterized by weight gain, cold intolerance, constipation, and bradycardia.
B. True — Thyrotoxicosis/Graves’ disease: hyperactivity, tremor, tachycardia, heat intolerance, exophthalmos.
C. False — Addison’s presents with pigmentation, hypotension.
D. False — Cushing's shows central obesity, striae.
E. False — Hyperparathyroidism involves hypercalcemia, not tremor/exophthalmos.

43.	A. False — Cushing’s syndrome would present with hypertension, central obesity, but not hyperpigmentation or electrolytes as described.
B. True — Addison’s: muscle weakness, weight loss, hyperpigmentation, low sodium, high potassium.
C. False — Conn's syndrome leads to hypertension and hypokalemia, not above.
D. False — Pheochromocytoma is episodic and presents with hypertension.
E. False — Hypopituitarism rarely includes pigmentation/hyperkalemia.

44.	A. False — Milk-alkali syndrome is rare and due to excess milk/alkali intake.
B. True — Primary hyperparathyroidism: elevated calcium, kidney stones, bone pain, abdominal pain, psychiatric findings.
C. False — Multiple myeloma: bone pain, hypercalcemia, anemia, proteinuria.
D. False — Secondary hyperparathyroidism: CKD, usually low or normal calcium.
E. False — Vitamin D toxicity: high calcium, low PTH.

45.	A. False — Vitamin C deficiency causes scurvy, not anemia.
B. False — B12 deficiency would present with macrocytic anemia.
C. True — Erythropoietin deficiency is the main cause of CKD anemia.
D. False — Folate deficiency is macrocytic.
E. False — Iron deficiency is more microcytic anemia.

46.	A. False — Sickle cell presents with dactylitis, crisis, with sickled cells.
B. False — Iron deficiency: microcytic, not severe anemia and facial deformity.
C. True — Thalassemia major: severe anemia, skeletal deformities, target cells.
D. False — Hereditary spherocytosis: spherocytes, not target cells.
E. False — AIHA would give spherocytes and rapid-onset anemia.

47.	A. False — TTP: pentad, schistocytes, fever, renal involvement, not isolated platelet drop.
B. False — HUS is childhood, with MAHA and renal failure.
C. True — ITP: isolated thrombocytopenia, mucosal bleeding, platelets <100,000.
D. False — DIC: low platelets, high D-dimer, bleeding, but not isolated drop.
E. False — AML presents with blasts, anemia, and infections.

48.	A. True — Hemophilia A: X-linked, FVIII deficiency, hemarthrosis, prolonged APTT, normal platelets.
B. False — Hemophilia B (FIX deficiency) presents similarly but is less common.
C. False — vWD: mucosal bleeding, prolonged bleeding time.
D. False — ITP: isolated thrombocytopenia.
E. False — DIC: consumption coagulopathy, not isolated hemarthroses.

49.	A. False — Prostate cancer causes bone pain, but not anemia or high calcium typically.
B. True — Multiple myeloma: bone pain, lytic lesions, anemia, hypercalcemia.
C. False — Osteoarthritis: pain but no lytic lesions/anemia/hypercalcemia.
D. False — Paget’s disease: bone pain, high ALP, not anemia/calcium.
E. False — Kidney cancer: hematuria, not bone pain.

50.	A. True — Stable angina: exertional chest pain, relieved by rest, ST depression on stress ECG.
B. False — Unstable angina: pain at rest, higher ACS risk.
C. False — STEMI: persistent pain at rest/EKG elevation.
D. False — Prinzmetal: variant angina, at rest, transient ST elevation.
E. False — Pericarditis: positional chest pain.

51.	A. False — Diabetes carries some risk but hypertension is the most important for stroke in elderly.
B. False — Rheumatic heart disease can cause stroke, but less frequently.
C. True — Hypertension is the single most important modifiable stroke risk factor in elderly patients.
D. False — Hyperthyroidism not associated with stroke.
E. False — Thrombocytopenia usually causes bleeding, not infarction.

52.	A. False — Alzheimer's disease: memory loss, not motor features.
B. False — Essential tremor: action not resting tremor.
C. True — Parkinson's: resting tremor, bradykinesia, rigidity, postural instability, festinating gait.
D. False — Huntington's: chorea, dementia, psychiatric, younger onset.
E. False — NPH: dementia, gait disturbance, incontinence.

53.	A. False — Guillain-Barre: ascending paralysis, not fluctuating weakness or ocular involvement.
B. True — Myasthenia gravis: fluctuating weakness, worse with use, ocular/bulbar involvement, positive edrophonium test.
C. False — MND: progressive weakness, no fatigue/ocular features.
D. False — MS: demyelinating, often sensory loss and relapses.
E. False — Lambert-Eaton: improves with use, associated with cancer.

54.	A. False — MS: demyelination, not acute paralysis/areflexia.
B. False — MG: ocular/bulbar fatigue, not areflexia.
C. True — Guillain-Barre: acute ascending paralysis, areflexia, post-infectious, “albuminocytologic dissociation.”
D. False — Botulism: descending weakness, cranial involvement.
E. False — ALS: UMN/LMN signs, progresses slowly.

55.	A. False — Fainting: rapid recovery, no postictal confusion/tongue biting.
B. True — Epilepsy: repeated seizures, tonic-clonic, postictal confusion, tongue biting.
C. False — Narcolepsy: sudden sleep, not convulsions.
D. False — Hypoglycemia: may seizure but usually with adrenergic prodrome.
E. False — TIA: sudden focal deficit that resolves, not generalized convulsions.

56.	A. True — SLE: malar rash, photosensitivity, ANA, nephritis, arthritis.
B. False — Scleroderma: skin thickening, Raynaud, less nephritis.
C. False — RA: symmetric polyarthritis, but no malar rash.
D. False — Psoriatic arthritis: psoriasis, not malar rash.
E. False — Dermatomyositis: muscle weakness, skin rash, but not malar.
57.	A. False — OA: short morning stiffness, larger joints.
B. False — Gout: monoarticular, sudden, not chronic symmetric.
C. False — Psoriatic arthritis: psoriasis, less symmetry.
D. True — RA: >1 hr stiffness, symmetrical small joint, seropositivity often.
E. False — SLE: can have arthritis, but more malar/systemic.

58.	A. False — OA: non-inflammatory, chronic, seldom sudden intense pain.
B. True — Gout: sudden monoarthritis, 1st MTP, urate crystals, classic in middle-aged men.
C. False — Pseudogout: rhomboid, calcium pyrophosphate crystals, knees.
D. False — RA: symmetrical, chronic, more MCPs/PIPs.
E. False — Septic arthritis: acute, but high fever/systemic.

59.	A. False — Infective endocarditis: vegetations, murmur, not thrush/low CD4.
B. False — Crohn’s: GI symptoms, not low CD4/chronic thrush.
C. True — HIV/AIDS: chronic thrush, fever, weight loss, low CD4.
D. False — Syphilis: may cause fever/ulcer, not low CD4/opportunistic.
E. False — CGD: childhood infections, not thrush/AIDS.

60.	A. False — Eczema: less sharply demarcated, more flexural.
B. False — Lichen planus: purple, polygonal, planar papules.
C. True — Psoriasis: silvery scale, elbows/knees, nail pitting/family hx.
D. False — Pityriasis rosea: herald patch, Christmas tree rash.
E. False — Seborrheic dermatitis: scalp/face mostly.


''';

    final result = service.extractAnswerKeys(sample);
    print('Parsed ${result.length} answer keys');
    for (final k in result.keys.toList()..sort()) {
      final answers = result[k]!['answers'] as List<bool>;
      final exps = result[k]!['explanations'] as List<String>;
      print('Question $k: answers=${answers.map((b) => b ? 'T' : 'F').join()}');
      for (int i = 0; i < answers.length; i++) {
        if (exps[i].isNotEmpty)
          print('  ${String.fromCharCode(65 + i)}: ${exps[i]}');
      }
    }
  });
}
