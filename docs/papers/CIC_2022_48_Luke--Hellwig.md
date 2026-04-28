<!-- page 0 -->

# Revising CAM16-UCS

Luke Hellwig, Mark D. Fairchild; Munsell Color Science Laboratory, Rochester Institute of Technology; Rochester, New York, USA

# Abstract

Recently-proposed modifications to the CIECAM16 color appearance model require an update to its corresponding uniform color space, CAM16-UCS, in order to ensure that the formulas continue to predict the available color difference data. Theoretical and statistical inconsistencies in the current CAM16-UCS formulas are also discussed and addressed by the proposed revisions. The STRESS metric is used to derive new formulas for CAM16-UCS and to evaluate the performance of these formulas in comparison to existing uniform color spaces or color difference formulas on a common color difference dataset.

# Background

Uniform color spaces seek to organize colors in a perceptually meaningful way that approximates the visual difference between colors. The goal of a such a color space is for pairs of colors that are separated by an equal Euclidean distance,  $\Delta \mathrm{E}$ , in the color space to have an equal visual difference,  $\Delta \mathrm{V}$ . Psychophysical data collected on visual color differences are used to evaluate the performance of uniform color spaces. These data consist of pairs of colors and their associated visual difference. STRESS is a common metric used to quantify the performance of a uniform color space on such data [1, 2, 3, 4, 5]:

$$
\begin{array}{l} S T R E S S = 1 0 0 \left(\frac {\sum \left(\Delta E _ {l} - F _ {l} \Delta V _ {l}\right) ^ {2}}{\sum F _ {l} ^ {2} \Delta V _ {l} ^ {2}}\right) ^ {\frac {1}{2}} \quad 1 \\ F _ {1} = \frac {\sum \Delta E _ {l} ^ {2}}{\sum \Delta E _ {l} \Delta V _ {l}} \quad 2 \\ \end{array}
$$

Lower values of STRESS indicate a better correlation between the  $\Delta \mathrm{E}$  values calculated from color pairs in a uniform color space and the  $\Delta \mathrm{V}$  of those color pairs as measured via psychophysics. The  $F_{l}$  term prevents overall scale differences between  $\Delta \mathrm{E}$  and  $\Delta \mathrm{V}$  from affecting the final value of STRESS.

Developing a uniform color space can be a challenge due to inherent conflicts between uniform scales of perceptual attributes and the visual color differences [5]. Differences in chroma are especially perceived as less visible by observers than differences in other dimensions such as lightness or hue [6]. One way to address these challenges is through specialized color difference equations, such as CIEDE2000 for CIELAB, which has larger tolerances in the chroma dimension [6]. CAM02-UCS and CAM16-UCS—built as extensions to CIE color appearance models—took a different approach, warping their scales of appearance attributes to generate a three-dimensional color space,  $J^{\prime}a^{\prime}b^{\prime}$ , where Euclidean distances estimate visual color differences [7, 8, 3]. In CAM16-UCS, these equations are given by [3]:

$$
\begin{array}{l} J ^ {\prime} = \frac {1 . 7 J}{1 + 0 . 0 0 7 J} \quad 3 \\ M ^ {\prime} = \frac {\ln (1 + 0 . 0 2 2 8 M)}{0 . 0 2 2 8} \quad 4 \\ a ^ {\prime} = M ^ {\prime} \cos h \quad 5 \\ b ^ {\prime} = M ^ {\prime} \sin h \quad 6 \\ \end{array}
$$

where  $J$  is lightness,  $M$  is colorfulness, and  $h$  is hue angle as predicted by CIECAM16 [9].

Interestingly, these formulas combine absolute (colorfulness) and relative (lightness) dimensions. This leads to the unusual

![img-0.jpeg](img-0.jpeg)
Figure 1. Side view of the sRGB gamut in CAM16-UCS  $J^{\prime}a^{\prime}b^{\prime}$  space at two values of white luminance  $(L_{W})$ . The magnitude of the  $a^\prime$  and  $b^{\prime}$  dimensions grow relative to the  $J^{\prime}$  dimension as the white luminance increases.

