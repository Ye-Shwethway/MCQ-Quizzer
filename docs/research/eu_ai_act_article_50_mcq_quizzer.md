# EU AI Act Article 50 — MCQ Quizzer release note

**Research date:** 2026-09-12

**Scope:** Article 50 transparency duties relevant to MCQ Quizzer's local, bring-your-own-key (BYOK) quiz-generation workflow.
**Sources:** Official EU sources only. This is a product-planning note, not legal advice. The Commission's own Article 50 Guidelines are non-binding; authoritative interpretation ultimately belongs to the Court of Justice of the European Union.

## Executive assessment

If MCQ Quizzer is offered in the EU after 2 August 2026, the cautious release position is to treat the app publisher as a **provider of a downstream interactive and generative AI system**, even though users supply their own third-party model API key. The app is offered under its own identity, takes a user's topic/instructions, invokes a model, transforms the response into a structured quiz, and displays that output directly to the user. That makes Articles 50(1), 50(2), and 50(5) plausibly applicable. This classification needs qualified EU legal review because the exact technical and contractual allocation across MCQ Quizzer and each upstream provider matters.

The immediate product gates are:

1. Clearly identify the AI interaction **before or at the first generation interaction**, in context and accessibly. A disclosure hidden only in settings, terms, or a privacy policy is insufficient under the Commission Guidelines.
2. Clearly and persistently identify every generated quiz as AI-generated, including in the generator, library, quiz/review views, and exports. Pair this with the already-approved warning that AI content and answers may be wrong and are not authoritative medical, legal, or educational advice.
3. Preserve machine-readable AI-origin/provenance information from generation through local storage, editing, export, sharing, backup, and re-import. Do not assume a visible badge or an internal boolean alone satisfies Article 50(2); the marking/detection method requires a standards and legal review.
4. Inventory upstream providers' marking capabilities and do not strip compliant upstream provenance. Reliance on an upstream or third-party marking solution is possible, but the downstream system provider remains responsible for demonstrating compliance.
5. Document the chosen compliance path against the Commission Guidelines and the approved voluntary Code of Practice. If the Owner does not sign the Code, maintain an evidence-backed gap analysis showing equivalent adequate measures.

## Dates and territorial reach

- Article 50 applies from **2 August 2026**. Its provider and deployer duties can reach entities outside the EU when they place systems on the EU market or foresee the system's output being used in the EU. An all-country Play launch that includes the EU therefore makes EU applicability a reasonable planning assumption. [AI Act, consolidated text, Articles 2 and 50](https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27/eng)
- A narrow transition applies only to **Article 50(2)** marking/detection for generative AI systems already placed on the market before 2 August 2026: those systems must comply by **2 December 2026**. It does not postpone Articles 50(1), 50(4), or 50(5). Content generated before 2 August 2026 need not be labelled retroactively. [Commission Article 50 FAQ](https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act)
- Because the Owner has designated the Play release as a **new listing**, the safe release assumption is immediate compliance, not reliance on grandfathering. Counsel should confirm whether any earlier APK distribution legally constituted placement on the market and whether later changes create a new system; relying on the transition is not recommended for launch planning.

## Provider and deployer roles

The Act defines a provider as an entity that develops an AI system, or has one developed, and places it on the market or puts it into service under its own name or trademark. A deployer uses an AI system under its authority, except for purely personal, non-professional use. One entity can hold both roles. The Guidelines expressly recognise downstream AI-system providers built on upstream general-purpose models and state that model-level measures can facilitate, but do not replace, downstream compliance. [Commission Article 50 Guidelines, §§10–17 and 26–28](https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf)

### Plausible MCQ Quizzer allocation

| Actor | Plausible role | Planning consequence |
|---|---|---|
| MCQ Quizzer publisher | Provider of the app-level/downstream AI system | Treat Articles 50(1), (2), and (5) as release requirements. BYOK alone does not clearly remove this role. |
| OpenAI, Gemini, OpenRouter, NanoGPT, or a custom endpoint | Provider of an upstream model/system | Record contractual and technical marking support per provider; preserve compliant marks where supplied. |
| Individual studying privately | Usually a purely personal, non-professional user; deployer obligations are excluded for that personal activity | Their private local quiz generation does not by itself make the publisher a deployer or create a public-publication duty. |
| Teacher, business, publisher, or professional using generated quizzes | Could be a deployer depending on authority and use | Their own publication/use may trigger duties; give them exportable provenance and clear guidance rather than implying the app transfers all compliance. |
| MCQ Quizzer publisher publishing generated quizzes or support content | Potentially also a deployer | Human-review/editorial controls and public-interest labelling need a separate operational policy. |

