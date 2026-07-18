# Personal Health Companion

## Product brief — version 0.2

**Owner:** Dave  
**Platform:** iPhone  
**Date:** 17 July 2026  
**Status:** Discovery / definition  
**Working title:** Personal Health Companion

---

## 1. Background

I have used the Simple app for roughly seven and a half months: six months on its paid tier followed by about six weeks on the free tier. During that time, it has helped me lose **27 kg**.

The app succeeds for me because it makes healthy behaviours visible and easy to repeat. It does not feel like maintaining a complicated diet spreadsheet. Logging is quick, progress is always close at hand, and the fasting timer provides a simple structure for the day.

I now want to build a personal iPhone app tailored to the parts of that experience that genuinely help me. The aim is not to reproduce every Simple feature or copy its interface. It is to create a smaller, calmer tool built around my habits, preferences and long-term weight-management needs.

## 2. Why the current experience works for me

### Everything important is in one place

The app brings together food, drinks, fasting, weight and movement. I can understand the shape of my day without switching between several apps.

### Logging takes very little effort

I can record food by taking a photo or typing a natural-language description. The app then estimates useful nutritional information such as carbohydrate, fat, sugar, fibre and salt. This is much easier than finding and weighing every ingredient manually.

### It gives my eating day a clear structure

I currently use a **16-hour** fasting target, leaving an **8-hour eating window**. The timer encourages me to keep to that rhythm without having to plan every meal. The product should not hard-code this schedule: each user chooses a fasting goal of **12 hours or longer**.

### Progress remains visible without demanding attention

The current fast is shown on the iPhone Lock Screen, so I can check it at a glance without opening the app.

### It explains what may be happening during a fast

The app describes the likely stages of a fast, including changes in digestion, insulin and use of stored energy. This makes elapsed time feel meaningful and helps motivate me to continue.

### It connects behaviours with outcomes

I record my weight in the Health app, so the product should read and display that existing history rather than creating a separate, incomplete record. Movement data such as steps should also come from the Health app. That helps me see progress as the result of several ordinary behaviours rather than one perfect diet.

### The interface feels friendly and easy to use

The design is clear, attractive and low-friction. The important actions are obvious and daily logging does not feel like administration.

> **Assumption:** “great DU” has been interpreted as “great UI”. Weight is recorded in the Health app and should be read from HealthKit.

---

## 3. Research summary

Simple currently describes its product as a practical, positive AI coach for lasting weight loss without diets, food restrictions or judgement. Its current App Store listing emphasises personalised plans, real-time nutrition analysis, on-demand coaching and tailored workouts without requiring conventional calorie counting. Its broader product model links food, fasting, water, weight and movement into one daily experience.

The important product lesson is not that this app needs all of Simple's features. It is that the features reinforce one another:

1. **Capture:** quickly log something that happened.
2. **Interpret:** turn the entry into understandable information.
3. **Orient:** show where the user is now—fasting, eating, hydrated, active or progressing.
4. **Encourage:** suggest one achievable next action.
5. **Review:** show patterns and progress over time.

Simple also reports an observational association between more frequent engagement with its AI coach and greater weight loss among active users. This does not establish that the coach caused the weight loss, but it supports the broader product hypothesis that frequent, useful feedback can help sustain engagement.

### Implications for this product

- Optimise for **speed and repeat use**, not exhaustive data entry.
- Use nutrition estimates to build awareness, not to claim laboratory accuracy.
- Prefer calm, non-judgemental language over red warnings, guilt or “failed day” messaging.
- Make the current fasting state visible outside the app.
- Let Apple Health remain the system of record for supported health and activity data where practical.
- Keep AI optional and reviewable: the user should confirm or edit every food estimate.
- Treat health data as sensitive and design for local processing/storage where feasible.

---

## 4. Product vision

> A private, low-friction iPhone companion that helps me maintain healthier eating, hydration, fasting and movement habits by making my day understandable at a glance.

## 5. Product promise

**Log in seconds. Understand the day. Keep going.**

The app should help the user make the next reasonable choice. It should not try to diagnose health conditions, prescribe treatment or turn every meal into a pass/fail event.

## 6. Primary user

### Initial persona: Dave

