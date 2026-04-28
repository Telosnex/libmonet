<!-- page 0 -->

# Brightness, lightness, colorfulness, and chroma in CIECAM02 and CAM16

Luke Hellwig, Mark D. Fairchild

## Abstract

In the CIECAM02 and CAM16 color appearance models, brightness is computed as a nonlinear function of lightness. This paper traces the history of that nonlinearity to its roots in the Hunt color appearance model. A new, more robust, linear relationship between lightness and brightness is proposed. This new formula also prompts the reevaluation of the CAM16 equations for chroma, colorfulness, and saturation. The new formulas for these perceptual attributes are tested on experimental data from the Munsell color order system and the LUTCHI color appearance dataset and are compared to the performance of the original CAM16 equations.

## Keywords

brightness, CAM16, color appearance model

## Background

Brightness is the perceptual attribute by which a light source or reflective surface appears to emit or reflect more or less light.1, 2, 3 Lightness is the brightness of a stimulus relative to the brightness of a white-appearing stimulus in a similarly illuminated area, also known as the reference white.1, 2, 3 While the brightness of stimuli has a general positive correlation with the amount of light they emit or reflect, there is no simple relationship between the amount of light emitted by a stimulus and its brightness and lightness. For instance, stimuli that with greater purity appear brighter than stimuli with less purity if they are of the same luminance (known as the Helmholtz--Kohlrausch Effect).4

The perceptual attribute colorfulness describes the absolute chromatic intensity of a visual stimulus. Chroma and saturation are relative measures of colorfulness; chroma is defined as the colorfulness of a stimulus relative to the brightness of similarly illuminated white and saturation is defined as the colorfulness of a stimulus relative to its own brightness.1, 2, 3

Much work has been done over past decades to model brightness, lightness, colorfulness, and chroma. This paper analyzes the lineage and current state of the brightness, lightness, colorfulness, and chroma functions in two prominent color appearance models: CIECAM02 and CAM16. For more information about these and other color appearance models and relevant color appearance phenomena, see.1 It is worth noting that CIECAM02 and CAM16 are identical after the chromatic adaptation stage. Thus, they are treated interchangeably in this article.

In general, widely used color appearance models follow a similar flow. First, given the Commission internationale de l'eclairage (CIE) XYZ tristimulus specification of a stimulus, a model will predict the responses of the three types of cone cells in our retina which form the basis of color vision. (Note that these cone spectral responses are chosen for model performance and are not meant to represent biological cone spectral sensitivities.) The chromatic and luminance adaptation of the cone cells will be modeled using information about the viewing conditions. The adaptation of the cone cells represents the first nonlinearity between signal and light in these models. The adapted and compressed cone signals will then be weighted and summed to derive an


<!-- page 1 -->

achromatic signal, A, and opponent chromatic signals, a and b. For instance, in CIECAM02 and CAM16, this relationship is represented by $$A = \left\lbrack {2R_{a}^{\prime} + G_{a}^{\prime} + 0.05B_{a}^{\prime} - 0.305} \right\rbrack N_{\text{bb}}$$ $$a = R_{a}^{\prime} - 12G_{a}^{\prime}/11 + B_{a}^{\prime}/11$$ $$b = \frac{1}{9}\left({R_{a}^{\prime} + G_{a}^{\prime} - 2B_{a}^{\prime}} \right)$$

where R_{a}′, G_{a}′, and B_{a}′ are the adapted signals of the three cone types and N_{bb} is a background dependency.5 Lightness, J, and brightness, Q, are then derived from the achromatic signal. The chromatic signals are used to calculate chroma, C, saturation, s or t, and colorfulness, M. The equations used to calculate J, Q, C, and M are the subject of this paper.

## BRIGHTNESS AND LIGHTNESS

The equations for brightness, Q, and lightness, J, in CIECAM02 and CAM16 originate mostly from the Hunt appearance model, which underwent a number of iterations from the early 1980s to the mid‐1990s.6, 7, 8, 9, 10 Of particular interest is the revision to the equations for J and Q that Hunt made in the early 1990s.9 Prior to this revision, the original model had linear relationships between A, Q, and J6: $$Q = (A + M)N_{1} - N_{2}$$

and $$J = 100Q/Q_{w}$$

where M is the colorfulness of the stimuli, N_{1} and N_{2} are factors that Hunt used to account for luminance dependencies related to work by Stevens and Bartleson,11 and Q_{w} is the brightness of white in the scene. Note that the use of M in the equation for Q was an attempt by Hunt to account for the Helmholtz‐Kohlrausch Effect. This dependency of Q on M was lost in the transition from the Hunt model to CIECAM97s, CIECAM02's precursor, and its presence or absence in the equations discussed in this paper do not detract from the overall discussion.

In 1991, Hunt revised the equations for Q and J, introducing nonlinearities in each9: $$Q = \left\lbrack {7\left({A + M/100} \right)} \right\rbrack^{0.6}N_{1} - N_{2}$$

and $$J = 100\left({Q/Q_{\text{W}}} \right)^{z}$$

where $$z = 1 + \left({Y_{\text{B}}/{Y_{\text{W}}}} \right)^{1/2}$$

with Y_{B} and Y_{W} being the luminance factors of the background and white point, respectively. (Note: M/100 in Equation (6) is equal to M in Equation (4). Hunt changed the scaling of that variable between the two papers.)

The first substantial change in the model is inclusion of a 0.6 power in converting from A to Q. Hunt offers no explicit justification for this modification, merely stating: “The different achromatic signal A in the revised model, leads to the following expression for Q,” and then, “These formulae lead to values of Q that, at normal photopic levels, are very similar in the original and revised models.”9 However, careful examination of the methods for calculating A in each model reveals no differences that would necessitate the inclusion of the 0.6 power nonlinearity. The only apparent nonlinearity prior to this stage in either model is the tone compression function for the cone signals, which is identical in both models8, 9: $$f(I) = 40\left\lbrack {I^{0.73}/\left({I^{0.73} + 2} \right)} \right\rbrack$$

There is neither a clear cause for the inclusion of the 0.6 power nor any evidence of equality in Q values between the two models, contrary to the claims made by Hunt in justification for the equations.