**Owner legal-review gate:** confirm the app-level provider classification and value-chain allocation using the final architecture, provider terms, branding, and exact EU distribution facts.

## Article 50(1): direct AI interaction disclosure

Article 50(1) requires providers to design directly interactive AI systems so people are informed that they are interacting with AI, unless that is obvious to a reasonably well-informed, observant, and circumspect person in context. The Guidelines interpret interaction broadly: it can be a single prompt and a single contextual response, can use written text or other actions, and need not be multi-turn chat. Direct interaction exists when the system itself makes the output available without a human intermediary. [AI Act Article 50(1)](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50) [Commission Guidelines, §§28–40](https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf)

MCQ Quizzer's topic/instructions → generated quiz flow therefore plausibly qualifies even if it is not conversational. The “obvious” exception should be treated narrowly; explicit disclosure is low-cost and safer.

Recommended gate:

- Before the first generation action, say plainly that an AI model will generate the questions and answers.
- Keep an “AI-generated” origin indicator in the resulting quiz and downstream views.
- State the consequence, not only the technology: generated questions, explanations, and answers can be inaccurate and must be independently checked, especially for medicine and law.
- Make the notice screen-reader accessible and sufficiently contrasted. A terms-only notice, generic “uses LLMs” statement, or non-perceivable metadata is not enough. The Guidelines say one prominent notice before first interaction will often suffice, but riskier contexts may warrant contextual reminders.

## Article 50(2): machine-readable marking and detectability

Providers of systems generating synthetic text must ensure outputs are marked in a machine-readable format and detectable as AI-generated or manipulated. The technical solution must be effective, interoperable, robust, and reliable as far as technically feasible, considering content type, implementation cost, and the acknowledged state of the art. Standard editing and non-substantive alterations have a limited exception; newly generated quiz questions and answers are unlikely to be mere standard editing. [AI Act Article 50(2)](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50) [Commission Guidelines, §§57–88](https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf)

For MCQ Quizzer, this is the main unresolved compliance risk:

- A local database field such as `origin = ai_generated` is useful and machine-readable, but may not alone be interoperable or make detection available to every person later exposed to exported content.
- A visible “AI-generated” badge supports human transparency but does not replace machine-readable marking.
- The app currently normalises upstream model output into its own quiz structure; that process must not silently discard upstream provenance or compliant markings.
- The Guidelines' narrow industrial/B2B proportionality cases do not plausibly fit a public consumer study app, and their ephemeral-output example does not fit quizzes that are stored, exported, or shared.
- Each exported/shared form needs an origin-preservation design. Structured exports can carry explicit provenance fields; human-facing documents should also carry a visible label. For formats with recognised provenance standards, use the applicable standard rather than inventing an invisible watermark.
- The Guidelines allow marking at different points in the value chain and reliance on a compliant upstream/third-party solution, but responsibility to demonstrate the app-level system's compliance remains with its provider.

Recommended technical/legal checkpoint before EU release:

1. Map every output and transformation: model response, parser, stored quiz, edits, display, backup, JSON/CSV/PDF/share, and re-import.
2. Define durable provenance data with at least artificial origin, generation time, upstream provider/model identifier, and later human-review/edit state. Never store or expose the API key in provenance.
3. Determine the recognised, interoperable marking method for each export modality using the final Code of Practice and current standards.
4. Provide a documented means to detect/read the mark and a human-readable result.
5. Test survival through normal app transformations and document limitations, reliability, accessibility, and provider dependencies.
6. Compare the implementation against the approved Code of Practice and retain the gap analysis and test evidence.

**Owner legal/technical-review gate:** approve the marking standard and evidence plan. Do not treat a disclaimer, database flag, provider/model label, or report endpoint as sufficient by itself.

## Article 50(4): deepfakes and public-interest text