- iPhone user in the UK; metric units and UK nutrition conventions.
- Vegan.
- Has already lost 27 kg and wants to continue safely or maintain that progress.
- Currently finds a 16:8 eating pattern useful, while requiring a configurable fasting goal starting at 12 hours.
- Values nutritional awareness but does not want laborious manual calorie counting.
- Wants a polished, glanceable app with minimal daily friction.
- Uses the Health app and wants movement and weight data connected.

The first release is deliberately a **single-user personal product**. Generalising for other users can wait until the core experience proves useful.

## 7. Jobs to be done

When I eat or drink, I want to record it in seconds so that tracking does not interrupt my day.

When I look at my phone, I want to know how long I have fasted and when my eating window starts or ends so that I can stick to my chosen rhythm.

When food is logged, I want an understandable nutritional estimate so that I can notice patterns without manually calculating every ingredient.

When motivation dips, I want to see evidence of my progress and recent consistency so that one imperfect choice does not derail me.

When I review a day or week, I want food, hydration, fasting, weight and movement in one view so that I can understand what is helping.

When I forget to use the app for a few days, I want to backdate food and drink entries and reconstruct the missing fasting history so that returning to the app does not mean losing my record or starting again.

---

## 8. Product principles

1. **Fast before comprehensive:** a useful approximate entry is better than an abandoned perfect one.
2. **Awareness before restriction:** inform choices without moralising about food.
3. **Trends before single numbers:** weekly patterns matter more than daily noise.
4. **One next action:** avoid dashboards that produce information but no clarity.
5. **Honest uncertainty:** label AI-derived nutrition and fasting physiology as estimates.
6. **Private by default:** collect and transmit as little sensitive data as possible.
7. **Personal first:** optimise for the habits that have already worked for Dave.
8. **Accessible and calm:** large tap targets, clear contrast, plain English and no shame-based streak mechanics.
9. **Easy to resume:** missing a few days must be recoverable without penalty or laborious administration.

## 9. Core daily experience

### Today screen

The home screen should answer five questions immediately:

- Am I currently fasting or inside my eating window?
- How long remains until the next fasting milestone or window change?
- What have I eaten and drunk today?
- How much movement have I done?
- Is there one useful thing to do next?

Primary actions:

- **Log food**
- **Log drink**
- **Start/end fast**
- **Log weight**

### Food capture flow

1. Take a photo or type/dictate a description.
2. Receive a proposed list of foods and portions.
3. Confirm or quickly edit foods and portion sizes.
4. Save the meal with estimated nutrition.
5. Show a short, neutral insight—for example, “Good source of fibre; protein looks light.”

The result should include, where the data supports it:

- energy (secondary, not the dominant score);
- protein;
- carbohydrate;
- fat and saturated fat;
- fibre;
- total sugar;
- salt;
- optional fruit and vegetable portions.

Because a single food image cannot reliably reveal ingredients or portion weight, photo analysis must always expose its assumptions and allow correction. A confidence label such as **high / medium / low** is preferable to false precision.

### Hydration flow

- One-tap favourites for water, tea and coffee.
- Remember common cup/glass sizes.
- Allow custom drinks and quantities in millilitres.
- Show total fluids for the day.
- Avoid implying that tea or coffee “doesn't count”; any optional hydration adjustment must be transparent.

### Fasting flow

- Let the user choose a fasting goal of **12 hours or longer**, in practical increments; initialise Dave's profile at **16 hours**.
- Start or stop manually, with sensible suggested times based on the last food entry.
- Allow correction of start/end times.
- Show elapsed time, target, eating-window times and recent consistency.
- Show a Lock Screen Live Activity while a fast is active.
- Provide optional reminders near the beginning and end of the eating window.

### Catch-up and history reconstruction flow

The product must tolerate being ignored for several days. Returning should feel like resuming, not failing.

1. Choose a past date or use **Catch up**.
2. Add backdated meals and drinks using the same quick-entry tools as today.
3. For each drink, indicate whether it was non-caloric or whether it should count as breaking a fast.
4. Ask the app to rebuild fasting history for the missing period.
5. Preview the proposed fasts derived from the last caloric entry of one day and the first caloric entry that follows.
6. Resolve ambiguous or implausible gaps, then confirm the reconstructed history.

The reconstruction must never silently overwrite confirmed fasts. It should distinguish:

- **confirmed fasts** explicitly started, stopped or approved by the user;
- **inferred fasts** calculated from backdated food and caloric-drink entries;
- **unknown periods** where there is not enough information to infer a fast honestly.