Hunt also introduces a pair of background dependencies in his 1991 model9: a multiplicative factor in the formula for A (N_{bb} in Equation (1)) and a nonlinearity in the formula for deriving J from Q (z in Equation (7)). The N_{bb} term predicts that the achromatic signal, A, of a given stimulus will increase as the luminance factor of the background decreases. This predicted increase in A is carried through to the brightness of the stimulus, Q, and the brightness of the reference white, Q_{W}, via Equation (6). However, the contribution of N_{bb} is canceled out in the formula for J, Equation (7), when Q is divided by Q_{W}. Thus Hunt needed the z term to also increase the lightness of a stimulus as the background luminance factor, Y_{B}, decreases. Since Q/Q_{W} varies from 0 to 1 in Equation (7), decreasing z as Y_{B} decreases (Equation (8)) causes J to increase as Hunt desired.

The addition of the z exponent to Equation (7) provides a possible explanation for Hunt's addition of the 0.6 exponent to Equation (8). Hunt may have wanted to


<!-- page 2 -->

maintain the similarity between his previous model (Equations (4) and (5)) and the equation for brightness published by Bartleson,11 which Hunt claims is equivalent to his model (see appendix II of8). By including the 0.6 power in the conversion from A to Q, Hunt partially undoes the nonlinearity introduced in going from Q to J, making the overall conversion from A to J more similar to his original, linear relationships (Equations (4) and (5)) between these values. However, if this was Hunt's motivation, there was no clear justification for separating the two nonlinearities between two steps of the model (Equations (6) and (7)) instead of just applying them both in a single step, such as in the formula for J (Equation 7).

Hunt's decision to separate these two nonlinearities in his model has been propagated through the CIE‐approved color appearance models for the past 30 years. The Hunt model was drawn heavily upon and formed the basis for the Q and J equations when CIECAM97s was developed to unify the various competing color appearance models of the 1980s and 1990s.1 The two nonlinearities that are used in CIECAM97s to calculate J from A seem to be equivalent in function to Hunt's nonlinearities. Since CIECAM97s and the subsequent CIE color appearance models calculate J before Q (as opposed to Q before J in the Hunt model), both nonlinearities from Equations 6 and 7 are included in a single step:*J* = 100(*A*/*A*_{*W*})^{*c**z*}.In CIECAM97s, c is set to either 0.525, 0.59, or 0.69 for dark, dim, or average surrounds, respectively. Thus, c carries similar values to the 0.6 power used in the Hunt model (Equation (6)). Like in the Hunt model, z depends on the relative background luminance:*z* = 1 + *F*_{*L**L*}(*Y*_{*B*}/*Y*_{*W*})^{1/2}where F_{LL} is one for stimuli smaller than 4° of visual angle and zero otherwise. Then, deriving the calculation for Q from J from the Hunt Model, CIECAM97s essentially inverts Equation (7), introducing a third nonlinearity to undo the z power that the Hunt model predicted to solely apply to J:*Q* = (1.24/*c*)(*J*/100)^{0.67}(*A*_{*W*}+3)^{0.9}.The exponent in Equation (12), 0.67, is approximately the multiplicative inverse of z, 0.69, for a typical, mid‐gray background (Y_{B} = 20), which seems to confirm our interpretation that the 0.67 exponent is merely an artifact of how the formula for Q was adapted from the Hunt model and was not based on visual data. Importantly, the derivation of these CIECAM97s formulas did not account for the intent behind the placement of these nonlinearities in the Hunt model. As discussed above, the z background dependency was most likely introduced by Hunt into Equation (7) to compensate for the fact that J has not been affected by Hunt's other background dependency, N_{bb}, which affected Q. Thus z was required by Hunt to only apply to J. With the order of J and Q calculation reversed in CIECAM97s, z now affects both J and Q, so Hunt's requirement of the placement of z in Equation (7) is no longer relevant for CIECAM97s. The focus in the derivation process of CIECAM97s on the mathematics of the Hunt model led to a literal inversion of Equation (7) to create Equation (12) without considering that the nonlinearity in Equation (7) is only present because Q is calculated before J in the Hunt model.

The basic structure of these equations introduced in CIECAM97s—two nonlinearities from A to J and then a single nonlinearity from J to Q—has been carried forward into the model's successors, CIECAM02 and CAM16.1, 5 In both models, the formula for J matches Equation 10, although z is now slightly different:*z* = 1.48 + √*Y*_{*B*}/*Y*_{*W*}.The nonlinearity to calculate Q from J was simplified from a 0.67 power to a square root:*Q* = (4/*c*)√*J*/100(*A*_{*W*}+4)*F*_{*L*}^{0.25}.There is little theoretical justification for the nonlinear relationship between lightness and brightness. No other color appearance model that predicts both brightness and lightness includes a nonlinear relationship between the two. A simple thought experiment highlights the nonlinearity's problematic nature. Imagine being shown an array of gray cards and being asked to choose the card that is halfway between black and white in terms of lightness. Then, you are asked to choose the card that is halfway between black and white in terms of brightness. The two cards chosen would be the same (allowing for some small degree of psychophysical uncertainty). But CAM16 claims that the same card will never be chosen, no matter the viewing conditions: the card that CAM16 predicts to have middle lightness will always be lighter than the card that CAM16 predicts to be middle brightness.

Practically, the nonlinear relationship between lightness and brightness seems to lead to incorrect predictions of brightness. Figure 1 shows neutral scales from black to white in equal steps of either lightness or brightness, as


<!-- page 3 -->

Equal steps in CAM16 lightness from black to white

![img-0.jpeg](img-0.jpeg)
FIGURE 1 Approximate lightness and brightness scales calculated using the CAM16 formulas for  $J$  and  $Q$  (Equations (10) and (14)). The viewing conditions were assumed to be "average" with a reference white of  $400\mathrm{cd} / \mathrm{m}^2$  and a white background

predicted by CAM16. (The viewing conditions were assumed to be "average" with a reference white of  $400\mathrm{cd} / \mathrm{m}^2$  and a white background.) Figure 1 is a direct visual description of the nonlinearities of the lightness and brightness of CAM16 and it is clear from these figures that the brightness nonlinearity is faulty.

Fortunately, this error can be simply remedied by removing the nonlinearity in the equation for  $Q$ . Additional improvements to the performance of the brightness equation can be made by removing extraneous luminance and background dependencies in the equations for  $A$  and  $Q$  that duplicate dependencies which already exist in the formulas. The equations for the achromatic signal, lightness and brightness become:

$$
A = 2 R _ {a} ^ {\prime} + G _ {a} ^ {\prime} + 0. 0 5 B _ {a} ^ {\prime} - 0. 3 0 5 \tag {15}
$$