The app does not currently generate image/audio/video deepfakes, so the first part of Article 50(4) appears out of scope unless the feature set changes.

The second part applies to deployers that publish AI-generated/manipulated text for the purpose of informing the public on matters of public interest. Commission examples include public health, justice, fundamental rights, consumer safety, and scientific or cultural developments. It does not apply where qualifying human review/editorial control has occurred and a person or legal entity holds editorial responsibility. Superficial grammar or spell checks are not substantive human review. [Commission Article 50 FAQ](https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act)

A quiz saved privately on a user's phone is not obviously “published” to the public. User-initiated sharing also does not automatically make the app publisher the deployer. However, medical, legal, civic, scientific, or current-affairs quiz text published by the Owner, a school, a business, or a professional could satisfy the public-interest criteria.

Release posture:

- Do not add an Owner-hosted public gallery of AI quizzes without a separate Article 50(4) review.
- Preserve AI-origin labels in exports so professional users can meet their own duties.
- If the Owner publishes generated content, require a documented substantive reviewer with relevant knowledge, an approve/edit/reject step, and named editorial responsibility—or label it clearly as AI-generated at first exposure.

**Owner legal-review gate:** assess any public gallery, community sharing, curated packs, social publishing, or Owner-authored store/support content before launch.

## Article 50(5): timing, clarity, and accessibility

Information required by paragraphs 1–4 must be clear and distinguishable, supplied no later than first interaction/exposure, and meet applicable accessibility requirements. For interaction, the Guidelines indicate disclosure at least once at the start of an interactive session; for in-scope generated content, disclosure attaches to each output and each natural person exposed. [Commission Guidelines, §§139–146](https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf)

Release acceptance should therefore include screen-reader semantics, contrast, text scaling, small-screen wrapping, and verification that the notice is not hidden below the primary generate action. Because the target audience is general students/adults rather than specifically children, child-directed presentation is not the intended baseline; the app should still account for reasonably foreseeable younger and disabled users in disclosure design.

## Compliance evidence and operational boundaries

The approved voluntary Code of Practice covers Articles 50(2), (4), and (5). The Commission and AI Board regard it as an adequate route to demonstrate compliance, but adherence is voluntary and is not conclusive proof. Non-signatories should expect to demonstrate equivalent adequate means, including a gap analysis against the Code. [Commission Code overview](https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content) [Commission assessment](https://digital-strategy.ec.europa.eu/en/library/commission-opinion-assessment-code-practice-transparency-ai-generated-content)

The planned in-app AI-content report flow and 90-day retention are useful safety and accountability controls, but they do **not** substitute for Article 50 disclosure or machine-readable marking. Likewise, Article 50 compliance does not establish that medical, educational, privacy, consumer-protection, copyright, or other uses are lawful.

Before the EU release gate is signed off, the Owner should obtain qualified review of:

- provider/deployer roles and territorial scope;
- whether the app was previously “placed on the market” and any transition claim;
- the selected machine-readable marking/detection standard for text and each export format;
- whether to sign the voluntary Code of Practice or maintain an alternative-means evidence package;
- public-sharing/community features and the public-interest-text rule;
- medical/legal positioning, consumer disclosures, accessibility, privacy, and report retention;
- provider contracts and whether upstream marking/provenance survives the app's processing.

## Official sources

- [Regulation (EU) 2024/1689, consolidated 27 July 2026](https://eur-lex.europa.eu/eli/reg/2024/1689/2026-07-27/eng)
- [European Commission Guidelines on Article 50, C(2026) 5054 final](https://ai-act-service-desk.ec.europa.eu/sites/default/files/2026-07/guidelines_on_the_implementation_of_the_transparency_obligations_for_certain_ai_systems_under_article_50_of_the_ai_act_bzptwqhk0ikg1dtlddap41psfy_131215.pdf)
- [European Commission Article 50 questions and answers](https://digital-strategy.ec.europa.eu/en/faqs/transparency-obligations-under-article-50-ai-act)
- [European Commission Code of Practice on Transparency of AI-generated Content](https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content)
- [European Commission opinion on the Code's adequacy](https://digital-strategy.ec.europa.eu/en/library/commission-opinion-assessment-code-practice-transparency-ai-generated-content)
