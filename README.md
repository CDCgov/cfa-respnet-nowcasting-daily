# Daily RESP-NET Nowcasts on a Weekly Reporting Cycle with Epinowcast

## Overview

The purpose of this project is to investigate whether we can use `epinowcast` to effectively perform daily nowcasts when we have a fixed weekly reporting cycle (e.g., all hospitalizations reported on Friday of each week). This is very much a work in progress.

### Progress Report: As Of November 2024

#### Modeling

See also: `capstone_deck.pdf`, the presentation slides used to present this project at the end of summer 2024.

Suppose we have daily hospital admission data collected on a fixed weekly reporting cycle. That is, the data are collected with daily resolution, and weekly, on a fixed day, a file containing all currently recorded admission dates is collected. All available information about the report date for each admission is associated with the day that the file containing all recorded admission dates is collected. Since this occurs once per week, report dates are only available with weekly resolution; i.e., admission dates will occur on all days of the week but report dates will only occur on e.g. Tuesdays.

We account for this using `epinowcast` in three ways:

1. A model with a fixed day-of-week (DOW) reporting effect.
2. A model with a fixed effect on whether or not a DOW is a report day, hardcoded such that the reporting hazard for non-reporting days is near 0.
3. A model which aggregates reporting probabilities and places them on the next possible reporting day.

##### DOW Reporting Effect