$$
J = 1 0 0 \left(A / A _ {\mathrm {W}}\right) ^ {c z} \tag {16}
$$

$$
Q = (2 / c) (J / 1 0 0) \left(A _ {\mathrm {W}}\right) \tag {17}
$$

Equation (17) restores the linear relationship between  $J$  and  $Q$ . The removal of  $N_{\mathrm{bb}}$  from Equation (15) compared to Equation (1) achieves two ends. First of all, this background-dependent term is redundant, given that  $Q$  depends on  $J$  and  $J$  depends on the relative background luminance factor via  $z$  in Equation (16). Hunt originally introduced  $N_{bb}$  in his 1991 model (Equations (6)-(8)), where the  $z$  background dependency only applied to  $J$ , and thus the  $N_{\mathrm{bb}}$  term was necessary to give brightness a background dependency. Now that  $z$  effects both  $J$  and  $Q$ , there is no need for  $N_{bb}$ . In fact, such a factor is undesirable since it only effects  $Q$  and not  $J$ . Additionally,  $N_{\mathrm{bb}}$  behaves impossibly, approaching infinity as the relative background luminance approaches zero and producing clearly unrealistic predictions below a background luminance factor of  $6\%$ , which is the darkest background used by Hunt in deriving the term. Removing this explicit

background dependency is consistent with the LUTCHI data, where all brightness scaling was done against the same gray background. $^{12}$  Thus, removing the  $N_{bb}$  factor returns the formulas to being a representation of the LUTCHI data, where brightness has the same background dependency as lightness.

The  $F_{L}$  factor in the CAM16 formula for  $Q$  (Equation (14)) was introduced to CIECAM02 via a paper that explored the use of a power function instead of a hyperbolic function to represent the cone dynamic response function in CIECAM97s. The inclusion of this  $F_{\mathrm{L}}$  factor was not justified by specific data nor mentioned in the text. Nonetheless, while this paper's main proposal for a power function to serve as the cone response function was not adopted by CIECAM02, CIECAM02 did include this  $F_{\mathrm{L}}$  factor in the formula for  $Q$ . Its inclusion was not mentioned in the papers that introduced CIECAM02. It is possible that the factor was introduced to help the  $Q$  formula mirror the adapting luminance dependency of the formula for colorfulness,  $M$ , so that saturation, which is colorfulness divided by brightness, would remain constant across adapting luminance. However, including the  $F_{\mathrm{L}}$  factor actually achieves the exact opposite, making the adapting luminance dependencies of  $Q$  and  $M$  less similar, because  $Q$  contains an additional adapting luminance dependency in the  $A_{\mathrm{W}}$  term. So no theoretical or data-based justification for the  $F_{\mathrm{L}}$  factor in the formula for  $Q$  can be found. Additionally, removing the  $F_{\mathrm{L}}$  factor, as proposed here, significantly improves the performance of the proposed  $Q$  formula (Equation (17)) on the LUTCHI data (see below). Thus, given the performance benefits and the lack of any data-based or theoretical downside, the  $F_{\mathrm{L}}$  factor must be removed.

The inverse  $c$  factor, which predicts the overall magnitude of the brightness scale to increase as the surround darkens, is also a candidate for removal, given that the LUTCHI data did not directly test the relationship between the surround conditions and the overall magnitude of the brightness scale. However, that factor has been left in the formula pending further data on the effect of surround conditions on brightness.

The overall magnitude of the  $Q$  scale has been reduced by half. Originally,  $Q$  was scaled to match the arbitrary magnitude of the brightness scale used in the LUTCHI experiment.[12] By rescaling the  $Q$  scale, one unit of  $Q$  is closer to one unit of reference visual difference as represented by the COMBVD dataset used to derive the CIECAM02-UCS and CAM16-UCS uniform color spaces.[5]  $Q$  is now roughly the same magnitude as  $J$  when  $L_{\mathrm{white}} = 100~\mathrm{cd / m^2}$  since that is the luminance of the reference white for the COMBVD data.[16]

The performance of the new formula for brightness (Equation (17)) was compared to the brightness formula


<!-- page 4 -->

from CAM16 (Equation (14)) using the LUTCHI color appearance dataset. $^{12}$  These data consist of 36 stimuli whose brightness was scaled at six luminance levels ranging from  $L_{\mathrm{white}} = 0.4 \, \mathrm{cd/m}^2$  to  $L_{\mathrm{white}} = 842 \, \mathrm{cd/m}^2$  ( $\sim 11$  stops). Hunt relied heavily on these data in his introduction of nonlinearities to the equations for brightness and lightness, $^9$  thus they serve as relevant reference data for the descendants of the Hunt model, including CAM16. The proposed, linear formula for brightness, Equation (17), outperforms the CAM16 formula for brightness, Equation (14), on these data (Figure 2). These results lend experimental support to the theoretical justification for the proposed modifications.

# 3 | CHROMA AND COLORFULNESS

In CIECAM02 and CAM16, the first step in calculating terms of chromatic intensity is to calculate  $t$ , which is similar to saturation, from the opponent chromatic signals  $a$  and  $b$ :

$$
t = \frac {\left(5 0 0 0 0 / 1 3\right) N _ {\mathrm {c}} N _ {\mathrm {c b}} e _ {\mathrm {t}} \sqrt {a ^ {2} + b ^ {2}}}{R _ {a} ^ {\prime} + G _ {a} ^ {\prime} + (2 1 / 2 0) B _ {a} ^ {\prime}} \tag {18}
$$

In this formula,  $N_{\mathrm{c}}$  is either 1, 0.9, or 0.8 for average, dim, and dark surround conditions, respectively.  $R_{a}^{\prime}, G_{a}^{\prime}$ , and  $B_{a}^{\prime}$  are the adapted cone signals. The hue-dependent eccentricity factor  $e_{\mathrm{t}}$  is included to account for scaling differences between  $a$  and  $b$ .  $N_{\mathrm{cb}}$  is a background dependency. These terms will be discussed below.  $t$  is then used to calculate chroma,  $C$ , colorfulness,  $M$ , and saturation,  $s$ :

$$
C = t ^ {0. 9} \sqrt {J / 1 0 0} \left(1. 6 4 - 0. 2 9 ^ {Y _ {\mathrm {B}} / Y _ {\mathrm {W}}}\right) \tag {19}
$$

$$
M = C \cdot F _ {\mathrm {L}} ^ {0. 2 5} \tag {20}
$$

$$
s = 1 0 0 \cdot \sqrt {M / Q} \tag {21}
$$

