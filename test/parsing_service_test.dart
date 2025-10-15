import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/services/parsing_service.dart';

void main() {
  group('ParsingService', () {
    final parsingService = ParsingService();

    test('_extractQuestions parses questions correctly', () {
      const text = '''
1. What is the capital of France?
A. London
B. Paris
C. Berlin
D. Madrid

2. What is 2 + 2?
A. 3
B. 4
C. 5
D. 6
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 2);

      expect(questions[0].questionText, 'What is the capital of France?');
      expect(questions[0].options, ['London', 'Paris', 'Berlin', 'Madrid']);
  // Default behavior: first option is considered correct
  expect(questions[0].correctAnswers[0], true);

  expect(questions[1].questionText, 'What is 2 + 2?');
  expect(questions[1].options, ['3', '4', '5', '6']);
  expect(questions[1].correctAnswers[0], true);
    });

    test('_extractQuestions skips section headers and parses questions', () {
      const text = '''
Cardiovascular System (1–8)

1. Which of the following is the primary function of the heart?
A. To pump blood throughout the body
B. To filter waste from the blood
C. To produce red blood cells
D. To regulate body temperature
E. To store nutrients

2. What is the normal resting heart rate for an adult?
A. 40-60 beats per minute
B. 60-100 beats per minute
C. 100-120 beats per minute
D. 120-140 beats per minute
E. 140-160 beats per minute
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 2);

      expect(questions[0].questionText, 'Which of the following is the primary function of the heart?');
      expect(questions[0].options, ['To pump blood throughout the body', 'To filter waste from the blood', 'To produce red blood cells', 'To regulate body temperature', 'To store nutrients']);
  expect(questions[0].correctAnswers[0], true);

      expect(questions[1].questionText, 'What is the normal resting heart rate for an adult?');
      expect(questions[1].options, ['40-60 beats per minute', '60-100 beats per minute', '100-120 beats per minute', '120-140 beats per minute', '140-160 beats per minute']);
  expect(questions[1].correctAnswers[0], true);
    });

    test('_extractQuestions handles empty text', () {
      final questions = parsingService.extractQuestions('');
      expect(questions, isEmpty);
    });

    test('_extractQuestions handles malformed text', () {
      const text = 'Some random text without questions.';
      final questions = parsingService.extractQuestions(text);
      expect(questions, isEmpty);
    });

    test('parseFile throws UnsupportedError for .doc files', () async {
      final mockFile = File('test.doc');

      expect(
        () async => await parsingService.parseFile(mockFile),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            'Convert .doc to .docx or PDF for support.',
          ),
        ),
      );
    });

    test('parseFile throws UnsupportedError for unsupported file types', () async {
      final mockFile = File('test.txt');

      expect(
        () async => await parsingService.parseFile(mockFile),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            'Unsupported file type. Only PDF and DOCX files are supported.',
          ),
        ),
      );
    });

    test('_extractQuestions parses complex .doc content with sections and questions', () {
      const text = '''
this is the content. Internal Medicine Question Set 7

Cardiovascular System (1–8)
1.	Cardiac Tamponade – Pathophysiology
A. Rapid accumulation of fluid impairs cardiac filling.
B. Pulsus paradoxus exceeds 10 mm Hg.
C. Kussmaul’s sign is diagnostic.
D. Beck’s triad includes hypotension, muffled heart sounds, and raised JVP.
E. Cardioversion is curative in tamponade.

2.	Eisenmenger Syndrome
A. Results from untreated left-to-right shunt.
B. Cyanosis develops later in life.
C. Pulmonary hypertension is a consequence.
D. Right-to-left shunt reverses the initial lesion.
E. Phlebotomy is always indicated for management.

3.	Bifascicular Block
A. Combination of RBBB and left anterior hemiblock.
B. May progress to complete heart block.
C. Commonly seen in older adults.
D. Requires permanent pacemaker in all cases.
E. ECG shows prolonged QRS and axis deviation.

4.	Restrictive Cardiomyopathy
A. Amyloidosis is a frequent cause.
B. Ventricular wall thickening is typical but non-hypertrophic.
C. Systolic function preserved until late.
D. Presents with signs of both right and left heart failure.
E. Digoxin improves long-term survival.

5.	Pulmonary Embolism – Massive
A. Causes acute right ventricular failure.
B. Presents with syncope and hypotension.
C. ECG shows S1Q3T3 pattern.
D. Thrombolysis may restore hemodynamics.
E. All cases present with hemoptysis.

6.	Prolonged QT Syndromes
A. Predispose to torsades de pointes.
B. May be congenital or acquired.
C. Hypokalemia and hypocalcemia can prolong QT.
D. Beta-blockers are indicated in congenital forms.
E. Amiodarone is first-line therapy.

7.	Infective Endocarditis – Subacute
A. Streptococcus viridans is a common agent.
B. Occurs on abnormal valves.
C. Splenomegaly may be present.
D. Osler nodes are tender lesions on fingers.
E. Rash of infective endocarditis always involves palms.

8.	Apical Hypertrophic Cardiomyopathy
A. More common in Asian populations.
B. Giant T waves may be present on ECG.
C. LV apex thickens disproportionately.
D. Sudden death may occur.
E. ACE inhibitors are standard therapy.
________________________________________

Respiratory System (9–15)
9.	Chronic Allergic Aspergillosis
A. IgE-mediated hypersensitivity.
B. Central bronchiectasis may be seen.
C. More common in asthma or CF.
D. Afebrile presentation typical.
E. Glucocorticoids always contraindicated.

10.	Silicosis
A. Associated with quarry and mine workers.
B. Eggshell calcification of lymph nodes.
C. Increased risk of tuberculosis.
D. Presents with chronic cough and dyspnea.
E. Lung transplantation is standard therapy.

11.	Pleural Empyema
A. Collection of pus in pleural space.
B. Decortication may be surgical intervention.
C. Fever, chest pain, and cough are common.
D. All cases need chest tube drainage.
E. Can follow pneumonia or thoracic surgery.

12.	Acute Respiratory Acidosis
A. Results from hypoventilation.
B. COPD can cause.
C. CNS depression may be a cause.
D. pCO2 is increased on ABG.
E. Bicarbonate therapy is first-line for all.

13.	Spontaneous Pneumothorax
A. More common in tall, thin young males.
B. Sudden pleuritic chest pain and dyspnea.
C. Reduced breath sounds on affected side.
D. Needle decompression is first-line for all cases.
E. Recurrence is common.

14.	Bronchiectasis – Non-CF
A. Caused by recurrent infections or obstruction.
B. Daily copious purulent sputum may occur.
C. Hemoptysis is a possible complication.
D. High-resolution CT shows dilated bronchi.
E. Smoking is the main risk factor.
15.	Tracheoesophageal Fistula – Adult
A. Can result from malignancy or trauma.
B. Recurrent aspiration pneumonia is typical.
C. Barium swallow used in diagnosis.
D. Surgical correction required in all cases.
E. All cases present with hematemesis.
________________________________________
Renal & Electrolyte System (16–22)
16.	Hyperkalemia
A. Can cause peaked T waves on ECG.
B. Chronic kidney disease is a common cause.
C. Insulin drives potassium into cells.
D. Calcium gluconate protects the heart.
E. Aldosterone deficiency can cause hyperkalemia.

17.	Goodpasture Syndrome
A. Anti-glomerular basement membrane antibodies present.
B. Causes both glomerulonephritis and alveolar hemorrhage.
C. Males more commonly affected than females.
D. Smoking is a risk factor for pulmonary involvement.
E. Plasma exchange is a treatment option.

18.	Rhabdomyolysis
A. Muscle breakdown releases myoglobin.
B. Causes acute tubular necrosis.
C. CK levels are markedly elevated.
D. Can result from crush injuries.
E. Urine dipstick is negative for blood.

19.	Hereditary Nephritis (Alport)
A. X-linked inheritance is most common form.
B. Progressive sensorineural hearing loss occurs.
C. Ocular abnormalities may be present.
D. Hematuria is typically the first sign.
E. All patients develop end-stage renal disease by age 30.
20.	Hypomagnesemia
A. Often associated with hypokalemia.
B. Can cause hypocalcemia.
C. Tetany may occur.
D. Diuretics can cause magnesium loss.
E. Magnesium replacement corrects associated electrolyte abnormalities.

21.	Contrast-Induced Nephropathy
A. Risk increased in diabetes and CKD.
B. Peak serum creatinine occurs 48-72 hours post-procedure.
C. N-acetylcysteine may be protective.
D. Hydration is the most effective prevention.
E. All contrast agents have equal nephrotoxicity.

22.	Gitelman Syndrome
A. Defect in distal convoluted tubule.
B. Hypokalemia and hypomagnesemia are typical.
C. Hypocalciuria is characteristic.
D. Usually presents in adulthood.
E. Magnesium supplementation improves symptoms.
________________________________________
Gastrointestinal System (23–30)
23.	Crohn Disease
A. Can affect any part of GI tract from mouth to anus.
B. Skip lesions are characteristic.
C. Full-thickness inflammation occurs.
D. Fistulae and strictures are complications.
E. Smoking improves disease course.

24.	Hereditary Pancreatitis
A. PRSS1 gene mutation is a cause.
B. Presents with recurrent acute pancreatitis.
C. Increased risk of pancreatic adenocarcinoma.
D. Autosomal dominant inheritance pattern.
E. Never progresses to chronic pancreatitis.
25.	Primary Hemochromatosis
A. HFE gene mutations cause disease.
B. Iron overload affects liver, heart, and pancreas.
C. Transferrin saturation is typically elevated.
D. Phlebotomy is the standard treatment.
E. Women are more commonly affected than men.

26.	Achalasia
A. Loss of esophageal peristalsis.
B. Lower esophageal sphincter fails to relax.
C. "Bird's beak" appearance on barium swallow.
D. Pneumatic dilation is a treatment option.
E. All cases are caused by Chagas disease.

27.	Alpha-1 Antitrypsin Deficiency – Liver
A. PiZZ genotype most severe.
B. Can cause neonatal cholestasis.
C. Periodic acid-Schiff positive globules in hepatocytes.
D. Liver transplantation may be required.
E. Augmentation therapy prevents liver disease.

28.	Gastrinoma (Zollinger-Ellison)
A. Most commonly located in duodenum.
B. Associated with MEN1 syndrome.
C. Secretin stimulation test is diagnostic.
D. Proton pump inhibitors control acid hypersecretion.
E. All gastrinomas are malignant.

29.	Mesenteric Venous Thrombosis
A. Associated with hypercoagulable states.
B. Can cause intestinal ischemia.
C. CT angiography is diagnostic.
D. Anticoagulation is the treatment.
E. Always requires surgical intervention.
30.	Hepatorenal Syndrome
A. Occurs in advanced liver disease with ascites.
B. Functional renal failure without structural kidney damage.
C. Type 1 has rapid onset and poor prognosis.
D. Terlipressin may improve renal function.
E. Renal biopsy shows specific changes.
________________________________________
Endocrinology (31–36)
31.	Non-Classic Congenital Adrenal Hyperplasia
A. Mild enzyme deficiency compared to classic form.
B. Presents with hirsutism and menstrual irregularity.
C. Androgen excess in females is typical.
D. May be diagnosed in adulthood.
E. Salt-wasting is a frequent finding.

32.	Hyperaldosteronism
A. Presents with hypertension and hypokalemia.
B. Spironolactone is often used for treatment.
C. Most cases are secondary to adrenal hyperplasia.
D. Renin levels are suppressed.
E. Surgical removal cures all cases.

33.	Factitious Hypoglycemia
A. Due to surreptitious insulin or sulfonylurea use.
B. Insulin levels elevated, C-peptide low with exogenous insulin.
C. Proinsulin levels always elevated.
D. Psychiatric evaluation often needed.
E. May present with neuroglycopenic symptoms.

34.	Graves Orbitopathy
A. Exophthalmos and lid retraction.
B. Worse in smokers.
C. Can occur after radioiodine therapy.
D. Myasthenia gravis is commonly co-morbid.
E. Glucocorticoids used for severe cases.
35.	Insulin Resistance Syndromes
A. Associated with obesity.
B. Leads to hyperinsulinemia.
C. Acanthosis nigricans may be present.
D. Can be seen in PCOS.
E. All forms are secondary to receptor gene mutations.

36.	Hypoparathyroidism
A. Chvostek and Trousseau signs positive.
B. Causes include post-thyroidectomy and autoimmune disease.
C. Causes hypocalcemia and hyperphosphatemia.
D. Vitamin D supplementation is required.
E. Seizures are a common complication.
________________________________________
Hematology (37–42)
37.	Paroxysmal Cold Hemoglobinuria
A. Biphasic hemolysin (Donath-Landsteiner antibody).
B. Hemolysis worsens after cold exposure.
C. Post-viral episodes in children.
D. Hemoglobinuria may occur.
E. Treatment is mainly cold avoidance.

38.	Aplastic Crisis
A. Temporary cessation of erythropoiesis.
B. Common with parvovirus B19 in sickle cell.
C. Reticulocytopenia seen.
D. Platelet count always low.
E. Resolves with supportive care in most.

39.	G6PD Deficiency
A. X-linked disorder.
B. Hemolysis may occur after oxidant drugs/fava beans.
C. Heinz bodies and bite cells on smear.
D. More common in males.
E. Chronic hemolysis in all patients.
40.	Acute Promyelocytic Leukemia (APL)
A. Associated with t(15;17) translocation.
B. DIC is a frequent complication.
C. All-trans retinoic acid (ATRA) is used in treatment.
D. Presents with pancytopenia and bleeding.
E. Always aggressive and incurable.

41.	Sickle Cell Trait
A. Usually asymptomatic.
B. Hematuria may occur.
C. No sickling on peripheral smear unless hypoxic.
D. Provides some malaria protection.
E. All traits develop sickle cell crises.

42.	Megaloblastic Anemia (B12 Deficiency)
A. Macrocytic anemia and hypersegmented neutrophils.
B. Neurologic symptoms possible.
C. Atrophic glossitis may be seen.
D. Pernicious anemia is autoimmune B12 deficiency.
E. Schilling test is used for iron absorption.
________________________________________
43.	Transient Global Amnesia
A. Sudden, temporary loss of memory.
B. No other focal neurological deficits.
C. Occurs more commonly in older adults.
D. MRI usually shows hippocampal lesions acutely.
E. Recurrence is very common.

44.	Subacute Combined Degeneration
A. Due to vitamin B12 deficiency.
B. Involves dorsal columns and corticospinal tracts.
C. Ataxia and spasticity may develop.
D. MRI may show spinal cord hyperintensity.
E. Correcting B12 immediately reverses all symptoms.
45.	Progressive Supranuclear Palsy
A. Parkinsonism with poor response to levodopa.
B. Supranuclear gaze palsy (especially vertical).
C. Early postural instability and falls.
D. Cognitive impairment may occur.
E. Tremor is the main feature.

46.	Benign Paroxysmal Positional Vertigo (BPPV)
A. Due to otoliths in semicircular canals.
B. Brief episodes of vertigo with position change.
C. Dix-Hallpike maneuver reproduces symptoms.
D. Epley maneuver may resolve symptoms.
E. Hearing loss is common.

47.	Myotonia Congenita
A. Autosomal dominant inheritance most common.
B. Delayed muscle relaxation after contraction.
C. Warm-up phenomenon observed.
D. Symptoms often improve with exercise.
E. Severe muscle atrophy always occurs.
________________________________________
Rheumatology (48–51)
48.	Calcium Pyrophosphate Deposition Disease (Pseudogout)
A. Chondrocalcinosis seen on imaging.
B. Rhomboid-shaped positively birefringent crystals.
C. Commonly affects the knee.
D. Associated with hyperparathyroidism.
E. Colchicine is never effective.

49.	Mixed Connective Tissue Disease
A. Overlap of SLE, scleroderma, and polymyositis features.
B. Anti-U1 RNP antibody positive.
C. Raynaud’s phenomenon may occur.
D. Pulmonary hypertension is a complication.
E. Always negative for any autoantibodies.
50.	Henoch-Schönlein Purpura
A. IgA immune complex small vessel vasculitis.
B. Palpable purpura is characteristic.
C. Arthralgia and abdominal pain may occur.
D. Renal involvement possible.
E. Most cases require immunosuppression.

51.	Relapsing Polychondritis
A. Recurrent inflammation of cartilage (ears/nose).
B. Saddle nose deformity may develop.
C. Laryngeal involvement can occur.
D. Associated with autoimmune disorders.
E. All cases rapidly progressive and fatal.
________________________________________
Infectious Diseases (52–55)
52.	Q Fever
A. Coxiella burnetii causative agent.
B. Associated with animal contact.
C. Culture-negative endocarditis manifestation.
D. Doxycycline is recommended treatment.
E. Spore-forming bacteria.

53.	Hantavirus Pulmonary Syndrome
A. Spread by rodent excreta.
B. Presents as acute respiratory distress syndrome.
C. Thrombocytopenia is typical.
D. Ribavirin is specific therapy.
E. May progress to shock.

54.	Rabies
A. Caused by neurotropic virus.
B. Transmitted by animal bites.
C. Long incubation period is typical.
D. Post-exposure prophylaxis can prevent disease.
E. Paralytic form is most common.
55.	Chikungunya Fever
A. Alphavirus spread by Aedes mosquitoes.
B. Severe joint pain and swelling.
C. Maculopapular rash typical.
D. Chronic arthritis may follow.
E. Corticosteroids are needed acutely in all cases.
________________________________________

Dermatology (56)
56.	Pityriasis Rosea
A. Herald patch usually precedes generalized rash.
B. "Christmas tree" distribution on trunk.
C. Self-limited condition.
D. Associated with HSV infection.
E. Needs systemic therapy in all cases.
________________________________________

Genetics (57)
57.	Wilson Disease – Genetics
A. Autosomal recessive inheritance pattern.
B. ATP7B gene mutation.
C. Defective copper excretion in bile.
D. Parents are obligate carriers.
E. All mutations are de novo.
________________________________________

Miscellaneous (58–60)
58.	Hyperventilation
A. Lowers PaCO2.
B. Causes respiratory alkalosis.
C. May induce carpopedal spasm.
D. Seen in anxiety attacks.
E. Always points to central nervous system pathology.

59.	Geriatric Syndromes
A. Falls are multifactorial in cause.
B. Polypharmacy increases risk of adverse drug events.
C. Delirium more common in hospitalized elderly.
D. Elder abuse must be reported.
E. All elderly become demented.

60.	Immunizations in Adults
A. Influenza vaccine recommended annually.
B. Pneumococcal vaccine for those >65 years.
C. Tdap booster every 10 years.
D. Live vaccines safe in all immunocompromised adults.
E. Zoster vaccine reduces risk of shingles.
________________________________________
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 60);

      // Test first question
      expect(questions[0].questionText, 'Cardiac Tamponade – Pathophysiology');
      expect(questions[0].options.length, 5);
      expect(questions[0].options[0], 'Rapid accumulation of fluid impairs cardiac filling.');
  expect(questions[0].correctAnswers[0], true);

      // Test a middle question
      expect(questions[29].questionText, 'Hepatorenal Syndrome');
      expect(questions[29].options.length, 5);
      expect(questions[29].options[4], 'Renal biopsy shows specific changes.');

      // Test last question
      expect(questions[59].questionText, 'Immunizations in Adults');
      expect(questions[59].options.length, 5);
      expect(questions[59].options[4], 'Zoster vaccine reduces risk of shingles.');
    });

    test('_extractQuestions handles concatenated question and options like "Relapsing PolychondritisA. ..."', () {
      const text = '''
51.	Relapsing PolychondritisA. Recurrent inflammation of cartilage (ears/nose).B. Saddle nose deformity may develop.C. Laryngeal involvement can occur.D. Associated with autoimmune disorders.E. All cases rapidly progressive and fatal.
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 1);
      expect(questions[0].questionText, 'Relapsing Polychondritis');
      expect(questions[0].options.length, 5);
      expect(questions[0].options[0], 'Recurrent inflammation of cartilage (ears/nose).');
      expect(questions[0].options[1], 'Saddle nose deformity may develop.');
      expect(questions[0].options[2], 'Laryngeal involvement can occur.');
      expect(questions[0].options[3], 'Associated with autoimmune disorders.');
      expect(questions[0].options[4], 'All cases rapidly progressive and fatal.');
  expect(questions[0].correctAnswers[0], true);
    });

    test('_extractQuestions handles non-numbered concatenated format like "Tuberculosis – ExtrapulmonaryA. ..."', () {
      const text = '''
Tuberculosis – ExtrapulmonaryA. Pleural, lymphatic, and bone disease are common forms.B. CSF findings in TB meningitis: high protein, low glucose.C. Miliary TB presents with diffuse small nodular infiltrates on chest X-ray.D. Four-drug initial therapy is standard.E. All patients have positive sputum smear.

Syphilis – Secondary StageA. Rash on palms and soles.B. Condyloma lata may develop.C. Highly infectious stage.D. Serology (RPR, VDRL, FTA-ABS) is positive.E. Always progresses to tertiary syphilis if untreated.
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 2);
      
      // First question
      expect(questions[0].questionText, 'Tuberculosis – Extrapulmonary');
      expect(questions[0].options.length, 5);
      expect(questions[0].options[0], 'Pleural, lymphatic, and bone disease are common forms.');
      expect(questions[0].options[1], 'CSF findings in TB meningitis: high protein, low glucose.');
      expect(questions[0].options[2], 'Miliary TB presents with diffuse small nodular infiltrates on chest X-ray.');
      expect(questions[0].options[3], 'Four-drug initial therapy is standard.');
      expect(questions[0].options[4], 'All patients have positive sputum smear.');
      
      // Second question
      expect(questions[1].questionText, 'Syphilis – Secondary Stage');
      expect(questions[1].options.length, 5);
      expect(questions[1].options[0], 'Rash on palms and soles.');
      expect(questions[1].options[1], 'Condyloma lata may develop.');
      expect(questions[1].options[2], 'Highly infectious stage.');
      expect(questions[1].options[3], 'Serology (RPR, VDRL, FTA-ABS) is positive.');
      expect(questions[1].options[4], 'Always progresses to tertiary syphilis if untreated.');
    });

    test('_extractQuestions handles mixed format with headers, numbered, and non-numbered concatenated questions', () {
      const text = '''
Dermatology (58), Genetics (59), Misc (60)

Lichen PlanusA. Purple, polygonal, pruritic, flat-topped papules.B. Wickham striae can be seen on mucous membranes.C. May be associated with hepatitis C.D. Affects flexor surfaces and oral mucosa.E. All require systemic corticosteroids.

Neurofibromatosis Type 1A. Autosomal dominant inheritance.B. Café-au-lait macules and axillary freckles.C. Lisch nodules (iris hamartomas) are typical.D. Increased risk of optic glioma.E. All develop malignant peripheral nerve sheath tumors.

Palliative Care – Symptom ManagementA. Pain control is fundamental.B. Opioids may be titrated for dyspnea.C. Delirium should be addressed.D. Early palliative care can improve quality of life and sometimes survival.E. Palliative care is only for end-of-life.
''';

      final questions = parsingService.extractQuestions(text);

      expect(questions.length, 3);
      expect(questions[0].questionText, 'Lichen Planus');
      expect(questions[0].options.length, 5);
      expect(questions[1].questionText, 'Neurofibromatosis Type 1');
      expect(questions[1].options.length, 5);
      expect(questions[2].questionText, 'Palliative Care – Symptom Management');
      expect(questions[2].options.length, 5);
    });

    // Note: Testing actual PDF and DOCX parsing would require mock files
    // For now, we test the extension checking logic
  });
}