As described in [`epinowcast`'s documentation](https://package.epinowcast.org/articles/model.html) (a useful read before reading this report), reporting probabilities are modeled with a discrete-time hazard model, including both effects on the hazard by reference day and by report day. We include no reference day effects, and a DOW effect for the report day:

$$\text{logit}(h_{t,d}) = \gamma_{t,d} + \delta_0 + \beta_{f,\delta}X_\delta; \hspace{1em} t = 1,\dots T, d = 0,\dots D$$

with

$$\beta_{f,\delta} X_\delta = \beta_1\mathbb{1}\{t+d = 
\text{Monday}\} + \beta_2\mathbb{1}\{t+d = 
\text{Tuesday}\} + \dots + \beta_7\mathbb{1}\{t+d = 
\text{Sunday}\}$$

Coefficients corresponding to days that are not the reporting day will be inferred to be negative values large enough to make the reporting hazard approximately zero (seems like they generally are inferred to be around -4 or -5).

##### Hardcoded Hazard

This method modifies the above method to decrease unneccessary model complexity. Since we do not need to estimate which day is the reporting day (i.e. for RESP-NET all reports are on Tuesdays), we can hardcode the coefficients of non-reporting days to be a negative value large enough to make the reporting hazard approximately zero (we are using -20). We can also condense the covariates representing each day of week into an indicator of whether a day is a reporting day or not, as below:

$$\beta_{f,\delta} X_\delta = \beta_1 \mathbb{1}\{t+d \neq \text{Report Day}\}; \hspace{1em} \beta_1 = -20$$

##### Probability Aggregation

Instead of modifying the reporting hazard, we can work directly with the reporting probabilities before they go into the negative binomial likelihood. `epinowcast` does:

$$n_{t,d}\mid \lambda_t, p_{t,d} \sim \text{NegBin}(\lambda_t p_{t,d}, \phi); \hspace{1em} t = 1,\dots T, d = 0,\dots D$$

where $n_{t,d}$ is the number of notifications by reference day $t$ and delay $d$. Suppose we have a reference date $t$ where the next possible reporting day occurs on day $t + k$ (e.g., the reference day is Saturday and $k = 3$, so the next reporting day is Tuesday). We can do something like

$$p_{t,d}\big\vert_{m + k < d < 7m + k} = 0$$
$$p_{t,d}\big\vert_{d = 7m + k} = \sum_{i = 7m}^{i=7m + k} p_{t,i}$$

for nonnegative integer $m$ that indexes weeks.


#### Code

This repository contains work toward (1) and (2) above, where (1) is essentially completed and (2) is still in progress. Work toward (3) is tracked in `epinowcast` [issue 480](https://github.com/epinowcast/epinowcast/issues/480) because it requires modification of the package's code.

##### Data

Synthetic data were simulated from an SEIHRD model as in `R/Simulated Data Analysis/Functions/sim_hospital_admissions.R`, and one test simulation was used for all model runs on simulated data. The original simulated data is entirely on the daily scale: both hospital admission and report dates are available at daily resolution. Code used to process sim data are in `R/Simulated Data Analysis/process_sim_data.R`. Several datasets are created here: an `epinowcast`-prepped version of the original daily data (Daily/Daily data, daily admission and report dates), the daily data aggregated to the fixed reporting cycle data (Daily/Weekly data, daily admission and weekly report dates), and the daily data aggregated to weekly (Weekly/Weekly data) as CFA NNH has been doing with their RESP-NET data in the past.

The RESP-NET data that inspired this project are protected under a DUA. The `R/Real Data Analysis` directory contains code assuming the data are influenza data from 2022 and 2023. There is an additional challenge presented by the real flu data: though report dates are on Tuesdays, the last day that these reports come from is Saturday. This is taken care of in the RESP-NET nowcasting repository using `delay_0` and `delay_1` effects to re-weight the distribution over epiweeks. I tried to mimic this in the models in `R/Real Data Analysis/Run Models` by reweighting days.

##### Models

`R/Simulated Data Analysis/Run Models/model_definition.R` contains the partially-defined `epinowcast` model that most of the other models in `R/Simulated Data Analysis/Run Models`. In that directory there are four .R files:

- `run_model_daily_data.R` runs a model on the Daily/Daily sim data, producing a nowcast to be compared to the nowcasts by our experimental models on Daily/Weekly data.
- `run_weekly_agg_model.R` runs a model on the Weekly/Weekly sim data, to be compared to our experimental models' daily nowcasts from Daily/Weekly data aggregated to weekly nowcasts.
- `run_DOW_model.R` contains the code to run the DOW model (1)
- `run_hardcode_hzd_model.R` contains the code to run the hardcoded hazard model (2)

`R/Real Data Analysis` is structured similarly, though without `model_definition.R` because the one in `R/Simulated Data Analysis` is reused, and without `run_model_daily_data.R` because Daily/Daily data are not available for the real RESP-NET influenza data. Additionally, in the real data analysis, priors taken from a previous flu season are used for some parameters.

#### Updates as of Nov. 2024

Work on the DOW model (1) is largely completed. This model is very simple and requires only a "normal" run of `epinowcast` using a fixed DOW effect.

Work on the hardcoded hazard model (2) is still in progress. We have found that, using the `Stan` model defined in `Stan/hardcode_hzd_effect.stan` to implement (2) as well as the likelihood skipping for 0 reporting hazard days (as turned on by the use of `observation_indicator = .observed`), this model works on the sim data but for some reason performs worse than the DOW model. It takes longer to run and has slightly wider BCIs in the nowcast. This is counterintuitive and should be investigated, since the whole point of (2) as compared to (1) is that the computational complexity is reduced. There have been more problems with the use of this model real flu data, where model runs throw many exceptions and generally have resulted in models with near 100% divergent transitions. Often, reasonable nowcasts are still produced, but the computational difficulties are unexpected. These have not been thoroughly investigated, but by trial and error seem to be related to the use of likelihood skipping and to the use of the `delay_0` and `delay_1` effects mentioned above and necessary for application of the model to RESP-NET data. Getting rid of `observation_indicator = .observed` solves many of these computational problems and seems to give results similar to on the sim data, but this is counterintuitive. 

Work on the probability aggregation model (3) is also in progress and a little blocked. There is an open draft PR where the structure to run a basic model is in place but attempted model fits lead to errors that won't allow fitting of the model (see `epinowcast` [issue 480](https://github.com/epinowcast/epinowcast/issues/480)). This method necessitates the use of the likelihood skipping, so it is possible there is some kind of indexing mismatch with that method and the probability aggregation matrix we are using (see `epinowcast` [#482](https://github.com/epinowcast/epinowcast/pull/482)).

## Repo Structure

`R` contains the R code for this projects. Subdirectories `Real Data Analysis` and `Simulated Data Analysis` contain the code for the real and simulated data respectively.

`Stan` contains any Stan code necessary to run the models. Currently it only contains the `epinowcast` model from [here](https://github.com/seabbs/epinowcast-fixed-reporting-example/tree/main).

`manuscript` will ultimately contain the draft of a paper for this project.

## Project Admin

Jessalyn Sebastian, zlm6, CDC/IOD/ORR/CFA (CTR) - Summer Intern 2024

supervised by Katie Gostic PhD, uep6, Nowcasting and Natural History Lead, CDC/IOD/ORR/CFA

## General Disclaimer
This repository was created for use by CDC programs to collaborate on public health related projects in support of the [CDC mission](https://www.cdc.gov/about/organization/mission.htm).  GitHub is not hosted by the CDC, but is a third party website used by CDC and its partners to share information and collaborate on software. CDC use of GitHub does not imply an endorsement of any one particular service, product, or enterprise.

## Public Domain Standard Notice
This repository constitutes a work of the United States Government and is not
subject to domestic copyright protection under 17 USC § 105. This repository is in
the public domain within the United States, and copyright and related rights in
the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
All contributions to this repository will be released under the CC0 dedication. By
submitting a pull request you are agreeing to comply with this waiver of
copyright interest.

## License Standard Notice
This repository is licensed under ASL v2 or later.

This source code in this repository is free: you can redistribute it and/or modify it under
the terms of the Apache Software License version 2, or (at your option) any
later version.

This source code in this repository is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the Apache Software License for more details.

You should have received a copy of the Apache Software License along with this
program. If not, see http://www.apache.org/licenses/LICENSE-2.0.html

The source code forked from other open source projects will inherit its license.

## Privacy Standard Notice
This repository contains only non-sensitive, publicly available data and
information. All material and community participation is covered by the
[Disclaimer](https://github.com/CDCgov/template/blob/master/DISCLAIMER.md)
and [Code of Conduct](https://github.com/CDCgov/template/blob/master/code-of-conduct.md).
For more information about CDC's privacy policy, please visit [http://www.cdc.gov/other/privacy.html](https://www.cdc.gov/other/privacy.html).

## Contributing Standard Notice
Anyone is encouraged to contribute to the repository by [forking](https://help.github.com/articles/fork-a-repo)
and submitting a pull request. (If you are new to GitHub, you might start with a
[basic tutorial](https://help.github.com/articles/set-up-git).) By contributing
to this project, you grant a world-wide, royalty-free, perpetual, irrevocable,
non-exclusive, transferable license to all users under the terms of the
[Apache Software License v2](http://www.apache.org/licenses/LICENSE-2.0.html) or
later.

All comments, messages, pull requests, and other submissions received through
CDC including this GitHub page may be subject to applicable federal law, including but not limited to the Federal Records Act, and may be archived. Learn more at [http://www.cdc.gov/other/privacy.html](http://www.cdc.gov/other/privacy.html).

## Records Management Standard Notice
This repository is not a source of government records but is a copy to increase
collaboration and collaborative potential. All government records will be
published through the [CDC web site](http://www.cdc.gov).