CAM16's formula for chroma has threefold dependence on the background luminance factor,  $Y_{\mathrm{B}}$ : via the explicit term in Equation (19), via  $J$  (see the  $z$  term in Equations (10) and (16)), and via the  $N_{\mathrm{cb}}$  factor in the formula for  $t$  (Equation (18)). Colorfulness, as derived from chroma in CAM16, is subject to these three background luminance factor dependencies, plus the additional dependence  $F_{\mathrm{L}}$  on the background luminance factor. The threefold dependence of chroma on background was an intentional choice by Hunt in his 1994 model.[17] The desired effect was for a darker background to increase the chroma and colorfulness of medium-dark and dark colors and to decrease the chroma and colorfulness of lighter colors.[17] However, the current background dependencies only achieve this effect when the background luminance factor is greater than 20 (Figure 3). Below  $Y_{\mathrm{B}} = 20$ , the chroma of all colors increases, approaching infinity as  $Y_{B}$  approaches zero. This implausible behavior is due to  $N_{\mathrm{cb}}$ , which approaches infinity as  $Y_{\mathrm{B}}$  approaches zero:

$$
N _ {\mathrm {c b}} = 0. 7 2 5 \left(Y _ {\mathrm {W}} / Y _ {\mathrm {B}}\right) ^ {0. 2} \tag {22}
$$

Thus, the current background dependencies in the CAM16 formula for chroma do not follow Hunt's desired

![img-1.jpeg](img-1.jpeg)
FIGURE 2 LUTCHI brightness scaling data $^{12}$  as predicted by (A)  $Q$  in CAM16 (Equation (17)) and (B) by the proposed formula for brightness (Equation (20)). The coefficient of determination  $\langle R^2\rangle$  between the two variables is 0.86 for CAM16 and 0.95 for the proposed formula. Colors are approximate. Note that the absolute magnitude of the scales need not match the magnitude of the observed data

![img-2.jpeg](img-2.jpeg)


<!-- page 5 -->

![img-3.jpeg](img-3.jpeg)
FIGURE 3 Dependence of the chroma of stimuli in CAM16 on the background luminance factor relative to their chroma with a mid-gray background, for stimuli with lightness ranging from 10 to 90 in steps of 10. All lines approach infinity as the background luminance factor approaches zero

behavior and produce highly implausible values for realistic background levels achieved by modern displays.

Furthermore, careful analysis of the LUTCHI data does not support Hunt's claims about the background dependency of chroma and colorfulness. Key sessions in the LUTCHI experiment involved scaling colorfulness (and other color appearance attributes) against gray and white backgrounds. In line with Hunt's observations, dark colors were scaled with lower colorfulness against the white background than against the gray background. However, the actual colorimetry of the stimuli changed between the background conditions; the stimuli against the white background for which Hunt observed lower colorfulness ratings were, in fact, physically dimmer. Thus, no background dependency is necessary to predict colorfulness ratings across different background luminance factors from the LUTCHI experiment.

The lack of background effects on colorfulness in the LUTCHI experiment seems contradictory to the high performance of CAM16—background dependency included—on the LUTCHI colorfulness data. This discrepancy can be explained via the relationship between adapting luminance and background luminance factor. If the adapting luminance is not specified by the user, CAM16 recommends using the background luminance factor to calculate the adapting luminance from the white point luminance. Unfortunately, this causes calculated brightness and colorfulness—color appearance attributes that scale with adapting luminance—to decrease as the background luminance decreases even if the stimulus is held constant. So,

the additional background dependencies in the brightness and colorfulness formulas (Figure 3) merely offset this unintentional decrease, holding the color appearance attributes constant for constant stimuli.

This combination of deriving adapting luminance from background luminance factor and then undoing the effects of adapting luminance through the three background dependencies in the equations for chroma and colorfulness is confusing for the user, overly complicated, and misrepresents what the color appearance model is doing. A simpler and clearer formula for colorfulness can be derived from the numerator of the formula for  $t$  (Equation (18)):

$$
M = 4 7 N _ {\mathrm {c}} e _ {\mathrm {t}} \sqrt {a ^ {2} + b ^ {2}} \tag {23}
$$

Chroma is derived by colorfulness by dividing by the achromatic white signal to make chroma invariant to scene luminance:

$$
C = 3 5 \cdot \frac {M}{A _ {\mathrm {w}}} \tag {24}
$$

Saturation,  $s$ , can be calculated from colorfulness and brightness using a linearized version of the CAM16 formula for  $s$ :

$$
s = 1 0 0 \cdot \frac {M}{Q} \tag {25}
$$

In addition to removing the myriad background dependencies, these formulas make the theoretical improvement of linearizing the formulas. The many nonlinearities in the original formulas (Equations (19)-(21)) appear to have been introduced to improve the performance of the model on the LUTCHI data without theoretical justification. As will be seen below, linearizing the formulas improves the linearity of their chroma and colorfulness predictions. It should also be noted that removing the background dependencies (specifically, the  $\sqrt{J / 100}$  term in Equation (19)) requires this restructuring of the formulas for chroma and colorfulness. An additional reason for removing the explicit  $J$  factor from the formulas for  $M$  and  $C$  is that the factor merely and poorly canceled out the denominator of the formula for  $t$  (Equation 18), leading to incorrect predictions of chroma and colorfulness for stimuli with large values of blue cone signal,  $B_{a}^{\prime}$ .

For a given reflective object, chroma—as predicted by both CAM16 and the proposed model—is constant as the scene luminance changes. In both models, the colorfulness of a reflective object increases with increasing scene


<!-- page 6 -->

![img-4.jpeg](img-4.jpeg)
FIGURE 4 Effect of the overall luminance level on (A) colorfulness,  $M$ , and (B) brightness,  $Q$ , for CAM16 and the proposed formulas. Colors from the Munsell color order system were used to measure the relationship between colorfulness and luminance. The proposed formulas for  $Q$  and  $M$  follow similar trends with regard to luminance, as they both scale proportional to  $A_W$ . All values were normalized relative to a white luminance of  $1000\mathrm{cd} / \mathrm{m}^2$

![img-5.jpeg](img-5.jpeg)

luminance (Figure 4). In CAM16, this luminance dependency is proportional to  $F_{\mathrm{L}}^{0.25}$ . In the proposed model, the colorfulness of a given object has the same relationship with scene luminance as the achromatic white signal,  $A_{W}$ , given that  $a$ ,  $b$ , and  $A_{W}$  are all proportional to the adapted cone signals  $R_{a}^{\prime}$ ,  $G_{a}^{\prime}$ , and  $B_{a}^{\prime}$ .