![img-1.jpeg](img-1.jpeg)

scenario where the magnitude of the  $a^\prime$  and  $b^{\prime}$  scales increases as the scene luminance increases, but the  $J^{\prime}$  scale remains constant (Figure 1). Thus, CAM16-UCS warps as the scene luminance changes and the overall magnitude of the scales shift. This decision to mix absolute and relative scales was made solely to slightly reduce STRESS [7]; no discussion was included as to whether this warping was a desirable property of a uniform color space.

Additionally, in the final form of CAM16-UCS, it is recommended to nonlinearly compress the color differences [3]:

$$
\Delta E = 1. 4 1 \left(\Delta E ^ {\prime}\right) ^ {0. 6 3} \tag {7}
$$

where  $\Delta \mathrm{E}^{\prime}$  is the true Euclidean distance between color pairs. This compression pushes values of  $\Delta \mathrm{E}$  towards one and is statistically unacceptable when the color differences to be fit are not randomly distributed. For instance, the RIT-DuPont dataset consists of color differences of exclusively  $\mathrm{dV} = 1.02$  [10]. The STRESS performance of a color difference metric, such as CAM16-UCS  $\Delta \mathrm{E}$ , can be artificially lowered (improved) by compressing the color differences towards this value as done in Equation 7 (Figure 2). In fact, one could create a color difference formula with no STRESS on the RIT-Dupont data by setting the exponent in Equation 7 infinitely close to zero. Clearly, this arbitrary ability to lower STRESS values should not be included in a color difference formula when STRESS is the principal metric used to evaluate such formulas.

Recently, substantial revisions were proposed to the equations for lightness, brightness, colorfulness, and chroma in CIECAM16 [11]. These revisions highlighted several areas (such as in the formula for brightness and the eccentricity function) in the history of the development of the model where values and dependencies had been simply transposed to the newer version of the model without refitting to the original psychophysical data. Additionally, CIECAM16 contained a major theoretical inconsistency in the formula for brightness. It is necessary to refit the CAM16-UCS formulas to account for the effects of these revisions. Additionally, updating the CAM16-UCS formulas provides the opportunity to address the theoretical shortcomings of the current CAM16-UCS formulas discussed above.




<!-- page 1 -->

# Methods

Perceptual attributes predicted by CIECAM16 are the inputs into the proposed uniform color spaces [3, 11]:

- Brightness, $Q$
- Lightness, $J$
- Colorfulness, $M$
- Chroma, $C$
- Hue angle, $h$

For definitions of these terms, see [12]. It should be noted that brightness and colorfulness increase as the overall luminance of the scene increases. (The recently proposed revisions to CIECAM16 ensure that these values scale with luminance at the same rate [11].) The magnitudes of lightness and chroma are invariant to the scene luminance.

Analysis of uniform color spaces and color difference formulas, described above, led us to propose the following form of equations to calculate $J' a' b'$:

$$
J' = \frac{(1 + x_1)J}{1 + 0.01x_1J} \tag{8}
$$

$$
C' = x_2 \frac{\ln(1 + x_2C)}{x_3} \tag{9}
$$

$$
a' = C' \cos h \tag{10}
$$

$$
b' = C' \sin h \tag{11}
$$

$x_1, x_2$, and $x_3$ are parameters of the $C'$ and $J'$ nonlinearities which can be optimized to minimize STRESS on visual color difference data as described below. Chroma, $C$, is used in place of colorfulness, $M$, from Equation 4 so that the magnitudes of all dimensions of $J'a'b'$ are invariant to scene luminance. Additionally, a chroma scaling term, $x_2$, is included so that $1\Delta V \approx 1\Delta E$.

