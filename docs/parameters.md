# Processing Parameters

Default parameters used by the pipeline, and where to change them.

## Filter

```matlab
% Butterworth, order 2, bandpass 0.5–35 Hz, channels 1–64 (excludes Cz)
```

## ASR (clean_rawdata)

In `process_single_erp_subject.m`, function `clean_and_ica_continuous`:

```matlab
EEG = pop_clean_rawdata(EEG, ...
    'FlatlineCriterion', 'off', ...
    'ChannelCriterion', 'off', ...
    'LineNoiseCriterion', 'off', ...
    'Highpass', 'off', ...
    'BurstCriterion', 20, ...           % increase to be more permissive
    'WindowCriterion', 0.25, ...
    'BurstRejection', 'on', ...
    'Distance', 'Euclidian', ...
    'WindowCriterionTolerances', [-Inf 7]);
```

## ICA

```matlab
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'pca', 64, 'interrupt', 'off');
```

Extended Infomax, PCA reduction to 64 components.

## ICLabel — automatic rejection

Components are rejected when classified with ≥70% probability as Muscle, Eye, Heart, or
Channel Noise. In `clean_and_ica_continuous`:

```matlab
EEG = pop_icflag(EEG, [NaN NaN; 0.7 1; 0.7 1; 0.7 1; NaN NaN; 0.7 1; NaN NaN]);
%                              Muscle  Eye   Heart            ChanNoise
% Raise 0.7 → 0.8 to be more conservative; lower → 0.5 to be more aggressive.
```

Class order: Brain, Muscle, Eye, Heart, LineNoise, ChanNoise, Other.

## Epochs

In `process_single_erp_subject.m`:

```matlab
EEG = pop_epochbin(EEG, [-200.0 800.0], [-200 0]);
%                        start   end     baseline
```

Window −200 to 800 ms, baseline −200 to 0 ms.

## Region-of-interest channel (E65)

An extra channel E65 is added to the final ERP as the mean of channels 33–40:

```matlab
E65 = (ch33 + ch34 + ch35 + ch36 + ch37 + ch38 + ch39 + ch40) / 8;
```