The overall magnitude of the  $M$  and  $C$  scales has been modified, as well. In CIECAM02 and CAM16,  $M$  was scaled to match the arbitrary magnitude of the colorfulness scale from the LUTCHI experiments. $^{12}$  The proposed  $M$  formula, Equation (23), is scaled by 0.75 compared to the formula from CAM16. This was done to better match the scale of unit reference visual differences from the COMBVD color difference dataset. $^{16}$  Given that the proposed  $Q$  scale was scaled by 0.5 relative to its CAM16 formula, the  $M$  dimension is now  $50\%$  larger relative to the  $Q$  dimension in the proposed formulas. This was done to minimize STRESS on the COMBVD data. $^{18}$

The formula for  $C$  was scaled by 0.6 relative to its magnitude in CAM16. This scaling provides a more accurate magnitude for chroma relative to the  $J$  dimension in the proposed formulas, improving the uniformity of the scales and minimizing STRESS as measured by the COMBVD color difference dataset.[16,18]

One further proposed change is to the eccentricity function,  $e_{\mathrm{t}}$ . The opponent chromatic signals,  $a$  and  $b$  (Equations (2) and (3)), are not guaranteed to be properly scaled in magnitude relative to each other. Thus, CIECAM02 and CAM16 use an eccentricity factor,  $e_{\mathrm{t}}$ , to account for differences in the scaling of  $a$  and  $b$  when

calculating chroma and colorfulness. The formula used in CAM16 can be traced back to values derived by Hunt for his 1982 color appearance model. $^{6}$  Hunt derived his eccentricity factors by drawing loci of constant saturation from the NCS color order system on a  $u'v'$  chromaticity diagram. Specifically, he calculated the relative radii of these loci at the four unique hues from the NCS system. While  $u'v'$  coordinates have no concrete relationship with  $a$  and  $b$ , Hunt reasoned that the limits of the relative radii of the loci as the saturation approached zero would be invariant of the color coordinates used. These assumptions and calculations led to eccentricity values of 1.45 for NCS unique blue, 0.65 for unique red, 0.5 for unique yellow, with the eccentricity of unique green set to unity. $^{6}$

In the 1985 revision of his color appearance model, Hunt introduced cross-talk between his  $R$ ,  $G$ , and  $B$  cone signal values. This cross-talk calculation included an additional square-root applied to the cone responses. Hunt also took the square-root of the eccentricity values from his 1982 paper since he was now working in square-root response space, leading to eccentricity values of 1.2 for blue, 0.8 for red, 0.7 for yellow, with the eccentricity of green set to unity. These values were used to derive the eccentricity function,  $e_{\mathrm{t}}$ , found in CAM16 (Figure 5):

$$
e _ {\mathrm {t}} = \frac {1}{4} \cdot \left[ \cos \left(\frac {h \cdot \pi}{1 8 0} + 2\right) + 3. 8 \right] \tag {26}
$$

The hue angle,  $h$ , is defined as:


<!-- page 7 -->

![img-6.jpeg](img-6.jpeg)
FIGURE 5 Average eccentricity of Munsell colors as a function of CAM16 hue angle in comparison to the CAM16  $e_{\mathrm{t}}$  function (Equation (26)) and the proposed formula, which was fit to the Munsell data (Equation (28)). Colors are approximate

$$
h = \tan^ {- 1} \left(\frac {b}{a}\right) \tag {27}
$$

The formula for eccentricity gives values of  $\sim 1.198$  for blue, 0.774 for red, 0.723 for yellow, and 0.988 for green, closely matching the above values from Hunt's 1985 paper. The hue angles used for the NCS unique hues were also transcribed from Hunt's 1985 model as opposed to measuring the hue angle of the NCS unique hues in the CAM16  $a - b$  dimensions.

This eccentricity function is problematic for a number of reasons. First of all, there are several potential flaws in the method used by Hunt to derive the initial eccentricity values in 1982. Chromaticness in the NCS system is relative to the maximum chromatic intensity of each individual hue,[19] thus NCS chromaticness and saturation are not meant to be compared in absolute terms across hues as Hunt did by drawing loci of constant saturation. Additionally, there is no self-apparent justification for his assumption that the limit of the loci of constant saturation as saturation approaches zero is invariant across different color spaces. Secondly, there is no justification for the use of the same numeric values for Hunt's 1985 model and CAM16, given that they have different RGB cone spaces and different tone compression functions. While CAM16 has remained true to the values derived by Hunt, it has lost the connection to Hunt's original intent in proposing these values. Finally, CAM16 assumes that the proper eccentricity values follow a sinusoidal shape between the target unique hue values. However, no evidence is provided to support such an assumption.

By returning to Hunt's original intent—the scaling of stimuli of each hue by their relative chromatic strength—we can derive an eccentricity function that resolves the problems described above. Unlike the NCS system, which normalizes each hue by its chromatic strength, the Munsell system has a measure of chromatic intensity, chroma, whose magnitude can be compared across hues.[19] To determine the proper eccentricity function of hue, the Munsell chroma of each Munsell color is divided by  $\sqrt{a^2 + b^2}$ , which is proportional to the chroma of the color following our proposed formula (Equations 23 and 24). The mean dividend for each Munsell hue is shown in Figure 5. A new formula for  $e_{\mathrm{t}}$  was fit to these data:

$$
\begin{array}{l} e _ {\mathrm {t}} = - 0. 0 5 8 2 \cos (h) - 0. 0 2 5 8 \cos (2 h) - 0. 1 3 4 7 \cos (3 h) \\ + 0. 0 2 8 9 \cos (4 h) - 0. 1 4 7 5 \sin (h) - 0. 0 3 0 8 \sin (2 h) \\ + 0. 0 3 8 5 \sin (3 h) + 0. 0 0 9 6 \sin (4 h) + 1 \\ \end{array}
$$

(28)

The formula was normalized to have an average value of one. While this proposed formula is more complex than the current formula (Equation (26)), it merely reflects the trend of the Munsell data (Figure 5), which appears plausible. We believe that it is better to directly represent the Munsell data rather than choose an ambiguous middle-ground between complexity and basis in data.