Water, unsweetened tea and black coffee may normally be marked as not breaking a fast, while additions such as sugar or plant milk may change that classification. The user must be able to override the default for any drink.

### Fasting-stage education

The app may show broad educational phases based on elapsed time, but must say clearly:

> “This is a general estimate based on time since your last meal. It is not a measurement of your blood glucose, insulin, ketosis or fat burning.”

Avoid definitive labels such as “your blood sugar is now low” or “you are now burning fat.” Individual metabolic response varies with meals, activity, sleep, health and medication.

### Progress flow

- Read the user's existing body-mass history from the Health app and refresh it automatically when permission allows.
- If the app offers weight entry, write the new sample to HealthKit so the Health app remains the primary record rather than maintaining a competing data silo.
- Show daily weight lightly and emphasise a 7-day or configurable trend.
- Show total change from a chosen starting point.
- Read steps and optionally active energy from the Health app.
- Present fasting consistency, hydration, food logging and movement together without inventing a single pseudo-scientific “health score.”

---

## 10. MVP scope

### Must have — release 1

| Capability | Minimum useful behaviour |
| --- | --- |
| Today screen | Current fasting state, today's logs, steps, weight trend and four quick actions |
| Fasting | User-defined goal from 12 hours upward; start/end/edit fast, timer, history and reminders |
| Catch-up | Backdate food and drinks, preview inferred fasts, confirm or correct reconstructed history |
| Lock Screen | Live Activity with elapsed/remaining time and current phase |
| Food text entry | Natural-language meal description converted into an editable food/nutrition estimate |
| Food history | Timeline of meals with nutrition breakdown and edit/delete |
| Hydration | Fast logging for water, tea, coffee and custom drinks |
| Weight | Read existing HealthKit body-mass history, show a trend, and write any in-app entries back to HealthKit |
| Movement | Read steps from HealthKit with clear permission handling |
| Privacy | On-device database, explicit consent and deletion/export controls |
| Settings | Metric units, fasting target of 12 hours or longer, eating-window times, reminders and nutrition display choices |

### Should have — release 1.1

- Food photo capture and editable AI interpretation.
- Reusable meals and recent foods.
- Vegan-aware feedback, especially protein, fibre and variety.
- Weekly review with a few plain-language observations.
- Home Screen widget.
- Data export in CSV or JSON.

### Could have — later

- Barcode scanning backed by a product database such as Open Food Facts.
- Voice-first logging through Siri/App Intents.
- Apple Watch companion.
- Meal planning and vegan recipe suggestions.
- Optional conversational coach.
- Private progress sharing with a chosen person.
- Correlations such as fasting consistency versus weight trend, with strong warnings that correlation is not causation.
- Cloud backup/sync if local-only storage proves insufficient.

### Explicitly out of scope for the MVP

- Social feeds, leaderboards or public profiles.
- Paid subscriptions or billing.
- General-purpose workout programmes.
- Clinical recommendations or diagnosis.
- Claims to measure glucose, insulin, ketosis or current fat burning without sensor data.
- A large recipe library.
- Android, web or multi-user accounts.
- Perfect calorie or portion accuracy from a photograph.

---

## 11. Functional requirements and acceptance criteria

### Fasting

- A user can start or end a fast in no more than two taps from the Today screen.
- A user can set a fasting goal of 12 hours or longer; changing the goal does not rewrite historical fast durations.
- An incorrect start or end time can be edited later.
- Crossing midnight does not split or corrupt a fast.
- The Lock Screen display remains useful when the app is not open.
- Notifications are optional and individually configurable.

### Catch-up and reconstructed history

- Food and drink entries can be created or edited for any past date and time.
- Rebuilding history produces a preview and requires confirmation before it changes fasting records.
- A reconstructed fast begins after the last confirmed caloric entry and ends at the next confirmed caloric entry.
- Non-caloric drinks remain visible in hydration history without automatically ending a fast.
- Conflicting entries are highlighted rather than resolved silently.
- Confirmed, inferred and unknown history are visually distinguishable.
- Re-running reconstruction is deterministic and does not create duplicate fasts.

### Food