There could also be applications where the user desires a uniform color space that is not relative but rather increases in size with increasing scene luminance. This can be easily achieved by using brightness, $Q$, and colorfulness, $M$, to derive an absolute uniform color space with dimensions $Q'p't'$. Similar compression functions can be used to calculate the $Q'$ and $M'$ dimensions as are used for the $J'$ and $C'$ dimensions. Additionally, unlike the $J'$ dimension, which is constrained to a 0 to 100 scale, the $Q'$ dimension can be rescaled so that to match magnitudes between $\Delta E$ and $\Delta V$. Such formulas have the form:

$$
Q' = x_4 \frac{(1 + x_5)Q}{1 + 0.01x_5J} \tag{12}
$$

$$
M' = x_6 \frac{\ln(1 + x_5M)}{x_7} \tag{13}
$$

$$
p' = M' \cos h \tag{14}
$$

$$
t' = M' \sin h \tag{15}
$$

where $x_4, x_5, x_6$, and $x_7$ are parameters which can be optimized to minimize STRESS on visual color difference data. Note that the $J$ term in the denominator of Equation 12 is not a typo but rather follows from the identity in the revised version of CIECAM16 [11]:

$$
\frac{Q}{Q_{whit} \alpha} = \frac{J}{100} \tag{16}
$$

The commonly-used Combined Visual Dataset (COMBVD) was employed for optimization [2, 6]. This dataset consists of four subsets from distinct color difference experiments: the RIT-Dupont dataset, consisting of 312 color pairs [10]; the Leeds dataset, consisting of 203 color pairs [13]; the Witt dataset, consisting of 418 color pairs [14], and the BFD dataset, consisting of 2028 color pairs [15]. For this analysis, however, the BFD data was reduced to only the 524 color pairs which were evaluated under Illuminant D65. The purpose of this paper was not to test the chromatic adaptation model of CAM16 and thus we were not interested in including color pairs under different illuminants and which had an outsize effect on the results. Additionally, two color pairs with extremely high chromas

![img-2.jpeg](img-2.jpeg)
Figure 2. STRESS of the CAM16-UCS color difference space on the RIT-Dupont dataset [10] as a function of the value of the exponent in Equation 7. Decreasing the value of the exponent decreases STRESS without changing the true performance of the uniform color space by compressing values towards one.

(significant outliers) were excluded from the Witt dataset to prevent them from becoming high-leverage points in the optimization of the chroma nonlinearity.

Based on the experimental conditions described for each dataset, the following parameters were used as inputs to CIECAM16. For the RIT-DuPont data, the adapting luminance was $127.3\,\mathrm{cd}/\mathrm{m}^2$ and the relative background luminance factor was 10.9 [2, 10]. For the Leeds data, the adapting luminance was $20\,\mathrm{cd}/\mathrm{m}^2$ and the relative background luminance factor was 18.4 [13]. For the Witt data, the adapting luminance was 86.7 and the relative background luminance factor was 24.9 [2, 14]. For the BFD data, the adapting luminance was $20\,\mathrm{cd}/\mathrm{m}^2$ and the relative background luminance factor was 20 [15].

Previous works using the COMBVD suggest weighting the STRESS formula so that each sub-dataset receives equal weight in the overall average [2]. The normal equation for STRESS (Equation 1) can be weighted like so:

$$
STRESS = 100 \left( \frac{\sum w_i (\Delta E_i - F_3 \Delta V_i)^2}{\sum w_i F_i^2 \Delta V_i^2} \right)^{\frac{3}{2}} \tag{17}
$$

where $w_i$ is the weighting factor for each color pair. To achieve equal weighting across datasets, the weighting factor for each color pair was set to the reciprocal of the number of color pairs in that dataset.

Optimization of the parameters $x_{1-7}$ to minimize stress was performed in MATLAB using a global search at the desired level of precision.

# Results

Optimization to minimize STRESS led to the following formulas for $J'a'b'$ coordinates for our modified CAM16-UCS:

$$
J' = \frac{1.7J}{1 + 0.007J} \tag{18}
$$

$$
C' = 2.4 \frac{\ln(1 + 0.098C)}{0.098} \tag{19}
$$