While the proposed formulas offer clear theoretical advantages to the current CAM16 formulas for chroma and colorfulness, it is important to verify that these proposed formulas also perform well on visual data. Data from the Munsell color order system $^{20}$  and the LUTCHI color appearance scaling experiments were used to compare the proposed and current models. These LUTCHI data contain two subsets. The first set of data consists of the scaled colorfulness of 99 stimuli at two luminance levels (252 and  $42~\mathrm{cd} / \mathrm{m}^2$ ) and three relative background luminance levels ( $6.2\%$ ,  $21.5\%$ , and  $100\%$ ). $^{21}$  The second set of data consists of the scaled colorfulness of 36 stimuli at six luminance levels ranging from  $L_{\mathrm{white}} = 0.4~\mathrm{cd} / \mathrm{m}^2$  to  $L_{\mathrm{white}} = 842~\mathrm{cd} / \mathrm{m}^2$  ( $\sim 11$  stops) against a mid-gray background. $^{12}$

Different methods were used to calculate the adapting luminance for the current versus the proposed formulas. Since, as discussed above, the background dependencies in the current CAM16 formulas for chroma and colorfulness compensate for background dependency of adapting luminance, the adapting luminance was allowed to vary with background luminance when predicting the LUTCHI data with the current CAM16 colorfulness formula. Even though this method of calculating the adapting luminance is problematic (as discussed above) and can easily lead to errors for unaware practitioners,


<!-- page 8 -->

![img-7.jpeg](img-7.jpeg)
FIGURE 6 The chroma of colors from the Munsell color order system $^{20}$  as predicted by chroma in (A) CAM16 (Equation (19)) and (B) the proposed formula (Equation (24)). The coefficients of determination  $(r^2)$  for the data are 0.87 for CAM16 and 0.96 for the proposed formula. The proposed chroma attribute also demonstrates improved linearity. Note that colors are approximate and that the scales need not be equal in magnitude

![img-8.jpeg](img-8.jpeg)

![img-9.jpeg](img-9.jpeg)
FIGURE 7 Colorfulness data from the LUTCHI scaling experiments $^{12,21}$  as predicted by (A) CAM16 (Equation (20)) and (B) the proposed formula (Equation (23)). The coefficients of determination  $(r^2)$  for the data are 0.81 for CAM16 and 0.71 for the proposed formula. Note that colors are approximate and that the scales need not be equal in magnitude

![img-10.jpeg](img-10.jpeg)

this method was chosen to represent the best possible performance for CAM16 on the LUTCHI colorfulness data. On the other hand, since the proposed formulas remove this convoluted set of counteracting background dependencies, the adapting luminance could be held at  $20\%$  of the white point luminance for all LUTCHI data calculations.

The models' performance on the Munsell data is shown in Figure 6 and their performance on the LUTCHI data is shown in Figure 7. The proposed chroma formula shows a clear improvement on the Munsell data compared

to the current formula. For the current formula, the plot appears to curve downwards as chroma increases. This nonlinearity is possibly due to the nonlinear relationship between  $t$  and  $C$  in CAM16 (Equations (18) and (19)), where greater values of  $C$  are compressed. Figure 6 shows the clear advantage in linearizing these formulas: there is no more downward curve at high chromas with the proposed formula. However, when analyzing Munsell chroma predictions within a single hue and chroma, the proposed chroma of the proposed formula decreases with decreasing value. In summary, the proposed formulas appear to be


<!-- page 9 -->

superior at predicting Munsell chroma as chroma and hue change, but not as consistent at predicting Munsell chroma as value changes. We believe that this is a worthwhile tradeoff.

The proposed formula for colorfulness (Equation (26)) underperforms the current CAM16 formula (Equation (23)) on the LUTCHI data (Figure 7). This performance advantage for the CAM16 formula is due to the difference in luminance dependency of the current and proposed formulas. The current colorfulness formula scales proportional to $F_{\text{L}}^{0.25}$, whereas the proposed colorfulness formula has the same relationship with scene luminance as A_{W} (Figure 4). However, there is an important theoretical argument for the proposed formula's proportionality to A_{W}: this matches the luminance‐dependent behavior of the proposed brightness, Q, formula (Equation (20)). Thus, as scene luminance increases, the proposed colorfulness and brightness scales remain in proportion to each other. This proportionality is necessary for saturation to remain invariant to scene luminance level. In the current CAM16 formulas, brightness increases more quickly than colorfulness with increasing luminance, leading to the poor performance of CAM16 on the LUTCHI brightness data (Figure 2). Given these theoretical considerations and the importance of the A_{W} dependency for the proposed Q formula, the worse performance on the LUTCHI data by the proposed colorfulness formulas is permissible.

## CONCLUSION

We have introduced important revisions to the CIECAM02 and CAM16 formulas for brightness, colorfulness, and chroma. Our goal has been primarily conservative in nature—not to extend CAM16 for new applications or datasets, but rather to improve its internal consistency while remaining grounded in the LUTCHI dataset and the principles used to derive the original equations. When needed, data from the Munsell color order system has supplemented the LUTCHI data, allowing us to improve the linearity of the color appearance model. Additionally, simplifications to certain formulas have brought the color appearance model into line with the theoretical definitions of color appearance terminology while also making explicit the effects accounted for by the model.

Analyzing the history of the equation for brightness, Q, in these color appearance models, we found that the nonlinear relationship between lightness, J, and brightness is an artifact of how the Hunt model was transcribed to CIECAM97s. Linearizing the nonlinearity (Equation (17)) removes a perceptual paradox (Figure 1) and improves the performance of the Q equation on brightness scaling data from the LUTCHI experiment (Figure 2). Removing redundant dependencies from the CAM16 equation for Q (Equation (14)) simplifies the brightness formula and improves performance. Thus, the proposed changes to the brightness formula are justified and necessitated by both theory and performance and are the most urgent of all changes proposed in this paper.

Resemblance between the CAM16 formulas for Q and C, chroma, (Equation (19))—specifically, the $\sqrt{J/100}$ term that appears in both and is clearly incorrect in the Q formula—prompted a reevaluation of CAM16 formulas for chroma, colorfulness, M, and saturation, s. Subsequent improvements made to the chroma and colorfulness formulas fall into three categories: background dependencies, eccentricity, and linearity.

