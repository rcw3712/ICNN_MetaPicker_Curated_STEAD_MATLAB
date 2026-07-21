# Method Notes

## I-CNN Meta-Learner: Conceptual Continuity with Well-Log Vs Prediction

The I-CNN architecture used in this framework directly continues the methodological pattern established for well-log Vs prediction, where I-CNN served as a meta-learner combining multiple base-learner Vs estimates:

```
Vs_hat = g_theta(Vs_hat_1, Vs_hat_2, ..., Vs_hat_M)
```

In the phase-picking context, the analogous formulation replaces scalar Vs estimates with time-varying probability curves:

```
Y_hat(t) = g_theta(Y_hat_STA(t), Y_hat_AIC(t), Y_hat_CNN(t), Y_hat_TCN(t))
```

In both cases, g_theta (the I-CNN) NEVER sees the original raw input (well logs in the Vs case; waveform in the phase-picking case) as its primary signal. It sees only the stacked OUTPUTS of base learners. This is the single most important architectural invariant preserved across both applications, and is enforced in code by the strict separation between:

- `src/base_pickers/` — models that consume conditioned/enhanced waveform (X)
- `src/meta_learner/` — the only module producing a model literally named "I-CNN", which consumes exclusively the meta-feature tensor (Z_meta)

## Loss Weighting Rationale

S-wave is given a higher loss weight (wS=2.5) than P-wave (wP=1.5) because:

1. S-wave arrives into the coda of the P-wave, where scattered energy can mask or mimic genuine onset features.
2. S-wave amplitude is typically strongest on horizontal components, which (a) have lower SNR than vertical in many settings and (b) are the components most likely to be degraded or absent in the PiGraf field deployment this framework anticipates.
3. STA/LTA and AIC base pickers are demonstrably less reliable for S than for P, since both classical methods were originally designed primarily around P-wave onset detection.
4. Errors in S-wave timing have outsized downstream impact: Vp/Vs ratio estimation, focal mechanism determination, and hypocentral depth resolution are all disproportionately sensitive to S-wave pick quality.

The Noise class receives the lowest weight (wNoise=0.5) because noise samples vastly outnumber true P/S onset samples within any 60-second window (label imbalance), and over-weighting the dominant class would suppress the network's sensitivity to the rare, high-value P/S onset signal.

## Physics-Aware Picking: Design Rationale

The physics-aware post-processing stage is necessary because a purely data-driven probability curve can produce a high-confidence but physically impossible S-wave pick — for instance, a peak appearing in the P-wave coda, which shares spectral characteristics with genuine S onset. Constraining the S search window to `[tauP + minSPTimeSec, tauP + maxSPTimeSec]` (with `tauP` itself fixed first via global argmax of the P probability curve) guarantees `tauS > tauP` by construction and removes an entire class of physically implausible errors without requiring any additional model capacity.

## Enhanced Representation: Why It Helps Base Pickers, Not I-CNN

`buildEnhancedRepresentation.m` constructs envelope, short-term energy, and STA/LTA characteristic-function channels FROM the conditioned waveform, supplementing raw amplitude with classically-motivated onset-sensitive features. This enriched representation is fed to base pickers (Baseline CNN, TCN) — never to the I-CNN. The I-CNN's "enhancement," if any, comes from the diversity and quality of its base-picker inputs, not from any direct access to engineered waveform features. Ablation condition 8 (`run_ablation_study.m`) quantifies the marginal contribution of this enhanced representation by training base pickers and the downstream I-CNN with non-enhanced (raw conditioned, 3-channel) input instead.