$$
a' = C' \cos h \tag{20}
$$

$$
b' = C' \sin h \tag{21}
$$

where $J, C$, and $h$ are calculated using the revised version of CIECAM16 [11]. Similarly, the optimized and modified CAM16-UCS-absolute is calculated:

$$
Q' = 0.86 \frac{1.7Q}{1 + 0.007J} \tag{22}
$$

$$
M' = 2.0 \frac{\ln(1 + 0.094M)}{0.094} \tag{23}
$$




<!-- page 2 -->

$$
p ^ {\prime} = M ^ {\prime} \cos h \tag {24}
$$

$$
t ^ {\prime} = M ^ {\prime} \sin h \tag {25}
$$

The STRESS of these equations on our version of the COMBVD dataset and its sub-datasets are shown in Table 1, along with the performance of common color difference formulas CIELAB  $\Delta E_{ab}$  [16], CIEDE2000 ( $\Delta E_{00}$ ) [6], CAM16-UCS [3], and DIN99 [17]. As noted above, color differences in CAM16-UCS were calculated without the compression of  $\Delta E$  values given the concern that this would artificially improve STRESS performance, especially on the RIT-DuPont dataset.

It is standard practice to use a two-sided  $F$ -test with an  $\alpha$  level of 0.05 to determine whether there is a significant difference between color difference formulas [2]. The square of the ratio between STRESS levels is compared to the critical value of  $F$  calculated using the degrees of freedom in the color difference datasets. (For the RIT-Dupont data, 155 is used at the number of degrees of freedom instead of 311 [2].) If the squared ratio is greater than the critical  $F$  value or less than its reciprocal, the color difference formulas are significantly different.

$F$ -tests showed that CIEDE2000 was superior to the proposed formulas for all datasets except Witt. There was no statistical difference between the traditional CAM16-UCS formulas and the proposed formulas. The proposed formulas were statistically superior to CIELAB  $\Delta E_{ab}$  for all datasets. Additionally, the proposed formulas outperformed DIN99 on the COMBVD, Witt, and Leeds datasets.

# Discussion