The current CAM16 formulas contain myriad background dependencies that counteract each other. This convoluted formulation hid the fact that the actual background dependency did not follow Hunt's qualitative description of how chroma and colorfulness depend on background luminance factor. Furthermore, close analysis of the LUTCHI data revealed no statistically significant effect of background luminance factor on scaled colorfulness or chroma. Thus, the background dependencies have been removed from the formulas for colorfulness and chroma. Additionally, it is now recommended that the adapting luminance be specified directly by the user, as opposed to being derived from the background luminance. Together, these changes mimic the background‐invariance found in the current formulas. Now, this invariance is explicit, as opposed to the current formulas, which claim to be dependent on background luminance but are actually invariant in practice.

This new, more honest formulation allows for future addition of background dependencies, if desired by the user. For instance, a background dependency of colorfulness has been reported by Kim et al.22 They follow a similar approach to modeling as proposed here; they do not include an explicit background dependency in their formulas for colorfulness and chroma. Instead, they modify the adapting luminance input term to reflect the changing background level while holding the stimulus luminance level constant. This approach may be worth exploring in a future iteration of CAM16. In the current model, such an accommodation is not possible because absolute luminance level of the stimulus is derived from the adapting luminance as opposed to being specified independently.

Eccentricity is a key function in CIECAM02 and CAM16 that scales colorfulness, chroma, and saturation to be perceptually uniform across hues. The current eccentricity function (Equation (26)) was fit to four values from an early version of the Hunt model. These values are no longer relevant to the current model given


<!-- page 10 -->

the fundamental differences between Hunt's early model and CAM16. Furthermore, their original derivation relied on assumptions that are unsupported and potentially incorrect. We have followed the core principles laid out by Hunt along a more rigorous path to deriving an eccentricity function directly from an analysis of the Munsell color order system using CAM16 color coordinates. The directness of the derivation promises to provide a much more reliable measure of eccentricity (Equation (28)).

The proposed formulas for colorfulness, chroma, and saturation have been linearized in comparison to their current CAM16 counterparts. This linearization is more theoretically grounded in the definitions of these attributes and leads to improved performance on data from the Munsell color order system. However, the linearization of the colorfulness equation contains a significant tradeoff. Colorfulness in the proposed formulas increases with increasing adapting luminance at the same rate as  $A_{\mathrm{W}}$ , the achromatic white signal, whereas in the current CAM16 colorfulness formula, colorfulness increases in proportion to the adapting-luminance-dependent  $F_{\mathrm{L}}^{0.25}$  (Figure 4). The matching luminance dependencies of  $A_{\mathrm{W}}$  and  $M$  in the proposed formula ensures that colorfulness remains proportional to brightness as adapting luminance increases, and the  $A_{\mathrm{W}}$  dependency of brightness is in turn necessary to correctly predict the LUTCHI brightness data. However, the  $A_{\mathrm{W}}$  dependency does hurt the performance of the proposed colorfulness formula on the LUTCHI colorfulness data compared to the current CAM16 formula. More work should be done to evaluate the proper relationship between colorfulness and adapting luminance.

As this paper has shown, changes made to one part of a color appearance model can have unexpected repercussions in other parts. Hopefully, the conservative nature of the changes proposed here reduce this possibility, but further scrutiny of the proposal from others is certainly warranted to assess the robustness of the new formulas. The uniform color space CAM16-UCS was not considered in this article and certainly needs to be revised and refit to experimental data given the changes proposed here. Until other new issues arise, though, the authors of this paper believe that the proposed modifications to CAM16 immediately improve the performance and theoretical grounding of the color appearance model.

# DATA AVAILABILITY STATEMENT

The LUTCHI color appearance data are available for download at http://markfairchild.org/CAM.. The Munsell renotation data are available for download at https://www.rit.edu/science/munsell-color-science-lab-educational-resources. An open-source MATLAB implementation of the proposed formulas are available upon request from the author.

# ORCID

Luke Hellwig https://orcid.org/0000-0002-5376-5184
Mark D. Fairchild https://orcid.org/0000-0003-1848-3429

# REFERENCES

[1] Fairchild MD. Color Appearance Models. Third ed. John Wiley &amp; Sons, Ltd; 2013.
[2] Hunt RWG. Colour terminology. Color Res Appl. 1978;3:79-87.
[3] Berns R. Billmeyer and Saltzman's Principles of Color Technology: Fourth Edition, Hoboken. Wiley; 2019.
[4] Donofrio RL. Review paper: the Helmholtz-Kohlrausch effect. J SID. 2011;19(10):658-664.
[5] Li C, Li Z, Wang Z, et al. Comprehensive color solutions: CAM16, CAT16, and CAM16UCS. Color Res Appl. 2017;42:703-718.
[6] Hunt RWG. A model of colour vision for predicting colour appearance. Color Res Appl. 1982;7(2):95-112.
[7] Hunt RWG, Pointer MR. A colour-appearance transform for the CIE 1931 standard colorimetric observer. Color Res Appl. 1985;10(3):165-179.
[8] Hunt RWG. A model of color vision for predicting colour appearance in various viewing conditions. Color Res Appl. 1987;12(6):297-314.
[9] Hunt RWG. Revised colour-appearance model for related and unrelated colours. Color Res Appl. 1991;16(3):146-165.
[10] Hunt RWG. A model of colour vision for practical applications. The Reproduction of Colour. 5th ed. Fountain Press; 1995.
[11] Bartleson CJ. Measures of brightness and lightness. Die Farbe. 1980;28:132-148.
[12] Luo MR, Clarke AA, Rhodes PA, Schappo A, Scrivener SAR, Tait CJ. Quantifying colour appearance. Part II. Testing colour models performance using LUTCHI colour appearance data. Color Res Appl. 1991;16(3):181-197.
[13] Hunt RWG, Li CJ, Luo MR. Dynamic cone response functions for models of colour appearance. Color Res Appl. 2003;28(2):82-88.
[14] N. Moroney, M. D. Fairchild, R. W. G. Hunt and C. J. Li, , The CIECAM02 Color Appearance Model," RIT Scholar Works, 2002. https://scholarworks.rit.edu/other/143/
[15] Li CJ, Luo MR, Hunt RWG, Moroney N, Fairchild MD, Newman T. The performance of CIECAM02. 10th Color and Imaging Conference Final Program and Proceedings. The Society for Imaging Science &amp; Technology; 2002.
[16] Luo MR, Rigg B. Chromaticity-discrimination ellipses for surface colors. Color Res Appl. 1986;11(1):25-42.
[17] Hunt RWG. An improved predictor of colourfulness in a model of colour vision. Color Res Appl. 1994;19(1):23-26.
[18] Melgosa M, Huertas R, Berns RS. Performance of recent advanced color-difference formulas using the standardized residual sum of squares index. J Opt Soc Am A. 2008;25(7): 1828-1834.
[19] Nayatani Y. Why two kinds of color order systems are necessary? Color Res Appl. 2005;30(4):295-303.
[20] Newhall SM, Nickerson D, Judd DB. Final report of the O.S.a. subcomittee on the spacing of the Munsell colors. J Opt Soc Am. 1943;33(7):385-418.
[21] Luo MR, Clarke AA, Rhodes PA, Schappo A, Scrivener SAR, Tait CJ. Quantifying colour appearance. Part I. LUTCHI colour appearance data. Color Res Appl. 1991;16(3):166-180.