- A typed meal can be submitted in one screen.
- The proposed meal is never saved as confirmed nutrition without a review opportunity.
- Every detected food, portion and nutrient estimate can be edited.
- The source is retained as `typed`, `photo`, `barcode` or `manual`.
- Estimated values are distinguishable from label/database values.

### Hydration

- A favourite drink can be logged in two taps or fewer.
- All quantities are stored consistently and displayed in ml or litres.
- Editing or deleting a drink updates the daily total immediately.
- A drink can be backdated and classified as fasting-safe or fast-breaking, with a sensible editable default.

### Health integration

- Permissions are requested only when a related feature is used and explain the benefit first.
- The app remains usable if any HealthKit permission is declined.
- Existing HealthKit body-mass samples appear in the product without requiring duplicate manual entry.
- Weight recorded elsewhere after the initial sync appears after refresh or background synchronisation.
- Duplicate samples are not created during repeated synchronisation.
- The source of a weight entry is visible.

### Data and trust

- The user can export their entries in a human-readable form.
- The user can delete all app-held data.
- Food photos are not retained after analysis unless the user chooses to keep them.
- Any off-device AI processing is disclosed before the first upload.
- No health data is used for advertising.

---

## 12. Conceptual data model

| Entity | Key information |
| --- | --- |
| User preferences | units, dietary preference, fasting target (minimum 12 hours), window, reminders |
| Fast | start, end, target duration at the time, confirmed/inferred status, derivation, notes |
| Meal | timestamp, description, photo reference, source, confidence, notes |
| Food item | name, quantity, unit, database reference, confidence |
| Nutrition estimate | energy, protein, carbs, fat, saturated fat, fibre, sugar, salt, provenance |
| Drink | timestamp, type, volume, favourite reference, caloric/fast-breaking classification |
| Weight sample | timestamp, kg, source, HealthKit identifier |
| Activity summary | date, steps, active energy, source |
| Insight | time range, observation, supporting data, confidence, dismissed state |

Provenance is important. The app should know whether a value came from a label/database, manual entry, AI estimate or HealthKit.

## 13. Success measures

For a personal app, success is behavioural usefulness rather than growth.

### MVP success criteria after four weeks

- Used on at least **5 days per week**.
- Median food or drink log takes **under 20 seconds**.
- At least **80% of intended fasts** are captured accurately enough to be useful.
- A gap of three days can be reconstructed and reviewed in **under five minutes**.
- Weekly review can be understood in **under one minute**.
- Fewer than **one frustrating correction per day** on average.
- Dave chooses the app over Simple for the core daily loop on most days.
- Continued use feels supportive rather than obsessive or burdensome.

### Quality guardrails

- No unlabelled physiological claims.
- No silent upload of health or food-photo data.
- No loss or duplication of HealthKit-linked records.
- Nutrition estimates always remain editable.
- A missed target never produces shaming language.

## 14. Key risks and mitigations

| Risk | Product response |
| --- | --- |
| Photo-derived nutrition appears more accurate than it is | Show detected foods, editable portions, provenance and confidence; use rounded values |
| Fasting stages are mistaken for sensor readings | Use educational ranges and a persistent “estimated, not measured” explanation |
| Tracking becomes obsessive or punitive | De-emphasise calories, avoid red failure states, support hiding metrics and taking breaks |
| Health advice is unsafe for some users | Include clear eligibility/safety messaging and advise medical guidance for relevant conditions or medication |
| Sensitive health data leaks | Local-first storage, least-privilege permissions, minimal retention and explicit upload consent |
| Scope expands into a clone of a mature commercial app | Protect the single-user MVP and validate each new feature against actual repeated use |
| AI cost or latency harms the experience | Cache common meals, support manual entry and keep the tracker usable without AI |
| Database values are incomplete or wrong | Display data source, permit correction and preserve the user's corrected version |
| Reconstructed fasting history creates false certainty | Require preview and confirmation; preserve unknown gaps; label inferred records |

## 15. Health and safety position

This is a wellbeing and habit-tracking product, not a medical device. It should not diagnose, treat or claim to prevent disease.

Before enabling fasting guidance, onboarding should advise the user to seek clinical guidance if fasting may be inappropriate—for example during pregnancy or breastfeeding, with a history of an eating disorder, with diabetes or glucose-lowering medication, or where another health condition or medicine makes meal timing important.

The product should make it easy to disable fasting, weight or nutrition features independently.

## 16. Privacy position

