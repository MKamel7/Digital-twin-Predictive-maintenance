# Fault Diagnosis Demo — Narration Notes

Reference script for presenting `FaultDiagnosisApp.m`. Every number here is
measured against the full held-out test split (n=30 per severity per fault
type unless noted), not asserted from the single stitched demo file alone.

## The numbers to say (corrected)

- **Sev1 gear_wear recall: 70% (95% CI ≈ 52–84%, n=30).** Not bare "70%" —
  the interval is wide at this sample size and that's worth saying out loud.
- **Sev2/sev3 gear_wear: 0 errors in 30 trials each.** Not "100%" or
  "perfect" — 0/30 does not mean the true error rate is zero, only that no
  failures were observed in this sample (95% CI for the true error rate is
  roughly 0–11%, by the rule of three).
- **Demo file's misclassification margin sits at the ~3.8th percentile of
  the model's correct-prediction margins** (median correct margin 0.64 vs.
  this call's 0.186) — i.e. far below the model's typical confidence when
  right. Do **not** say "the model's most-decided mistake" — that's a rank
  within only 7 total errors in the test set, not a statistically
  meaningful claim.

## The mechanism question — checked, not confirmed (and now refuted)

I floated a hypothesis that early-stage gear_wear's friction signature
might resemble imbalance's constant-offset (DC) signature, which is why
the demo's sev1 file gets misattributed. **I checked this against actual
signal morphology and it does not hold up:**

- gear_wear sev1 mean/std ratio: 0.007 (essentially zero-mean)
- imbalance sev1 mean/std ratio: 2.044 (genuinely DC-dominated)
- gear_wear sev3 (correctly classified) mean/std ratio: 0.008 — same shape
  as sev1, just larger amplitude (std 0.306 vs 0.149)

Gear_wear sev1 is not morphing toward imbalance's shape — it's a
lower-amplitude version of the *same* shape as the correctly-classified
sev3 case. **Say: "I checked the obvious hypothesis against signal
morphology and it didn't hold up — there's no confirmed single-feature
explanation; this remains an open question."** Do not present the DC-offset
story as plausible or likely. It was tested and rejected.

## Full error breakdown at sev1 (why one demo file isn't the whole story)

Of 9 total sev1 gear_wear errors (out of 30 test files):
- 4/9 predicted "healthy" — fault genuinely undetected at this severity
- 5/9 predicted "imbalance" — fault detected but misattributed (the demo's case)

Both failure modes are real and roughly equally common. The demo shows one
of them, not the dominant or only one.

## The all-class score panel (Stage 1 + Stage 2, shown separately)

The GUI now shows live decision scores alongside each prediction, split
into two panels that mirror the model's actual two-stage architecture --
**deliberately not combined into one 4-class chart.**

- **Stage 1** (healthy vs. faulty): shown as a simple verdict + correct/
  incorrect indicator. No score bar -- it's a binary call.
- **Stage 2** (fault type only, gear_wear/bearing/imbalance): shown as a
  3-bar panel, softmax-normalized *within those 3 classes only*. Labeled
  "relative confidence," never "probability" -- SVM decision-function
  scores are not calibrated probabilities.

**Why not one combined 4-class panel:** an earlier version did combine
Stage 1's healthy-vs-faulty margin with Stage 2's among-faults scores
into a single softmax. This was wrong, not just inelegant: at the sev1
gear_wear miss, it made "healthy" outrank gear_wear in the chart, even
though Stage 1 had *already correctly called the file faulty*. That's an
artifact of forcing healthy into a competition Stage 2 never runs --
mixing two different decision functions on two different scales. The fix
was to stop combining them, not to retune the mix until the numbers
looked right (that would be choosing math to fit a story).

**The corrected payoff moment, at the sev1 gear_wear miss:**
Stage 1 correctly says FAULTY. Stage 2 (3-way): gear_wear=0.33,
bearing=0.28, **imbalance=0.40 (predicted, wrong)**. Gear_wear is the
genuine second-place bar, gap to the prediction ≈0.07 -- close. Say:
*"Stage 1 caught the fault; Stage 2 narrowly picked the wrong fault
type, with the true type as a close runner-up."* Do not say *why*
gear_wear and imbalance are close (the obvious morphology hypothesis was
checked and refuted, see above) -- only that they are.

## Scope reminders (say these, don't let them be assumed)

- This is a **file-level diagnostic tool** (one prediction per ~20s run),
  not a real-time monitor.
- No claim of RUL, remaining life, or prognosis anywhere — this is fault
  classification only.
- The "decision score" shown is an SVM margin, not a calibrated
  probability.
- The model never trained on these specific held-out files (family 9).