<!-- page 11 -->

[22] Kim MH, Weyrich T, Kautz J. Model human color perception under extended luminance levels. ACM Trans. Graphics. 2009; 28(3):1-9.
[23] Schlömer N. Algorithmic improvements for the CIECAM02 and CAM16 color appearance models. Unpublished Manuscript; 2018. https://arxiv.org/abs/1802.06067v1

# AUTHOR BIOGRAPHIES

Luke Hellwig is a Ph.D. student, artist, and Color Metrology Specialist at the Munsell Color Science Laboratory at the Rochester Institute of Technology in Rochester, NY. He completed a B.A. in Physics at Carleton College in Northfield, MN, and received the Ruth Katzman Award to study painting and light art at the Art Students League of New York. He will be the co-author of the new edition of Color Appearance Models with Mark D. Fairchild.

Mark D. Fairchild is a Professor and Founding Head of the Integrated Sciences Academy in RIT's College of Science and Director of the Program of Color Science and Munsell Color Science Laboratory. He received his B.S. and M.S. degrees in Imaging Science from RIT and PhD in Vision Science (Brain and Cognitive Science) from the University of Rochester. He is author of over 400 technical publications and the book, Color Appearance Models, 3rd Ed.

How to cite this article: Hellwig L, Fairchild MD. Brightness, lightness, colorfulness, and chroma in CIECAM02 and CAM16. Color Res Appl. 2022;1-13. doi:10.1002/col.22792

# APPENDIX A

# SUMMARY OF PROPOSED CHANGES TO CAM16

Relative to the CAM16 color appearance model as proposed by Li et al., we propose the following changes:

Step 0:  $N_{\mathrm{bb}}$  and  $N_{\mathrm{cb}}$  are no longer used. The formula for achromatic white response is now:

$$
A _ {\mathrm {W}} = 2 R _ {\mathrm {a w}} ^ {\prime} + G _ {\mathrm {a w}} ^ {\prime} + 0. 0 5 B _ {\mathrm {a w}} ^ {\prime} - 0. 3 0 5
$$

Step 6: Calculate the achromatic response:

$$
A = 2 R _ {a} ^ {\prime} + G _ {a} ^ {\prime} + 0. 0 5 B _ {a} ^ {\prime} - 0. 3 0 5
$$

Step 8: Calculate brightness:

$$
Q = (2 / c) (J / 1 0 0) \left(A _ {\mathrm {W}}\right)
$$

Step 9:  $t$  is no longer used in the calculation of chroma, colorfulness, and saturation.

$$
\begin{array}{l} e _ {t} = - 0. 0 5 8 2 \cos (h) - 0. 0 2 5 8 \cos (2 h) - 0. 1 3 4 7 \cos (3 h) \\ + 0. 0 2 8 9 \cos (4 \mathrm {h}) - 0. 1 4 7 5 \sin (\mathrm {h}) - 0. 0 3 0 8 \sin (2 \mathrm {h}) \\ + 0. 0 3 8 5 \sin (3 \mathrm {h}) + 0. 0 0 9 6 \sin (4 \mathrm {h}) + 1 \\ \end{array}
$$

$$
M = 4 3 N _ {\mathrm {c}} e _ {\mathrm {t}} \sqrt {a ^ {2} + b ^ {2}}
$$

$$
C = 3 5 \cdot \frac {M}{A _ {\mathrm {w}}}
$$

$$
s = 1 0 0 \cdot \frac {M}{Q}
$$

These changes necessitate the following modifications to the inverse CAM16 model as proposed by Li et al. Algorithmic improvements suggested by Schlömer have been incorporated.

Step 0:  $N_{\mathrm{bb}}$  and  $N_{\mathrm{cb}}$  are no longer used. The formula for achromatic white response is now:

$$
A _ {\mathrm {W}} = 2 R _ {\mathrm {a w}} ^ {\prime} + G _ {\mathrm {a w}} ^ {\prime} + 0. 0 5 B _ {\mathrm {a w}} ^ {\prime} - 0. 3 0 5
$$

Step 1-1: Compute  $J$  from  $Q$  (if  $Q$  is given):

$$
J = \frac {5 0 \cdot c \cdot Q}{A _ {\mathrm {W}}}
$$

Compute  $Q$  from  $J$  (if  $J$  is given):

$$
Q = (2 / c) (J / 1 0 0) \left(A _ {\mathrm {W}}\right)
$$

Step 1-2: Calculate  $M$  from  $C$  or  $s$ :

$$
M = \frac {C \cdot A _ {\mathrm {w}}}{3 5}
$$

$$
M = \frac {s \cdot Q}{1 0 0}
$$

Step 2 and Step 3: Calculate  $e_t, A, M, a,$  and  $b$ .

$$
\begin{array}{l} e _ {\mathrm {t}} = - 0. 0 5 8 2 \cos (\mathrm {h}) - 0. 0 2 5 8 \cos (2 \mathrm {h}) - 0. 1 3 4 7 \cos (3 \mathrm {h}) \\ + 0. 0 2 8 9 \cos (4 \mathrm {h}) - 0. 1 4 7 5 \sin (\mathrm {h}) - 0. 0 3 0 8 \sin (2 \mathrm {h}) \\ + 0. 0 3 8 5 \sin (3 \mathrm {h}) + 0. 0 0 9 6 \sin (4 \mathrm {h}) + 1 \\ \end{array}
$$

$$
A = A _ {\mathrm {W}} \cdot \left(\frac {J}{1 0 0}\right) ^ {\frac {1}{1 2}}
$$


<!-- page 12 -->

$$
p _ {1} ^ {\prime} = 4 3 N _ {\mathrm {c}} e _ {1}
$$

$$
\gamma = \frac {M}{p _ {1} ^ {\prime}}
$$

$$
a = \gamma \cos (h)
$$

$$
b = \gamma \sin (h)
$$