HealthKit gives users fine-grained control over which health data an app can read and write. This product should request only the minimum required data types, at the point of use, and remain functional when access is refused.

Recommended baseline:

- Store the journal locally on the iPhone by default.
- Use iCloud only as an explicit later decision, not an invisible dependency.
- Process text or images on-device where practical.
- If external AI is used, explain what is sent, why, where it is processed and whether it is retained.
- Separate health functionality from analytics; avoid third-party advertising SDKs.
- Provide export and complete deletion from the first public release.

## 17. Open product questions

1. Should the app help continue weight loss, maintain the current weight, or allow both modes?
2. Which nutrition values are genuinely useful every day: energy, protein, carbs, fat, fibre, sugar, salt, or something else?
3. Should food feedback remain descriptive, or compare intake with daily targets?
4. Is a photo history valuable, or should images be deleted once a meal is analysed?
5. Should a live fast start automatically from the last meal, or always require explicit confirmation?
6. During catch-up, should the app infer fasting boundaries immediately after each entry or only when the user selects **Rebuild history**?
7. Which parts of Simple's free tier are still essential, and which paid features were rarely used?
8. Is this permanently a personal app, or might it eventually be released to other people?

## 18. Recommended discovery before coding

### One-week diary study

For seven days, note each time Simple is opened:

- what triggered the visit;
- the action taken;
- how long it took;
- what information changed the next decision;
- any friction, ignored screen or unwanted coaching.

### Screen inventory

Capture or sketch the screens involved in the five core flows: food, drink, fasting, weight and daily review. Record what each element accomplishes without copying visual assets or wording.

### Prototype test

Create a tappable prototype for only the Today screen and the four quick actions. Test whether a full day can be tracked comfortably before building AI food analysis.

### Technical spike

Before committing to the MVP architecture, verify:

- HealthKit read/write behaviour for steps and body mass;
- Live Activity behaviour across a 16-hour fast;
- background and notification limits;
- natural-language meal analysis accuracy on ten typical vegan meals;
- cost, privacy and latency of any external AI service.

## 19. Suggested delivery sequence

### Prototype

Today screen, fake data, fasting timer and quick-log interactions.

### Alpha

Local storage, manual/text food entry, backdated nutrition and hydration, HealthKit weight, fasting history and reconstruction.

### Beta

HealthKit, Lock Screen Live Activity, export, privacy controls and weekly review.

### Post-beta

Photo-based food analysis, reusable meals, vegan-aware insights and barcode lookup.

This ordering deliberately tests whether the fundamental habit loop is valuable before adding the most uncertain and expensive feature: nutrition estimation from meal photos.

---

## 20. Source notes

- [Simple official site](https://simple.life/) — current positioning around practical, positive AI coaching and sustainable behaviour change.
- [Simple on the UK App Store](https://apps.apple.com/gb/app/simple-ai-weight-loss-coach/id1467720176) — current product description and advertised feature set.
- [Simple: four stages of intermittent fasting](https://simple.life/blog/stages-of-intermittent-fasting/) — the educational fasting-stage model used as product context.
- [Simple research summary on AI coach engagement](https://simple.life/blog/ai-health-coach-supports-weight-loss/) — company-reported observational engagement and weight-loss results; not evidence of causation.
- [Simple privacy policy](https://simple.life/privacy/en/) — useful comparison for the data flows and third parties a mature AI health app may involve.
- [Apple: Health and fitness apps](https://developer.apple.com/health-fitness/) — HealthKit as a permissioned repository for health and fitness data.
- [Apple: authorising access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) — fine-grained read/write authorisation requirements.
- [Apple: protecting user privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) — HealthKit privacy guidance.
- [Open Food Facts API](https://openfoodfacts.github.io/openfoodfacts-server/api/) — a possible later source for packaged-food ingredients and nutrition.
- [Lucassen et al., portion-size estimation study](https://pmc.ncbi.nlm.nih.gov/articles/PMC9291996/) — evidence that portion-size reporting is a meaningful source of dietary-assessment error.

## 21. One-sentence MVP definition

> An iPhone app that lets Dave use a configurable fasting goal, record food and drinks in seconds, rebuild missed history from backdated entries, read weight and movement from HealthKit, keep an active fast visible on the Lock Screen, and receive calm, honest insights without pretending estimates are measurements.