Recently proposed revisions to the equations for brightness,  $Q$ , colorfulness,  $M$ , and chroma,  $C$ , in CIECAM16 necessitate a refitting of the equations for the associated uniform color space. We have matched performance of the previous CAM16-UCS while substantially improving the theoretical grounding for the formulas. Specifically, the previous CAM16-UCS combined a relative scale, lightness,  $J$ , with an absolute scale, colorfulness,  $M$ . This led to the undesirable situation where  $a'$  and  $b'$  increased with increasing scene luminance while  $J'$  remained constant. The current proposal resolves this inconsistency by including two uniform color spaces, one that is relative ( $J'a'b'$ ) and one that is absolute ( $Q'p't'$ ), from which the user can choose. Additional statistical sleight-of-hand (Equation 7) used by the previous CAM16-UCS formulas has also been removed from the proposed formulas. These theoretical improvements have not compromised the ability of the formulas to predict color difference data (Table 1).

It is worthwhile to note that these uniform color spaces should only be used to calculate color differences. The characteristic nonlinearities in Equations 18, 19, 22, and 23 warp the uniform perceptual attribute scales of CIECAM16. The resulting uniform color spaces are thus uniform only in their prediction of color differences, not in their prediction of perceptual attributes.

# References

[1] P. A. García, R. Huertas, M. Melgosa and G. Cui, "Measurement of the relationship between perceived and computer color differences," J. Opt. Soc. Am. A, vol. 24, no. 7, pp. 1823-1829, 2007.
[2] M. Melgosa, R. Huertas and R. S. Berns, "Performance of recent advanced color-difference formulas using the standardized residual sum of squares index," J. Opt. Soc. Am. A, vol. 25, no. 7, pp. 1828-1834, 2008.

Table 1. Weighted STRESS performance (Equation 9) of the proposed uniform color spaces and other common color difference metrics on the modified COMBVD dataset. Underlined values are significantly better than the proposed formulas' values and italicized values are significantly worse.

|  Color Difference Metric | Color Difference Dataset  |   |   |   |   |
| --- | --- | --- | --- | --- | --- |
|   |  COM-BVD | RIT-DuPont | Witt | Leeds | BFD  |
|  Proposed J'a'b' | 28.2 | 22.9 | 32.3 | 23.8 | 28.8  |
|  Proposed Q'p't' | 28.6 | 22.5 | 31.7 | 24.5 | 28.5  |
|  CIEDE2000 | 24.2 | 19.5 | 30.1 | 19.2 | 23.4  |
|  CAM16-UCS | 28.1 | 20.6 | 30.9 | 25.4 | 28.5  |
|  CIELAB ΔEab | 45.3 | 33.4 | 51.9 | 40.1 | 44.8  |
|  DIN99 | 31.8 | 24.2 | 36.3 | 29.8 | 30.7  |

[3] C. Li, Z. Li, Z. Wang, Y. Xu, M. R. Luo, G. Cui, M. Melgosa, M. Brill and M. Pointer, "Comprehensive color solutions: CAM16, CAT16, and CAM16UCS," Color Research and Applications, vol. 42, pp. 703-718, 2017.
[4] M. Safdar, G. Cui, Y. J. Kim and M. R. Luo, "Perceptually uniform color space for image signals including high dynamic range and wide gamut," Optics Express, vol. 25, no. 13, pp. 15131-15151, 2017.
[5] L. M. Ragoo and I. Farup, "Optimising a Euclidean Colour Space Transform for Colour Order and Perceptual Uniformity," in Proc. IS&amp;T 29th Color and Imaging Conf., 2021.
[6] M. R. Luo, G. Cui and B. Rigg, "The Development of the CIE 2000 Colour-Difference Formula: CIEDE2000," Color Res. Appl., vol. 26, no. 5, pp. 340-350, 2001.
[7] C. Li, M. R. Luo and G. Cui, "Colour-Differences Evaluation Using Colour Appearance Models," in Proc. IS&amp;T/SID 11th Color Imaging Conference, 2003.
[8] M. R. Luo, G. Cui and C. Li, "Uniform Colour Spaces Based on CIECAM02 Colour Appearance Model," Color Res. Appl., vol. 31, no. 4, pp. 320-330, 2006.
[9] CIE 248:2022, "The CIE 2016 Colour Appearance Model for Colour Management Systems: CIECAM16," CIE, Vienna, 2022.
[10] R. S. Berns, D. H. Alman, L. Reniff, G. D. Snyder and M. R. Balonen-Rosen, "Visual Determination of Suprathreshold Color-Difference Tolerances Using Probit Analysis," Color Res. Appl., vol. 16, no. 5, pp. 297-316, 1991.
[11] L. Hellwig and M. D. Fairchild, "Brightness, lightness, colorfulness, and chroma in CIECAM02 and CAM16," Color Res. Appl., 2022.
[12] R. W. G. Hunt, "Colour terminology," Color Res. Appl., vol. 3, pp. 79-87, 1978.
[13] D.-H. Kim, The Influence of Parametric Effects on the Appearance of Small Colour Differences, University of Leeds, 1997.
[14] K. Witt, "Geometric Relations between Scales of Small Colour Differences," Color Res. Appl., vol. 24, no. 2, pp. 78-92, 1999.
[15] M. R. Luo and B. Rigg, "Chromaticity-discrimination ellipses for surface colors," Color Res. Appl., vol. 11, pp. 25-42, 1986.
[16] CIE 015:2018, "Colorimetry, 4th Edition," CIE, Vienna, 2018.
[17] G. Cui, M. R. Luo, B. Rigg, G. Roesler and K. Witt, "Uniform Colour Spaces Based on the DIN99 Colour-Difference Formula," Color Res. Appl., vol. 27, no. 4, pp. 282-290, 2002.
